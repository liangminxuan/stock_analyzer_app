"""
股票数据后端服务 - 多数据源获取公告、新闻、财报、选股数据
部署: python app.py
端口: 5000
数据源优先级: 东方财富(AKShare) → 新浪 → TickFlow(免费层+蓝筹池)
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import akshare as ak
import json
from datetime import datetime, timedelta
import traceback
import pandas as pd
import time
import threading
from ai_engine import full_ai_analysis, calculate_technical_signals, calculate_risk_metrics

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


# ========== 全局股票数据缓存 ==========
_stock_data_lock = threading.Lock()
_stock_data_cache = {
    'df': None,
    'last_update': 0,
    'loading': False,
    'load_error': None,
    'load_start_time': 0,
}
_tencent_enrich_cache = None  # 腾讯API补充缓存

def get_stock_data():
    """获取A股实时数据（带缓存，缓存2小时）
    如果数据正在加载中，会等待加载完成（最多120秒）
    """
    now = time.time()

    # 缓存有效期内直接返回（2小时）
    with _stock_data_lock:
        if _stock_data_cache['df'] is not None and (now - _stock_data_cache['last_update']) < 7200:
            return _stock_data_cache['df']

        # 如果正在加载，等待加载完成
        if _stock_data_cache['loading']:
            pass  # 释放锁后等待
        else:
            # 没有在加载，开始加载
            _stock_data_cache['loading'] = True
            _stock_data_cache['load_error'] = None
            _stock_data_cache['load_start_time'] = now
            # 在锁内启动加载线程
            t = threading.Thread(target=_load_stock_data, daemon=True)
            t.start()

    # 等待加载完成
    wait_start = time.time()
    while _stock_data_cache['loading'] and (time.time() - wait_start) < 120:
        time.sleep(1)

    with _stock_data_lock:
        if _stock_data_cache['df'] is not None:
            return _stock_data_cache['df']
        if _stock_data_cache['load_error']:
            print(f"[get_stock_data] 加载失败: {_stock_data_cache['load_error']}")
        return None


# ==================== 腾讯财经 API ====================

def _tencent_quote(codes):
    """
    腾讯财经实时行情 API（HTTP GET, GBK编码, ~分隔88字段）
    参考: https://github.com/simonlin1212/a-stock-data
    字段: 1=名称, 3=现价, 4=昨收, 32=涨跌幅%, 38=换手率%, 39=PE_TTM, 44=总市值亿, 46=PB
    不封IP，海外可用，批量请求一次可查多只。
    """
    if not codes:
        return {}
    prefixed = []
    for c in codes:
        c = str(c).strip()
        # 清理已有前缀
        c = c.replace('sh', '').replace('sz', '').replace('bj', '').replace('.', '')
        if c.startswith(("6", "9")):
            prefixed.append(f"sh{c}")
        elif c.startswith("8"):
            prefixed.append(f"bj{c}")
        else:
            prefixed.append(f"sz{c}")

    # 腾讯 API 单次最多约 50 只，分批请求
    all_results = {}
    batch_size = 50
    for i in range(0, len(prefixed), batch_size):
        batch = prefixed[i:i+batch_size]
        try:
            url = "https://qt.gtimg.cn/q=" + ",".join(batch)
            # 使用 requests 而非 urllib（Render 环境兼容性更好）
            import requests as req_lib
            resp = req_lib.get(url, timeout=15, headers={"User-Agent": "Mozilla/5.0"})
            data = resp.content.decode("gbk")

            for line in data.strip().split(";"):
                if not line.strip() or "=" not in line or '"' not in line:
                    continue
                key = line.split("=")[0].split("_")[-1]
                vals = line.split('"')[1].split("~")
                if len(vals) < 53:
                    continue
                code = key[2:]
                all_results[code] = {
                    "name":         vals[1],
                    "price":        float(vals[3]) if vals[3] else 0,
                    "last_close":   float(vals[4]) if vals[4] else 0,
                    "change_pct":   float(vals[32]) if vals[32] else 0,
                    "turnover_pct": float(vals[38]) if vals[38] else 0,
                    "pe_ttm":       float(vals[39]) if vals[39] else 0,
                    "mcap_yi":      float(vals[44]) if vals[44] else 0,
                    "pb":           float(vals[46]) if vals[46] else 0,
                }
        except Exception as e:
            print(f"[tencent_quote] 批次请求失败: {e}")

    return all_results


def _enrich_with_tencent(df):
    """
    用腾讯财经 API 补充 DataFrame 中缺失的 PE/PB/市值/换手率。
    只补充缺失值，不覆盖已有有效数据。
    使用全局缓存避免重复请求腾讯API。
    """
    global _tencent_enrich_cache

    if df is None or df.empty:
        return df

    # 检查是否需要补充
    pe_valid = df['pe'].notna().sum() if 'pe' in df.columns else 0
    pb_valid = df['pb'].notna().sum() if 'pb' in df.columns else 0
    total = len(df)

    if pe_valid > total * 0.5 and pb_valid > total * 0.5:
        print(f"[enrich_tencent] 数据已完整(PE={pe_valid}/{total}, PB={pb_valid}/{total})，无需补充")
        return df

    # 检查缓存：如果之前已经补充过，直接返回
    if _tencent_enrich_cache is not None:
        cache_age = time.time() - _tencent_enrich_cache
        if cache_age < 600:  # 10分钟内不重复补充
            print(f"[enrich_tencent] 跳过，上次补充于 {cache_age:.0f}s 前")
            return df

    # 获取代码列表
    code_col = 'code' if 'code' in df.columns else '代码'
    if code_col not in df.columns:
        print(f"[enrich_tencent] 找不到代码列，跳过")
        return df

    codes = df[code_col].astype(str).str.strip().tolist()
    codes = [c.replace('sh','').replace('sz','').replace('bj','').replace('.','') for c in codes]

    print(f"[enrich_tencent] PE有效={pe_valid}/{total}, PB有效={pb_valid}/{total}, 开始补充 {len(codes)} 只...")

    # 分批请求腾讯API（每批200只）
    all_tencent = {}
    batch_size = 200
    for i in range(0, len(codes), batch_size):
        batch = codes[i:i+batch_size]
        batch_data = _tencent_quote(batch)
        all_tencent.update(batch_data)
        if i + batch_size < len(codes):
            time.sleep(0.1)  # 避免请求过快

    print(f"[enrich_tencent] 腾讯API返回 {len(all_tencent)} 只股票数据")

    if not all_tencent:
        _tencent_enrich_cache = time.time()  # 记录失败时间，避免频繁重试
        return df

    # 补充数据
    enriched_pe = 0
    enriched_pb = 0
    enriched_mcap = 0

    for idx, row in df.iterrows():
        code = str(row.get(code_col, '')).strip()
        code = code.replace('sh','').replace('sz','').replace('bj','').replace('.','')
        if code not in all_tencent:
            continue
        tq = all_tencent[code]

        # PE
        if 'pe' in df.columns:
            cur_pe = row.get('pe')
            if pd.isna(cur_pe) or cur_pe == 0:
                pe_val = tq.get('pe_ttm', 0)
                if pe_val and pe_val > 0:
                    df.at[idx, 'pe'] = pe_val
                    enriched_pe += 1

        # PB
        if 'pb' in df.columns:
            cur_pb = row.get('pb')
            if pd.isna(cur_pb) or cur_pb == 0:
                pb_val = tq.get('pb', 0)
                if pb_val and pb_val > 0:
                    df.at[idx, 'pb'] = pb_val
                    enriched_pb += 1

        # 市值
        if 'market_cap' in df.columns:
            cur_mcap = row.get('market_cap')
            if pd.isna(cur_mcap) or cur_mcap == 0:
                mcap_val = tq.get('mcap_yi', 0)
                if mcap_val and mcap_val > 0:
                    df.at[idx, 'market_cap'] = mcap_val
                    enriched_mcap += 1

        # 换手率
        if 'turnover' in df.columns:
            cur_turn = row.get('turnover')
            if pd.isna(cur_turn) or cur_turn == 0:
                turn_val = tq.get('turnover_pct', 0)
                if turn_val and turn_val > 0:
                    df.at[idx, 'turnover'] = turn_val

    print(f"[enrich_tencent] 补充完成: PE+{enriched_pe}, PB+{enriched_pb}, 市值+{enriched_mcap}")

    # 更新缓存时间
    _tencent_enrich_cache = time.time()

    # 更新全局缓存中的df（确保后续请求也能用到补充后的数据）
    with _stock_data_lock:
        if _stock_data_cache.get('df') is not None:
            _stock_data_cache['df'] = df

    return df


# ==================== 蓝筹池常量（消除重复定义）====================

BLUECHIP_POOL = {
    '000001': {'name': '平安银行', 'pe': 6.5, 'pb': 0.6, 'cap': 2000},
    '000002': {'name': '万科A', 'pe': 8.0, 'pb': 0.8, 'cap': 1500},
    '600036': {'name': '招商银行', 'pe': 5.5, 'pb': 0.7, 'cap': 8000},
    '601318': {'name': '中国平安', 'pe': 8.5, 'pb': 1.0, 'cap': 8000},
    '600519': {'name': '贵州茅台', 'pe': 25.0, 'pb': 8.0, 'cap': 18000},
    '000858': {'name': '五粮液', 'pe': 20.0, 'pb': 5.0, 'cap': 5000},
    '002594': {'name': '比亚迪', 'pe': 30.0, 'pb': 6.0, 'cap': 7000},
    '300750': {'name': '宁德时代', 'pe': 35.0, 'pb': 5.5, 'cap': 7000},
    '601398': {'name': '工商银行', 'pe': 4.5, 'pb': 0.5, 'cap': 18000},
    '601288': {'name': '农业银行', 'pe': 4.0, 'pb': 0.4, 'cap': 14000},
    '600900': {'name': '长江电力', 'pe': 18.0, 'pb': 3.5, 'cap': 5000},
    '601888': {'name': '中国中免', 'pe': 28.0, 'pb': 4.5, 'cap': 3000},
    '000333': {'name': '美的集团', 'pe': 12.0, 'pb': 3.0, 'cap': 5000},
    '002415': {'name': '海康威视', 'pe': 22.0, 'pb': 4.0, 'cap': 3500},
    '300059': {'name': '东方财富', 'pe': 30.0, 'pb': 5.0, 'cap': 2500},
    '600276': {'name': '恒瑞医药', 'pe': 40.0, 'pb': 6.5, 'cap': 3000},
    '000568': {'name': '泸州老窖', 'pe': 18.0, 'pb': 5.5, 'cap': 2500},
    '002304': {'name': '洋河股份', 'pe': 15.0, 'pb': 2.5, 'cap': 2000},
    '601166': {'name': '兴业银行', 'pe': 5.0, 'pb': 0.6, 'cap': 4000},
    '600887': {'name': '伊利股份', 'pe': 16.0, 'pb': 3.5, 'cap': 2000},
}


def _load_stock_data():
    """实际执行数据加载（在后台线程中运行），最多重试2次"""
    try:
        for attempt in range(3):
            print(f"[get_stock_data] 开始获取A股实时数据... (第{attempt+1}次)")
            start = time.time()

            df = None
            errors = []

            # 尝试1: 东方财富接口
            try:
                df = ak.stock_zh_a_spot_em()
                print(f"[get_stock_data] stock_zh_a_spot_em() 成功, {len(df)} 行, 耗时 {time.time()-start:.1f}s")
            except Exception as e1:
                errors.append(f"东方财富: {str(e1)[:100]}")
                print(f"[get_stock_data] 东方财富接口失败: {e1}")

            # 尝试2: 备用接口
            if df is None:
                try:
                    df = ak.stock_zh_a_spot()
                    print(f"[get_stock_data] stock_zh_a_spot() 成功, {len(df)} 行, 耗时 {time.time()-start:.1f}s")
                except Exception as e2:
                    errors.append(f"备用: {str(e2)[:100]}")
                    print(f"[get_stock_data] 备用接口也失败: {e2}")

            # 尝试3: 新浪实时行情接口（更轻量，增加超时）
            if df is None:
                try:
                    import requests as req_lib
                    url = "https://money.finance.sina.com.cn/d/api/openapi_proxy.php/?__s=[[%22hq%22,%22hs_a%22,%22%22%2C%22%22%2C50%2C1]]"
                    resp = req_lib.get(url, timeout=30)
                    data = resp.json()
                    if data and data[0] and 'items' in data[0]:
                        items = data[0]['items']
                        rows = []
                        for item in items:
                            rows.append({
                                '代码': item[0],
                                '名称': item[1],
                                '最新价': item[2],
                                '涨跌幅': item[3],
                                '市盈率-动态': item[4] if len(item) > 4 else None,
                                '市净率': item[5] if len(item) > 5 else None,
                                '总市值': item[6] if len(item) > 6 else None,
                                '换手率': item[7] if len(item) > 7 else None,
                            })
                        df = pd.DataFrame(rows)
                        print(f"[get_stock_data] 新浪接口成功, {len(df)} 行, 耗时 {time.time()-start:.1f}s")
                except Exception as e3:
                    errors.append(f"新浪: {str(e3)[:100]}")
                    print(f"[get_stock_data] 新浪接口也失败: {e3}")

            # 尝试4: TickFlow 免费层 + 蓝筹池
            if df is None:
                try:
                    from tickflow import TickFlow
                    tf = TickFlow.free()
                    rows = []
                    for code, info in BLUECHIP_POOL.items():
                        tf_code = f"{code}.SZ" if code.startswith(('0', '3')) else f"{code}.SH"
                        try:
                            kdf = tf.klines.get(tf_code, period="1d", as_dataframe=True)
                            if kdf is not None and len(kdf) >= 2:
                                latest = kdf.iloc[-1]
                                prev = kdf.iloc[-2]
                                close = float(latest['close'])
                                prev_close = float(prev['close'])
                                pct_chg = round((close - prev_close) / prev_close * 100, 2)
                                name = str(latest.get('name', info['name']))
                                rows.append({
                                    '代码': code, '名称': name, '最新价': close,
                                    '涨跌幅': pct_chg, '市盈率-动态': info['pe'],
                                    '市净率': info['pb'], '总市值': info['cap'],
                                    '换手率': None,
                                })
                        except Exception:
                            rows.append({
                                '代码': code, '名称': info['name'], '最新价': 0,
                                '涨跌幅': 0, '市盈率-动态': info['pe'],
                                '市净率': info['pb'], '总市值': info['cap'],
                                '换手率': None,
                            })
                    df = pd.DataFrame(rows)
                    print(f"[get_stock_data] TickFlow+蓝筹池成功, {len(df)} 行, 耗时 {time.time()-start:.1f}s")
                except Exception as e4:
                    errors.append(f"TickFlow: {str(e4)[:100]}")
                    print(f"[get_stock_data] TickFlow也失败: {e4}")

            if df is not None and not df.empty:
                with _stock_data_lock:
                    _stock_data_cache['df'] = df
                    _stock_data_cache['last_update'] = time.time()
                    _stock_data_cache['load_error'] = None
                    print(f"[get_stock_data] 数据加载完成, {len(df)} 行")
                return

            # 所有接口都失败，等待后重试
            print(f"[get_stock_data] 第{attempt+1}次尝试全部失败: {errors}")
            if attempt < 2:
                print(f"[get_stock_data] 等待10秒后重试...")
                time.sleep(10)

        # 3次都失败
        with _stock_data_lock:
            _stock_data_cache['load_error'] = "; ".join(errors)
            _stock_data_cache['loading'] = False
            print(f"[get_stock_data] 3次尝试均失败，放弃加载")

    except Exception as e:
        with _stock_data_lock:
            _stock_data_cache['load_error'] = str(e)
            _stock_data_cache['loading'] = False
        print(f"[get_stock_data] 加载异常: {e}")


def warmup_stock_data():
    """后台预热股票数据"""
    with _stock_data_lock:
        if _stock_data_cache['loading'] or (_stock_data_cache['df'] is not None and (time.time() - _stock_data_cache['last_update']) < 7200):
            return
        _stock_data_cache['loading'] = True
        _stock_data_cache['load_error'] = None
        _stock_data_cache['load_start_time'] = time.time()
    t = threading.Thread(target=_load_stock_data, daemon=True)
    t.start()


# 启动时预热
warmup_stock_data()


@app.route('/health', methods=['GET'])
def health():
    """健康检查（同时触发数据预热）"""
    if _stock_data_cache['df'] is None and not _stock_data_cache['loading']:
        warmup_stock_data()
    return jsonify({'status': 'ok', 'time': datetime.now().isoformat()})


@app.route('/api/stock/data_status', methods=['GET'])
def stock_data_status():
    """检查股票数据缓存状态"""
    import time
    with _stock_data_lock:
        is_loaded = _stock_data_cache['df'] is not None
        is_loading = _stock_data_cache['loading']
        row_count = len(_stock_data_cache['df']) if is_loaded else 0
        last_update = _stock_data_cache['last_update']
        load_error = _stock_data_cache['load_error']
        load_start = _stock_data_cache['load_start_time']
        elapsed = time.time() - load_start if is_loading and load_start > 0 else 0

    # 如果数据未加载且未在加载，触发预热
    if not is_loaded and not is_loading:
        warmup_stock_data()

    return jsonify({
        'success': True,
        'loaded': is_loaded,
        'loading': is_loading,
        'row_count': row_count,
        'last_update': last_update,
        'load_error': load_error,
        'loading_elapsed': round(elapsed, 1) if is_loading else 0,
    })


@app.route('/api/debug/test_akshare', methods=['GET'])
def debug_test_akshare():
    """测试 akshare 接口是否可用"""
    import time
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

def _get_tickflow_bluechip_data():
    """使用 TickFlow 免费层获取蓝筹池最新行情（含预设 PE/PB/市值）"""
    try:
        from tickflow import TickFlow
        tf = TickFlow.free()
        rows = []
        for code, info in BLUECHIP_POOL.items():
            tf_code = f"{code}.SZ" if code.startswith(('0', '3')) else f"{code}.SH"
            try:
                kdf = tf.klines.get(tf_code, period="1d", as_dataframe=True)
                if kdf is not None and len(kdf) >= 2:
                    latest = kdf.iloc[-1]
                    prev = kdf.iloc[-2]
                    close = float(latest['close'])
                    prev_close = float(prev['close'])
                    pct_chg = round((close - prev_close) / prev_close * 100, 2)
                    name = str(latest.get('name', info['name']))
                    rows.append({
                        '代码': code, '名称': name, '最新价': close,
                        '涨跌幅': pct_chg, '市盈率-动态': info['pe'],
                        '市净率': info['pb'], '总市值': info['cap'],
                        '换手率': None,
                    })
            except:
                rows.append({
                    '代码': code, '名称': info['name'], '最新价': 0,
                    '涨跌幅': 0, '市盈率-动态': info['pe'],
                    '市净率': info['pb'], '总市值': info['cap'],
                    '换手率': None,
                })
        return pd.DataFrame(rows)
    except Exception as e:
        print(f"[tickflow_bluechip] 获取失败: {e}")
        return None


def normalize_stock_data(df):
    """统一不同数据源的股票数据列名"""
    # 东方财富接口的列名映射（兼容多个版本）
    em_mapping = {
        '代码': 'code',
        '名称': 'name',
        '最新价': 'price',
        '涨跌幅': 'change_percent',
        '市盈率-动态': 'pe',
        '市盈率(动)': 'pe',
        '动态市盈率': 'pe',
        '市净率': 'pb',
        '总市值': 'market_cap',
        '换手率': 'turnover',
        '所属行业': 'industry',
        'ROE': 'roe',
    }

    # 新浪接口的列名映射
    sina_mapping = {
        '代码': 'code',
        '名称': 'name',
        '最新价': 'price',
        '涨跌幅': 'change_percent',
    }

    # TickFlow 数据源的列名映射
    tickflow_mapping = {
        'symbol': 'code',
        'name': 'name',
        'close': 'price',
        'pctChg': 'change_percent',
    }

    # 如果列名已经是英文，直接返回
    if 'code' in df.columns:
        return df

    # 打印原始列名用于调试
    print(f"[normalize_stock_data] 原始列名: {df.columns.tolist()}")
    print(f"[normalize_stock_data] 原始行数: {len(df)}")

    # 判断数据源类型
    has_pe = any(c in df.columns for c in ['市盈率-动态', '市盈率(动)', '动态市盈率'])
    has_sina = '代码' in df.columns and not has_pe
    has_tickflow = 'symbol' in df.columns

    if has_tickflow:
        df = df.rename(columns=tickflow_mapping)
        # TickFlow 缺少财务指标
        for col in ['pe', 'pb', 'market_cap', 'turnover', 'industry', 'roe']:
            if col not in df.columns:
                df[col] = float('nan')
    elif has_pe:
        # 东方财富接口 - 使用完整映射
        df = df.rename(columns=em_mapping)
    elif has_sina:
        # 新浪接口 - 只映射基本字段
        df = df.rename(columns=sina_mapping)
        for col in ['pe', 'pb', 'market_cap', 'turnover', 'industry', 'roe']:
            if col not in df.columns:
                df[col] = float('nan')
    else:
        # 未知数据源，尝试通用映射
        df = df.rename(columns=em_mapping)
        for col in ['pe', 'pb', 'market_cap', 'turnover', 'industry', 'roe']:
            if col not in df.columns:
                df[col] = float('nan')

    # 清理代码前缀 (sh/sz/bj)
    if 'code' in df.columns:
        df['code'] = df['code'].astype(str).str.replace(r'^(sh|sz|bj)', '', regex=True)

    print(f"[normalize_stock_data] 映射后列名: {df.columns.tolist()}")
    return df


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

        # 获取A股实时行情数据（使用全局缓存）
        df = get_stock_data()
        if df is None:
            return jsonify({'success': False, 'error': '无法获取股票数据，请稍后重试', 'data': []}), 200

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

        # 获取A股实时数据（使用全局缓存）
        df = get_stock_data()
        if df is None:
            return jsonify({'success': False, 'error': '无法获取股票数据，请稍后重试', 'data': []}), 200

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


# ==================== 公告原文解读 API ====================

@app.route('/api/announcement/detail', methods=['GET'])
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
    title_lower = title.lower()
    
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


@app.route('/api/stock/ai_analysis')
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


if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5000))
    print(f"股票数据后端服务启动... 端口: {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
