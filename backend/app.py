"""
股票数据后端服务 - 使用 AKShare 获取公告、新闻、财报数据
部署: python app.py
端口: 5000
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import akshare as ak
import json
from datetime import datetime, timedelta
import traceback

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


if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5000))
    print(f"股票数据后端服务启动... 端口: {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
