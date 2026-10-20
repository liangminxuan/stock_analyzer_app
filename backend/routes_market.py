"""行情相关路由：健康检查、快照状态、选股筛选、策略推荐、行业列表。"""

from datetime import datetime
import time, traceback
import pandas as pd
import akshare as ak

from flask import Blueprint, jsonify, request

from market_data import (
    _OFFHOURS_REFRESH_SECONDS,
    _REFRESH_SECONDS,
    _enrich_with_tencent,
    _stock_data_cache,
    _stock_data_lock,
    get_stock_data,
    is_trading_time,
    normalize_stock_data,
    stock_data_error,
    stock_data_is_loading,
    warmup_stock_data,
)
from cache_store import get_cached, rate_limit, set_cached

market_bp = Blueprint('market_bp', __name__)


def _data_not_ready_response():
    """行情数据尚未就绪时的统一响应（HTTP 200，客户端按 success=false 处理）。"""
    error = stock_data_error()
    if error:
        return jsonify({
            'success': False,
            'error': '行情数据暂时不可用，请稍后重试',
            'detail': error,
            'data': [],
        })
    return jsonify({
        'success': False,
        'error': '行情数据正在准备中，请稍后重试',
        'loading': stock_data_is_loading(),
        'retry_after': 10,
        'data': [],
    })


@market_bp.route('/health', methods=['GET'])
def health():
    """健康检查（同时触发数据预热）"""
    if _stock_data_cache['df'] is None and not _stock_data_cache['loading']:
        warmup_stock_data()
    return jsonify({'status': 'ok', 'time': datetime.now().isoformat()})


@market_bp.route('/api/stock/data_status', methods=['GET'])
def stock_data_status():
    """检查股票数据缓存状态"""
    with _stock_data_lock:
        is_loaded = _stock_data_cache['df'] is not None
        is_loading = _stock_data_cache['loading']
        row_count = len(_stock_data_cache['df']) if is_loaded else 0
        last_update = _stock_data_cache['last_update']
        load_error = _stock_data_cache['load_error']
        load_start = _stock_data_cache['load_start_time']
        elapsed = time.time() - load_start if is_loading and load_start > 0 else 0

    # 兜底预热（后台刷新线程未开启时才会真正生效）
    if not is_loaded and not is_loading:
        warmup_stock_data()

    age = (time.time() - last_update) if (is_loaded and last_update) else None
    # 交易时段内超过 10 分钟视为过期；非交易时段放宽到 12 小时
    stale_after = 600 if is_trading_time() else 12 * 3600

    return jsonify({
        'success': True,
        'loaded': is_loaded,
        'loading': is_loading,
        'row_count': row_count,
        'last_update': last_update,
        'age_seconds': round(age, 1) if age is not None else None,
        'stale': bool(age is not None and age > stale_after),
        'load_error': load_error,
        'loading_elapsed': round(elapsed, 1) if is_loading else 0,
        'trading_time': is_trading_time(),
        'refresh_interval': _REFRESH_SECONDS if is_trading_time() else _OFFHOURS_REFRESH_SECONDS,
        'snapshot_enabled': True,
    })


