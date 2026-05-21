"""
股票数据后端服务 - 使用 AKShare 获取公告、新闻、财报、选股数据
部署: python app.py
端口: 5000
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import akshare as ak
import json
from datetime import datetime, timedelta
import traceback
import pandas as pd

app = Flask(__name__)
CORS(app)

# 缓存：减少重复请求
_cache = {}
_cache_timeout = {}  # key -> 过期时间戳

def get_cached(key, timeout_seconds=300):
    """获取缓存数据"""
    import time
    if key in _cache:
        if time.time() < _cache_timeout.get(key, 0):
            return _cache[key]
    return None

def set_cached(key, data, timeout_seconds=300):
    """设置缓存"""
    import time
    _cache[key] = data
    _cache_timeout[key] = time.time() + timeout_seconds


@app.route('/health', methods=['GET'])
def health():
    """健康检查"""
    return jsonify({'status': 'ok', 'time': datetime.now().isoformat()})


@app.route('/api/announcements', methods=['GET'])
def get_announcements():
    """
    获取公告列表
    参数:
      - date: 日期(YYYYMMDD)，默认今天
      - keyword: 搜索关键词(股票名称/代码)
      - type: 公告类型(全部/财务报告/重大事项/...)
      - page: 页码，默认1
      - size: 每页数量，默认20
    """
    try:
        date = request.args.get('date', datetime.now().strftime('%Y%m%d'))
        keyword = request.args.get('keyword', '')
        notice_type = request.args.get('type', '全部')
        page = int(request.args.get('page', 1))
        size = int(request.args.get('size', 20))

        # 缓存key
        cache_key = f'announcements_{date}_{notice_type}_{keyword}'
        cached = get_cached(cache_key, 300)
        if cached:
            return jsonify(cached)

        # 获取公告
        df = ak.stock_notice_report(symbol=notice_type, date=date)

        # 按关键词筛选
        if keyword:
            mask = df['公告标题'].str.contains(keyword, na=False) | \
                   df['名称'].str.contains(keyword, na=False) | \
                   df['代码'].str.contains(keyword, na=False)
            df = df[mask]

        # 分页
        total = len(df)
        start = (page - 1) * size
        end = start + size
        df_page = df.iloc[start:end]

        # 构建返回数据
        items = []
        for _, row in df_page.iterrows():
            items.append({
                'code': str(row.get('代码', '')),
                'name': str(row.get('名称', '')),
                'title': str(row.get('公告标题', '')),
                'type': str(row.get('公告类型', '')),
                'date': str(row.get('公告日期', '')),
                'url': str(row.get('网址', '')),
            })

        result = {
            'success': True,
            'total': total,
            'page': page,
            'size': size,
            'date': date,
            'data': items,
        }

        set_cached(cache_key, result, 300)
        return jsonify(result)

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stock/news', methods=['GET'])
def get_stock_news():
    """
    获取个股新闻
    参数:
      - code: 股票代码(如601318)
    """
    try:
        code = request.args.get('code', '601318')

        cache_key = f'news_{code}'
        cached = get_cached(cache_key, 600)
        if cached:
            return jsonify(cached)

        # 获取个股新闻
        df = ak.stock_news_em(symbol=code)

        items = []
        for _, row in df.iterrows():
            items.append({
                'title': str(row.get('新闻标题', '')),
                'content': str(row.get('新闻内容', ''))[:200],  # 截取前200字
                'time': str(row.get('发布时间', '')),
                'source': str(row.get('文章来源', '')),
                'url': str(row.get('新闻链接', '')),
            })

        result = {
            'success': True,
            'code': code,
            'total': len(items),
            'data': items,
        }

        set_cached(cache_key, result, 600)
        return jsonify(result)

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stock/financial', methods=['GET'])
def get_stock_financial():
    """
    获取个股财务摘要
    参数:
      - code: 股票代码(如601318)
    """
    try:
        code = request.args.get('code', '601318')

        cache_key = f'financial_{code}'
        cached = get_cached(cache_key, 3600)  # 财务数据缓存1小时
        if cached:
            return jsonify(cached)

        # 获取财务摘要
        df = ak.stock_financial_abstract_ths(symbol=code, indicator="按报告期")

        # 按报告期倒序排列（最新的在前）
        if '报告期' in df.columns:
            df = df.sort_values('报告期', ascending=False)

        items = []
        for _, row in df.head(8).iterrows():  # 最近8期
            item = {'report_date': str(row.get('报告期', ''))}
            for col in df.columns:
                if col != '报告期':
                    val = row.get(col)
                    if val is not None and str(val) != 'nan':
                        item[col] = str(val)
                    else:
                        item[col] = ''
            items.append(item)

        result = {
            'success': True,
            'code': code,
            'columns': [c for c in df.columns if c != '报告期'],
            'data': items,
        }

        set_cached(cache_key, result, 3600)
        return jsonify(result)

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stock/analysis', methods=['GET'])
def get_stock_analysis():
    """
    获取个股综合分析（公告+新闻+财报）
    参数:
      - code: 股票代码
      - name: 股票名称(用于搜索公告)
    """
    try:
        code = request.args.get('code', '601318')
        name = request.args.get('name', '')

        # 并行获取数据（简化为串行）
        announcements = []
        news = []
        financial = []

        # 1. 获取今日公告
        try:
            today = datetime.now().strftime('%Y%m%d')
            df_ann = ak.stock_notice_report(symbol="全部", date=today)
            if name:
                mask = df_ann['公告标题'].str.contains(name, na=False)
                df_ann = df_ann[mask]
            for _, row in df_ann.head(10).iterrows():
                announcements.append({
                    'title': str(row.get('公告标题', '')),
                    'type': str(row.get('公告类型', '')),
                    'date': str(row.get('公告日期', '')),
                })
        except Exception as e:
            print(f"公告获取失败: {e}")

        # 2. 获取个股新闻
        try:
            df_news = ak.stock_news_em(symbol=code)
            for _, row in df_news.head(10).iterrows():
                news.append({
                    'title': str(row.get('新闻标题', '')),
                    'time': str(row.get('发布时间', '')),
                    'source': str(row.get('文章来源', '')),
                })
        except Exception as e:
            print(f"新闻获取失败: {e}")

        # 3. 获取财务摘要
        try:
            df_fin = ak.stock_financial_abstract_ths(symbol=code, indicator="按报告期")
            if '报告期' in df_fin.columns:
                df_fin = df_fin.sort_values('报告期', ascending=False)
            for _, row in df_fin.head(4).iterrows():
                financial.append({
                    'report_date': str(row.get('报告期', '')),
                    'net_profit': str(row.get('净利润', '')),
                    'revenue': str(row.get('营业总收入', '')),
                    'eps': str(row.get('基本每股收益', '')),
                    'roe': str(row.get('净资产收益率', '')),
                })
        except Exception as e:
            print(f"财务获取失败: {e}")

        return jsonify({
            'success': True,
            'code': code,
            'name': name,
            'announcements': announcements,
            'news': news,
            'financial': financial,
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# ==================== 智能选股 API ====================

@app.route('/api/stock/screen', methods=['GET'])
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

        # 获取A股实时行情数据
        try:
            df = ak.stock_zh_a_spot_em()
        except:
            # 备用接口
            df = ak.stock_zh_a_spot()

        # 重命名列以便统一处理
        column_mapping = {
            '代码': 'code',
            '名称': 'name',
            '最新价': 'price',
            '涨跌幅': 'change_percent',
            '市盈率-动态': 'pe',
            '市净率': 'pb',
            '总市值': 'market_cap',
            '换手率': 'turnover',
            '所属行业': 'industry',
            'ROE': 'roe',
        }
        df = df.rename(columns=column_mapping)

        # 数据清洗和转换
        if 'pe' in df.columns:
            df['pe'] = pd.to_numeric(df['pe'], errors='coerce')
        if 'pb' in df.columns:
            df['pb'] = pd.to_numeric(df['pb'], errors='coerce')
        if 'market_cap' in df.columns:
            df['market_cap'] = pd.to_numeric(df['market_cap'], errors='coerce') / 100000000  # 转为亿
        if 'turnover' in df.columns:
            df['turnover'] = pd.to_numeric(df['turnover'], errors='coerce')
        if 'roe' in df.columns:
            df['roe'] = pd.to_numeric(df['roe'], errors='coerce')

        # 应用筛选条件
        if pe_min is not None:
            df = df[df['pe'] >= pe_min]
        if pe_max is not None:
            df = df[df['pe'] <= pe_max]
        if pb_min is not None:
            df = df[df['pb'] >= pb_min]
        if pb_max is not None:
            df = df[df['pb'] <= pb_max]
        if roe_min is not None and 'roe' in df.columns:
            df = df[df['roe'] >= roe_min]
        if market_cap_min is not None:
            df = df[df['market_cap'] >= market_cap_min]
        if market_cap_max is not None:
            df = df[df['market_cap'] <= market_cap_max]
        if turnover_min is not None:
            df = df[df['turnover'] >= turnover_min]
        if industry and 'industry' in df.columns:
            df = df[df['industry'].str.contains(industry, na=False)]

        # 排除异常值
        df = df[df['pe'] > 0]  # 排除负PE
        df = df[df['pb'] > 0]  # 排除负PB

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
                'pe': float(row.get('pe', 0)) if pd.notna(row.get('pe')) else None,
                'pb': float(row.get('pb', 0)) if pd.notna(row.get('pb')) else None,
                'market_cap': float(row.get('market_cap', 0)) if pd.notna(row.get('market_cap')) else None,
                'turnover': float(row.get('turnover', 0)) if pd.notna(row.get('turnover')) else None,
            }
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
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stock/recommend', methods=['GET'])
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

        # 获取A股实时数据
        try:
            df = ak.stock_zh_a_spot_em()
        except:
            df = ak.stock_zh_a_spot()

        # 统一列名
        column_mapping = {
            '代码': 'code',
            '名称': 'name',
            '最新价': 'price',
            '涨跌幅': 'change_percent',
            '市盈率-动态': 'pe',
            '市净率': 'pb',
            '总市值': 'market_cap',
            '换手率': 'turnover',
            '所属行业': 'industry',
            'ROE': 'roe',
            '净利润': 'net_profit',
        }
        df = df.rename(columns=column_mapping)

        # 数据清洗
        for col in ['pe', 'pb', 'market_cap', 'turnover', 'roe', 'change_percent']:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')

        if 'market_cap' in df.columns:
            df['market_cap'] = df['market_cap'] / 100000000  # 转为亿

        # 根据策略筛选
        filtered_df = df.copy()
        strategy_desc = ""

        if strategy == 'value':
            # 价值策略：低PE、低PB、高ROE、大市值
            strategy_desc = "低估值高分红，适合稳健投资"
            filtered_df = filtered_df[
                (filtered_df['pe'] > 0) & (filtered_df['pe'] < 20) &
                (filtered_df['pb'] > 0) & (filtered_df['pb'] < 3) &
                (filtered_df['market_cap'] > 100)
            ]
            if 'roe' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['roe'] > 8]
            # 按PE升序（越低越好）
            filtered_df = filtered_df.sort_values('pe', ascending=True)

        elif strategy == 'growth':
            # 成长策略：中等PE、高涨幅、高换手、中小市值
            strategy_desc = "高成长潜力，适合激进投资"
            filtered_df = filtered_df[
                (filtered_df['pe'] > 10) & (filtered_df['pe'] < 80) &
                (filtered_df['market_cap'] > 20) & (filtered_df['market_cap'] < 500) &
                (filtered_df['change_percent'] > -5)
            ]
            if 'turnover' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['turnover'] > 2]
            # 按涨跌幅降序
            filtered_df = filtered_df.sort_values('change_percent', ascending=False)

        elif strategy == 'tech':
            # 技术突破策略：高换手、近期强势、量价配合
            strategy_desc = "趋势跟踪，捕捉技术突破"
            filtered_df = filtered_df[
                (filtered_df['change_percent'] > 2) &
                (filtered_df['market_cap'] > 50)
            ]
            if 'turnover' in filtered_df.columns:
                filtered_df = filtered_df[filtered_df['turnover'] > 5]
            # 按涨跌幅降序
            filtered_df = filtered_df.sort_values('change_percent', ascending=False)

        else:  # comprehensive - 综合选股
            strategy_desc = "多维度综合评分，均衡配置"
            # 综合评分：PE适中(20-40)、PB适中、市值适中、有涨幅
            filtered_df = filtered_df[
                (filtered_df['pe'] > 5) & (filtered_df['pe'] < 50) &
                (filtered_df['pb'] > 0) & (filtered_df['pb'] < 5) &
                (filtered_df['market_cap'] > 50) &
                (filtered_df['change_percent'] > -3)
            ]
            # 综合排序：市值适中 + 涨幅适中
            filtered_df['score'] = (
                (100 - filtered_df['pe'].clip(0, 100)) * 0.3 +  # PE越低越好
                (10 - filtered_df['pb'].clip(0, 10)) * 10 * 0.3 +  # PB越低越好
                filtered_df['change_percent'].clip(-10, 10) * 2 * 0.4  # 涨幅适中偏好
            )
            filtered_df = filtered_df.sort_values('score', ascending=False)

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
                'pe': float(row.get('pe', 0)) if pd.notna(row.get('pe')) else None,
                'pb': float(row.get('pb', 0)) if pd.notna(row.get('pb')) else None,
                'market_cap': float(row.get('market_cap', 0)) if pd.notna(row.get('market_cap')) else None,
                'turnover': float(row.get('turnover', 0)) if pd.notna(row.get('turnover')) else None,
            }
            if 'industry' in df.columns:
                item['industry'] = str(row.get('industry', ''))

            # 生成推荐理由
            reasons = []
            if item['pe'] and item['pe'] < 20:
                reasons.append("估值偏低")
            if item['pb'] and item['pb'] < 2:
                reasons.append("市净率合理")
            if item['change_percent'] and item['change_percent'] > 5:
                reasons.append("近期强势")
            if item['turnover'] and item['turnover'] > 5:
                reasons.append("成交活跃")
            if item['market_cap'] and item['market_cap'] > 500:
                reasons.append("大盘蓝筹")
            elif item['market_cap'] and item['market_cap'] < 100:
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
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stock/industries', methods=['GET'])
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
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5000))
    print(f"股票数据后端服务启动... 端口: {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
