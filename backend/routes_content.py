"""内容相关路由：公告、新闻、财报、综合分析、公告解读、AI 评分、调试接口。"""

import os
import time
import traceback
from datetime import datetime
import pandas as pd
import akshare as ak

from flask import Blueprint, jsonify, request

from market_data import (
    _stock_data_cache,
    _tencent_quote,
)
from cache_store import get_cached, rate_limit, set_cached
from ai_engine import full_ai_analysis

content_bp = Blueprint('content_bp', __name__)


@content_bp.route('/api/debug/test_akshare', methods=['GET'])
def debug_test_akshare():
    """测试 akshare 接口是否可用

    默认关闭：该接口会触发全市场数据抓取，线上公开等于给了别人一个
    放大器（见 AUDIT_REPORT.md P1-3）。需要时设置环境变量
    ENABLE_DEBUG_ENDPOINTS=1 再重启。
    """
    if os.environ.get('ENABLE_DEBUG_ENDPOINTS') != '1':
        return jsonify({'success': False, 'error': '调试接口已关闭'}), 404

    results = {}

    # 测试东方财富接口
    try:
        start = time.time()
        df = ak.stock_zh_a_spot_em()
        elapsed = time.time() - start
        results['stock_zh_a_spot_em'] = {
            'success': True,
            'rows': len(df),
            'columns': df.columns.tolist(),
            'elapsed': round(elapsed, 1),
            'sample': df.head(2).to_dict('records') if not df.empty else [],
        }
    except Exception as e:
        results['stock_zh_a_spot_em'] = {'success': False, 'error': str(e)}

    # 测试备用接口
    try:
        start = time.time()
        df = ak.stock_zh_a_spot()
        elapsed = time.time() - start
        results['stock_zh_a_spot'] = {
            'success': True,
            'rows': len(df),
            'columns': df.columns.tolist(),
            'elapsed': round(elapsed, 1),
        }
    except Exception as e:
        results['stock_zh_a_spot'] = {'success': False, 'error': str(e)}

    return jsonify({
        'success': True,
        'results': results,
        'cache_status': {
            'loaded': _stock_data_cache['df'] is not None,
            'loading': _stock_data_cache['loading'],
            'error': _stock_data_cache['load_error'],
        },
    })


@content_bp.route('/api/announcements', methods=['GET'])
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


@content_bp.route('/api/stock/news', methods=['GET'])
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


@content_bp.route('/api/stock/financial', methods=['GET'])
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

        # 判断是否为A股（6/0/3开头的6位数字）
        is_a_stock = len(code) == 6 and code[0] in ('6', '0', '3', '8', '4')

        df = None
        source = ''

        if is_a_stock:
            # A股：优先使用同花顺财务摘要
            try:
                df = ak.stock_financial_abstract_ths(symbol=code, indicator="按报告期")
                source = 'ths'
            except Exception as e:
                print(f"同花顺财务摘要失败({code}): {e}")

        if df is None or (hasattr(df, 'empty') and df.empty):
            # 备用：东方财富利润表
            try:
                market = 'SH' if code.startswith('6') else 'SZ'
                df_profit = ak.stock_profit_sheet_by_report_em(symbol=f"{code}.{market}")
                if df_profit is not None and not df_profit.empty:
                    # 取关键财务指标
                    rename_map = {}
                    if 'REPORT_DATE' in df_profit.columns:
                        rename_map['REPORT_DATE'] = '报告期'
                    if 'TOTAL_OPERATE_INCOME' in df_profit.columns:
                        rename_map['TOTAL_OPERATE_INCOME'] = '营业总收入'
                    if 'PARENT_NETPROFIT' in df_profit.columns:
                        rename_map['PARENT_NETPROFIT'] = '净利润'
                    if 'BASIC_EPS' in df_profit.columns:
                        rename_map['BASIC_EPS'] = '每股收益'
                    if 'WEIGHTAVG_ROE' in df_profit.columns:
                        rename_map['WEIGHTAVG_ROE'] = '加权净资产收益率'
                    df_profit = df_profit.rename(columns=rename_map)
                    df_profit = df_profit.sort_values(
                        by=[c for c in ['报告期', 'REPORT_DATE'] if c in df_profit.columns][0],
                        ascending=False
                    ) if '报告期' in df_profit.columns or 'REPORT_DATE' in df_profit.columns else df_profit
                    df = df_profit
                    source = 'em_profit'
            except Exception as e:
                print(f"东方财富利润表失败({code}): {e}")

        if df is None or (hasattr(df, 'empty') and df.empty):
            return jsonify({
                'success': False,
                'error': f'无法获取该股票的财务数据（代码: {code}），该接口仅支持A股',
                'code': code,
            }), 200

        # 统一处理：按报告期倒序排列（最新的在前）
        date_col = None
        for col in ['报告期', 'REPORT_DATE']:
            if col in df.columns:
                date_col = col
                break
        if date_col:
            df = df.sort_values(date_col, ascending=False)

        items = []
        for _, row in df.head(8).iterrows():  # 最近8期
            item = {'report_date': str(row.get(date_col, '')) if date_col else ''}
            for col in df.columns:
                if col != date_col:
                    val = row.get(col)
                    if val is not None and str(val) != 'nan':
                        item[col] = str(val)
                    else:
                        item[col] = ''
            items.append(item)

        result = {
            'success': True,
            'code': code,
            'source': source,
            'columns': [c for c in df.columns if c != date_col],
            'data': items,
        }

        set_cached(cache_key, result, 3600)
        return jsonify(result)

    except Exception as e:
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@content_bp.route('/api/stock/analysis', methods=['GET'])
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