@market_bp.route('/api/stock/screen', methods=['GET'])
@rate_limit
def stock_screen():
    """
    股票筛选器 - 根据条件筛选股票
    参数:
      - pe_min, pe_max: 市盈率范围
      - pb_min, pb_max: 市净率范围
      - roe_min: ROE最低值
      - market_cap_min, market_cap_max: 市值范围(亿)
      - turnover_min: 换手率最低值
      - industry: 行业名称
      - page: 页码，默认1
      - size: 每页数量，默认20
    """
    try:
        # 获取筛选参数
        pe_min = request.args.get('pe_min', type=float)
        pe_max = request.args.get('pe_max', type=float)
        pb_min = request.args.get('pb_min', type=float)
        pb_max = request.args.get('pb_max', type=float)
        roe_min = request.args.get('roe_min', type=float)
        market_cap_min = request.args.get('market_cap_min', type=float)
        market_cap_max = request.args.get('market_cap_max', type=float)
        turnover_min = request.args.get('turnover_min', type=float)
        industry = request.args.get('industry', '')
        page = int(request.args.get('page', 1))
        size = int(request.args.get('size', 20))

        # 缓存key
        cache_key = f'screen_{pe_min}_{pe_max}_{pb_min}_{pb_max}_{roe_min}_{market_cap_min}_{market_cap_max}_{turnover_min}_{industry}'
        cached = get_cached(cache_key, 600)
        if cached:
            return jsonify(cached)

        # 获取A股实时行情数据（使用全局缓存）
        df = get_stock_data()
        if df is None:
            return _data_not_ready_response()

        # 标准化列名
        df = normalize_stock_data(df)
        
        # 用腾讯财经 API 补充缺失的 PE/PB/市值
        df = _enrich_with_tencent(df)
        
        # 检查必需的列
        required_cols = ['code', 'name']
        for col in required_cols:
            if col not in df.columns:
                return jsonify({'success': False, 'error': f'缺少必需列: {col}', 'columns': df.columns.tolist()}), 500
        
        # 确保数据框不为空
        if df.empty:
            return jsonify({'success': False, 'error': '获取的股票数据为空', 'data': []}), 500

        # 数据清洗和转换
        numeric_cols = ['price', 'change_percent', 'pe', 'pb', 'market_cap', 'turnover', 'roe']
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')

        # 市值单位转换：如果市值 > 100000，说明是元，需要转为亿；否则已经是亿
        if 'market_cap' in df.columns:
            if df['market_cap'].max() > 100000:
                df['market_cap'] = df['market_cap'] / 100000000  # 转为亿

        # 数据清洗：过滤停牌股票（价格为0或NaN），但保留新股（首日无昨收）
        if 'price' in df.columns:
            before_count = len(df)
            df = df[df['price'].notna() & (df['price'] > 0)]
            if len(df) < before_count:
                print(f"[stock_screen] 过滤了 {before_count - len(df)} 只停牌/无效股票")

        # 应用筛选条件
        if pe_min is not None and 'pe' in df.columns:
            df = df[df['pe'] >= pe_min]
        if pe_max is not None and 'pe' in df.columns:
            df = df[df['pe'] <= pe_max]
        if pb_min is not None and 'pb' in df.columns:
            df = df[df['pb'] >= pb_min]
        if pb_max is not None and 'pb' in df.columns:
            df = df[df['pb'] <= pb_max]
        if roe_min is not None and 'roe' in df.columns:
            df = df[df['roe'] >= roe_min]
        if market_cap_min is not None and 'market_cap' in df.columns:
            df = df[df['market_cap'] >= market_cap_min]
        if market_cap_max is not None and 'market_cap' in df.columns:
            df = df[df['market_cap'] <= market_cap_max]
        if turnover_min is not None and 'turnover' in df.columns:
            df = df[df['turnover'] >= turnover_min]
        if industry and 'industry' in df.columns:
            df = df[df['industry'].str.contains(industry, na=False)]

        # 排除异常值（只排除非NaN的负值）
        if 'pe' in df.columns:
            df = df[(df['pe'].isna()) | (df['pe'] > 0)]  # 保留NaN和正PE
        if 'pb' in df.columns:
            df = df[(df['pb'].isna()) | (df['pb'] > 0)]  # 保留NaN和正PB

        # 排序（按涨跌幅降序）
        if 'change_percent' in df.columns:
            df = df.sort_values('change_percent', ascending=False)

        # 分页
        total = len(df)
        start = (page - 1) * size
        end = start + size
        df_page = df.iloc[start:end]

        # 构建返回数据
        items = []
        for _, row in df_page.iterrows():
            item = {
                'code': str(row.get('code', '')),
                'name': str(row.get('name', '')),
                'price': float(row.get('price', 0)) if pd.notna(row.get('price')) else 0,
                'change_percent': float(row.get('change_percent', 0)) if pd.notna(row.get('change_percent')) else 0,
            }
            if 'pe' in df.columns:
                item['pe'] = float(row.get('pe', 0)) if pd.notna(row.get('pe')) else None
            if 'pb' in df.columns:
                item['pb'] = float(row.get('pb', 0)) if pd.notna(row.get('pb')) else None
            if 'market_cap' in df.columns:
                item['market_cap'] = float(row.get('market_cap', 0)) if pd.notna(row.get('market_cap')) else None
            if 'turnover' in df.columns:
                item['turnover'] = float(row.get('turnover', 0)) if pd.notna(row.get('turnover')) else None
            if 'industry' in df.columns:
                item['industry'] = str(row.get('industry', ''))
            if 'roe' in df.columns:
                item['roe'] = float(row.get('roe', 0)) if pd.notna(row.get('roe')) else None
            items.append(item)

        result = {
            'success': True,
            'total': total,
            'page': page,
            'size': size,
            'filters': {
                'pe_range': [pe_min, pe_max],
                'pb_range': [pb_min, pb_max],
                'roe_min': roe_min,
                'market_cap_range': [market_cap_min, market_cap_max],
                'turnover_min': turnover_min,
                'industry': industry,
            },
            'data': items,
        }

        set_cached(cache_key, result, 600)
        return jsonify(result)

    except Exception as e:
        error_detail = traceback.format_exc()
        print(f"[stock_screen] 错误: {e}\n{error_detail}")
        return jsonify({'success': False, 'error': str(e), 'detail': error_detail}), 500