@content_bp.route('/api/announcement/detail', methods=['GET'])
@rate_limit
def get_announcement_detail():
    """
    获取公告详情并解读
    参数:
      - url: 公告原文URL
      - title: 公告标题
      - stock_name: 股票名称
    """
    try:
        url = request.args.get('url', '')
        title = request.args.get('title', '')
        stock_name = request.args.get('stock_name', '')
        
        print(f"[get_announcement_detail] 请求: url={url}, title={title}, stock_name={stock_name}")

        if not url:
            return jsonify({'success': False, 'error': '缺少URL参数'}), 400

        # 基于标题生成深度解读（不获取原文，因为公告网站通常有反爬）
        interpretation = generate_announcement_interpretation(title, "", stock_name)
        
        print(f"[get_announcement_detail] 解读结果: {interpretation}")

        result = {
            'success': True,
            'title': title,
            'stock_name': stock_name,
            'url': url,
            'content_preview': '点击查看原文链接查看详细内容',
            'interpretation': interpretation,
        }
        print(f"[get_announcement_detail] 返回: {result}")
        return jsonify(result)

    except Exception as e:
        error_detail = traceback.format_exc()
        print(f"[get_announcement_detail] 错误: {e}\n{error_detail}")
        return jsonify({'success': False, 'error': str(e), 'detail': error_detail}), 500


def generate_announcement_interpretation(title, content, stock_name):
    """生成公告深度解读"""
    # 基于标题和内容的解读
    interpretation = {
        'summary': '',
        'key_points': [],
        'impact': '',
        'suggestion': ''
    }
    
    if '分红' in title or '利润分配' in title or '派息' in title:
        interpretation['summary'] = f'{stock_name}宣布分红派息，这是公司盈利后向股东返还现金的方式。'
        interpretation['key_points'] = [
            '分红金额：查看每股分红金额',
            '除权除息日：确定何时能收到分红',
            '分红比例：分红金额占净利润的比例'
        ]
        interpretation['impact'] = '通常被视为积极信号，表明公司现金流健康。'
        interpretation['suggestion'] = '关注分红收益率（分红金额/股价），高于3%算是不错的收益。'
        
    elif '增持' in title or '回购' in title:
        interpretation['summary'] = f'公司大股东或管理层正在增持{stock_name}股票。'
        interpretation['key_points'] = [
            '增持主体：是谁在增持（大股东/高管/员工持股计划）',
            '增持金额：增持了多少钱',
            '增持价格：增持的价格区间'
        ]
        interpretation['impact'] = '内部人士增持通常被视为对公司未来有信心的信号。'
        interpretation['suggestion'] = '关注增持金额是否足够大（至少千万元级别才有参考意义）。'
        
    elif '减持' in title:
        interpretation['summary'] = f'公司股东正在减持{stock_name}股票。'
        interpretation['key_points'] = [
            '减持主体：是谁在减持',
            '减持比例：减持了多少股份',
            '减持原因：是资金需求还是对公司前景不看好'
        ]
        interpretation['impact'] = '减持可能被市场解读为负面信号，但要看具体情况。'
        interpretation['suggestion'] = '如果减持比例超过1%需要警惕；如果是小比例减持（<0.5%）且是财务投资者，影响有限。'
        
    elif '业绩' in title or '预告' in title:
        interpretation['summary'] = f'{stock_name}发布了业绩预告，透露了公司经营状况。'
        interpretation['key_points'] = [
            '同比变化：和去年同期相比增长还是下滑',
            '环比变化：和上一季度相比的变化',
            '业绩原因：增长或下滑的具体原因'
        ]
        interpretation['impact'] = '业绩是股价的重要驱动力，超预期的业绩通常会推动股价上涨。'
        interpretation['suggestion'] = '不仅要看绝对数值，更要看增长趋势和是否达到市场预期。'
        
    elif '合同' in title or '中标' in title:
        interpretation['summary'] = f'{stock_name}获得了新的业务合同或中标项目。'
        interpretation['key_points'] = [
            '合同金额：合同总金额有多大',
            '合同期限：合同执行周期',
            '收入确认：何时能确认收入'
        ]
        interpretation['impact'] = '新订单意味着未来收入有保障，对股价是积极信号。'
        interpretation['suggestion'] = '对比公司年收入规模，如果合同金额占年收入10%以上，影响较大。'
        
    else:
        interpretation['summary'] = f'{stock_name}发布了一则公告，涉及{title}。'
        interpretation['key_points'] = ['建议仔细阅读公告原文', '关注公告中的关键数字和时间节点']
        interpretation['impact'] = '需要结合具体内容分析影响。'
        interpretation['suggestion'] = '如果不确定影响，可以咨询专业人士或观望等待市场反应。'
    
    # 如果有内容，尝试提取关键数字
    if content:
        import re
        # 提取金额数字
        amounts = re.findall(r'(\d+\.?\d*)\s*亿元?', content)
        if amounts:
            interpretation['key_points'].append(f'涉及金额：约{amounts[0]}亿元')
        
        # 提取百分比
        percents = re.findall(r'(\d+\.?\d*)%', content)
        if percents:
            interpretation['key_points'].append(f'涉及比例：{percents[0]}%')
    
    return interpretation


@content_bp.route('/api/stock/ai_analysis')
@rate_limit
def ai_analysis():
    code = request.args.get('code', '').strip()
    if not code:
        return jsonify({'success': False, 'error': '请提供股票代码'})

    try:
        from datetime import datetime, timedelta
        import requests as req_lib

        # ====== 使用腾讯财经K线API（与前端K线分析同源，稳定可靠） ======
        secid = f'sh{code}' if code.startswith(('6', '9')) else ('bj' if code.startswith('8') else f'sz{code}')
        end_dt = datetime.now()
        start_dt = end_dt - timedelta(days=540)
        start_str = start_dt.strftime('%Y-%m-%d')
        end_str = end_dt.strftime('%Y-%m-%d')

        kline_url = f'https://web.ifzq.gtimg.cn/appstock/app/fqkline/get?param={secid},day,{start_str},{end_str},300,qfq'
        print(f'[ai_analysis] 请求腾讯K线: {code}')

        resp = req_lib.get(kline_url, timeout=15, headers={'User-Agent': 'Mozilla/5.0'})
        resp.raise_for_status()
        resp_data = resp.json()

        klines = resp_data.get('data', {}).get(secid, {}).get('qfqday', [])
        if not klines:
            return jsonify({'success': False, 'error': f'未获取到 {code} 的K线数据，请确认股票代码是否正确'})

        # 解析K线数据为 DataFrame
        # 格式: ['日期', '开盘', '收盘', '最高', '最低', '成交量']
        rows = []
        for k in klines:
            rows.append({
                'date': k[0],
                'open': float(k[1]),
                'close': float(k[2]),
                'high': float(k[3]),
                'low': float(k[4]),
                'volume': int(float(k[5]))
            })
        df = pd.DataFrame(rows)
        print(f'[ai_analysis] 成功获取 {code} K线数据，共 {len(df)} 条')

        if len(df) < 30:
            return jsonify({'success': False, 'error': f'{code} 的K线数据不足（仅 {len(df)} 条），需要至少30条数据'})

        df = df.sort_values('date').reset_index(drop=True)

        # 获取基本面数据（使用腾讯API），失败不影响分析
        tq = {}
        try:
            tencent_data = _tencent_quote([code])
            tq = tencent_data.get(code, {})
        except Exception as e:
            print(f'[ai_analysis] 腾讯API获取失败(不影响分析): {e}')

        metrics = {
            'pe': tq.get('pe_ttm', 0) or 0,
            'pb': tq.get('pb', 0) or 0,
        }

        # 调用AI分析引擎
        result = full_ai_analysis(df, metrics if any(metrics.values()) else None)
        result['success'] = True
        result['code'] = code
        result['name'] = tq.get('name', '')
        return jsonify(result)
    except Exception as e:
        import traceback
        tb = traceback.format_exc()
        print(f'[ai_analysis] 分析异常: {tb}')
        return jsonify({'success': False, 'error': f'分析出错: {str(e)[:200]}'})