@market_bp.route('/api/stock/recommend', methods=['GET'])
@rate_limit
def stock_recommend():
    """
    智能选股推荐 - 基于策略推荐股票
    参数:
      - strategy: 策略类型 (value-价值, growth-成长, tech-技术, comprehensive-综合)
      - count: 推荐数量，默认10
    """
    try:
        strategy = request.args.get('strategy', 'comprehensive')
        count = int(request.args.get('count', 10))

        # 缓存key
        cache_key = f'recommend_{strategy}_{count}'
        cached = get_cached(cache_key, 300)
        if cached:
            return jsonify(cached)

        # 获取A股实时数据（使用全局缓存）
        df = get_stock_data()
        if df is None:
            return _data_not_ready_response()

        # 标准化列名
        df = normalize_stock_data(df)
        
        # 用腾讯财经 API 补充缺失的 PE/PB/市值
        df = _enrich_with_tencent(df)
        
        # 检查必需的列
        if 'code' not in df.columns or 'name' not in df.columns:
            return jsonify({'success': False, 'error': '缺少必需列', 'columns': df.columns.tolist()}), 500

        # 数据清洗
        numeric_cols = ['price', 'change_percent', 'pe', 'pb', 'market_cap', 'turnover', 'roe']
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')

        # 市值单位转换：如果市值 > 100000，说明是元，需要转为亿；否则已经是亿
        if 'market_cap' in df.columns:
            if df['market_cap'].max() > 100000:
                df['market_cap'] = df['market_cap'] / 100000000  # 转为亿

        # 数据清洗：过滤停牌股票（价格为0或NaN），保留新股
        if 'price' in df.columns:
            before_count = len(df)
            df = df[df['price'].notna() & (df['price'] > 0)]
            if len(df) < before_count:
                print(f"[stock_recommend] 过滤了 {before_count - len(df)} 只停牌/无效股票")

        # 根据策略筛选
        filtered_df = df.copy()
        strategy_desc = ""

        if strategy == 'value':
            # 价值策略：低PE、低PB、大市值
            strategy_desc = "低估值高分红，适合稳健投资"
            # 排除北交所（920/83开头）
            if 'code' in filtered_df.columns:
                filtered_df = filtered_df[~filtered_df['code'].astype(str).str.startswith(('920', '83'))]
            if 'pe' in filtered_df.columns:
                # 只保留有有效PE值的股票
                filtered_df = filtered_df[filtered_df['pe'].notna() & (filtered_df['pe'] > 0)]
                filtered_df = filtered_df[filtered_df['pe'] < 20]
            if 'pb' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['pb'].notna() & (filtered_df['pb'] > 0)]
                filtered_df = filtered_df[filtered_df['pb'] < 3]
            if 'market_cap' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['market_cap'].notna() & (filtered_df['market_cap'] > 100)]
            # 按PE升序（越低越好）- 有PE的排前面
            if 'pe' in filtered_df.columns:
                filtered_df = filtered_df.sort_values('pe', ascending=True, na_position='last')

        elif strategy == 'growth':
            # 成长策略：中等PE、高涨幅、中小市值
            strategy_desc = "高成长潜力，适合激进投资"
            if 'pe' in filtered_df.columns:
                filtered_df = filtered_df[(filtered_df['pe'].isna()) | (filtered_df['pe'] > 10)]
                filtered_df = filtered_df[(filtered_df['pe'].isna()) | (filtered_df['pe'] < 80)]
            if 'market_cap' in filtered_df.columns:
                filtered_df = filtered_df[(filtered_df['market_cap'].isna()) | (filtered_df['market_cap'] > 20)]
                filtered_df = filtered_df[(filtered_df['market_cap'].isna()) | (filtered_df['market_cap'] < 500)]
            if 'change_percent' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['change_percent'] > -5]
            # 按涨跌幅降序
            if 'change_percent' in filtered_df.columns:
                filtered_df = filtered_df.sort_values('change_percent', ascending=False)

        elif strategy == 'tech':
            # 技术突破策略：高换手、近期强势
            strategy_desc = "趋势跟踪，捕捉技术突破"
            if 'change_percent' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['change_percent'] > 2]
            if 'market_cap' in filtered_df.columns:
                filtered_df = filtered_df[(filtered_df['market_cap'].isna()) | (filtered_df['market_cap'] > 50)]
            # 按涨跌幅降序
            if 'change_percent' in filtered_df.columns:
                filtered_df = filtered_df.sort_values('change_percent', ascending=False)

        else:  # comprehensive - 综合选股
            strategy_desc = "多维度综合评分，均衡配置"
            if 'pe' in filtered_df.columns:
                filtered_df = filtered_df[(filtered_df['pe'].isna()) | (filtered_df['pe'] > 5)]
                filtered_df = filtered_df[(filtered_df['pe'].isna()) | (filtered_df['pe'] < 50)]
            if 'pb' in filtered_df.columns:
                filtered_df = filtered_df[(filtered_df['pb'].isna()) | (filtered_df['pb'] > 0)]
                filtered_df = filtered_df[(filtered_df['pb'].isna()) | (filtered_df['pb'] < 5)]
            if 'market_cap' in filtered_df.columns:
                filtered_df = filtered_df[(filtered_df['market_cap'].isna()) | (filtered_df['market_cap'] > 50)]
            if 'change_percent' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['change_percent'] > -3]

            # 多因子综合评分
            def _composite_score(row):
                score = 50  # 基础分
                # PE 评分（越低越好，5-50分）
                pe = row.get('pe')
                if pd.notna(pe) and pe > 0:
                    score += max(0, 15 - pe / 5)  # PE=5得15分, PE=50得5分
                # PB 评分（越低越好）
                pb = row.get('pb')
                if pd.notna(pb) and pb > 0:
                    score += max(0, 10 - pb * 2)  # PB=0.5得9分, PB=5得0分
                # 市值评分（大市值加分）
                mcap = row.get('market_cap')
                if pd.notna(mcap) and mcap > 0:
                    if mcap > 1000:
                        score += 5  # 大盘股加分
                # 涨幅评分（正涨幅加分，避免大跌股）
                chg = row.get('change_percent')
                if pd.notna(chg):
                    if 0 < chg < 5:
                        score += 10  # 温和上涨最优
                    elif chg >= 5:
                        score += 5  # 涨幅过大适度加分
                    elif chg < -2:
                        score -= 5  # 下跌扣分
                # 换手率评分（适度活跃）
                turn = row.get('turnover')
                if pd.notna(turn) and turn > 0:
                    if 1 < turn < 10:
                        score += 5  # 适度换手
                return score

            filtered_df['_score'] = filtered_df.apply(_composite_score, axis=1)
            filtered_df = filtered_df.sort_values('_score', ascending=False)

        # 取前N个
        result_df = filtered_df.head(count)

        # 构建返回数据
        items = []
        for _, row in result_df.iterrows():
            item = {
                'code': str(row.get('code', '')),
                'name': str(row.get('name', '')),
                'price': float(row.get('price', 0)) if pd.notna(row.get('price')) else 0,
                'change_percent': float(row.get('change_percent', 0)) if pd.notna(row.get('change_percent')) else 0,
            }
            if 'pe' in df.columns:
                item['pe'] = float(row.get('pe', 0)) if pd.notna(row.get('pe')) else None
            if 'pb' in df.columns:
                item['pb'] = float(row.get('pb', 0)) if pd.notna(row.get('pb')) else None
            if 'market_cap' in df.columns:
                item['market_cap'] = float(row.get('market_cap', 0)) if pd.notna(row.get('market_cap')) else None
            if 'turnover' in df.columns:
                item['turnover'] = float(row.get('turnover', 0)) if pd.notna(row.get('turnover')) else None
            if 'industry' in df.columns:
                item['industry'] = str(row.get('industry', ''))

            # 生成推荐理由
            reasons = []
            if item.get('pe') and item['pe'] < 20:
                reasons.append("估值偏低")
            if item.get('pb') and item['pb'] < 2:
                reasons.append("市净率合理")
            if item.get('change_percent') and item['change_percent'] > 5:
                reasons.append("近期强势")
            if item.get('turnover') and item['turnover'] > 5:
                reasons.append("成交活跃")
            if item.get('market_cap') and item['market_cap'] > 500:
                reasons.append("大盘蓝筹")
            elif item.get('market_cap') and item['market_cap'] < 100:
                reasons.append("中小盘成长")

            item['reason'] = "、".join(reasons) if reasons else "符合选股条件"
            items.append(item)

        result = {
            'success': True,
            'strategy': strategy,
            'strategy_name': {
                'value': '价值优选',
                'growth': '成长先锋',
                'tech': '技术突破',
                'comprehensive': '综合选股'
            }.get(strategy, '综合选股'),
            'strategy_desc': strategy_desc,
            'count': len(items),
            'data': items,
        }

        set_cached(cache_key, result, 300)
        return jsonify(result)

    except Exception as e:
        error_detail = traceback.format_exc()
        print(f"[stock_recommend] 错误: {e}\n{error_detail}")
        return jsonify({'success': False, 'error': str(e), 'detail': error_detail}), 500


@market_bp.route('/api/stock/industries', methods=['GET'])
def get_industries():
    """获取行业列表"""
    try:
        cache_key = 'industries'
        cached = get_cached(cache_key, 3600)
        if cached:
            return jsonify(cached)

        # 获取行业数据
        df = ak.stock_board_industry_name_em()

        items = []
        for _, row in df.head(50).iterrows():
            items.append({
                'name': str(row.get('板块名称', '')),
                'change': str(row.get('板块涨跌幅', '')),
            })

        result = {
            'success': True,
            'data': items,
        }

        set_cached(cache_key, result, 3600)
        return jsonify(result)

    except Exception as e:
        traceback.print_exc()
        # 与其他接口保持一致：数据不可用属于“暂时失败”，用 success 标记而非 500
        return jsonify({'success': False, 'error': f'行业数据暂不可用: {e}', 'data': []})
