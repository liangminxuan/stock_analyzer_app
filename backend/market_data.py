"""行情数据层：多数据源加载、腾讯基本面补充、快照与后台定时刷新。

对外主要接口：
- `get_stock_data()`：只读快照（不阻塞）
- `stock_data_age/error/is_loading()`：状态查询
- `normalize_stock_data(df)`：列名归一化
- `is_trading_time()`：A股交易时段判断
- `warmup_stock_data()` / `start_background_refresh()`：后台加载
"""

import gzip
import json
import os
import threading
import time
from datetime import datetime, timedelta, timezone

import pandas as pd

import akshare as ak

import settings
from settings import (
    OFFHOURS_REFRESH_SECONDS as _OFFHOURS_REFRESH_SECONDS,
    REFRESH_SECONDS as _REFRESH_SECONDS,
    SNAPSHOT_DIR as _SNAPSHOT_DIR,
    SNAPSHOT_MAX_AGE_SECONDS as _SNAPSHOT_MAX_AGE,
    SNAPSHOT_PATH as _SNAPSHOT_PATH,
    TENCENT_ENRICH_TTL as _TENCENT_ENRICH_TTL,
)

# ========== 全局股票数据缓存 ==========
_stock_data_lock = threading.Lock()
_stock_data_cache = {
    'df': None,
    'last_update': 0,
    'loading': False,
    'load_error': None,
    'load_start_time': 0,
}
# 腾讯基本面补充缓存：{'ts': 时间戳, 'data': {code: {...}}}
#
# 修复点（AUDIT_REPORT.md P1-1）：旧实现只缓存时间戳，命中缓存时
# 直接 return 未补充 PE/PB 的原始 df，导致同一筛选条件在 10 分钟内
# 结果时好时坏。现在缓存数据本身，并在命中时回填。
_tencent_fundamentals_cache = {'ts': 0.0, 'data': {}}

def get_stock_data(wait_seconds=0):
    """获取A股行情快照（**请求路径不再阻塞**）。

    改造前（AUDIT_REPORT.md P2-2）：首次请求会在请求线程里等全量行情加载，
    实测 `/api/stock/screen` 耗时 **120.46s**，期间还占住一个 gunicorn worker。

    现在：
    - 数据由后台刷新线程（`start_background_refresh()`）定时更新；
    - 请求进来只读缓存，没有就立刻返回 None，由接口给出“准备中”的提示；
    - 只有显式传 `wait_seconds>0` 时才短暂等待（测试/运维脚本用）。
    """
    with _stock_data_lock:
        df = _stock_data_cache['df']
        loading = _stock_data_cache['loading']
        load_error = _stock_data_cache['load_error']

    if df is not None:
        return df

    if wait_seconds and wait_seconds > 0:
        deadline = time.time() + wait_seconds
        while time.time() < deadline:
            time.sleep(0.2)
            with _stock_data_lock:
                if _stock_data_cache['df'] is not None:
                    return _stock_data_cache['df']
                if not _stock_data_cache['loading']:
                    break

    if load_error:
        print(f"[get_stock_data] 数据不可用: {load_error}")
    elif loading:
        print("[get_stock_data] 数据仍在加载，直接返回 None（不阻塞请求）")
    return None


def stock_data_age():
    """返回当前快照的数据年龄（秒）；没有数据时返回 None。"""
    with _stock_data_lock:
        if _stock_data_cache['df'] is None:
            return None
        last_update = _stock_data_cache['last_update']
    return max(0.0, time.time() - last_update) if last_update else None


def stock_data_error():
    """返回最近一次加载失败原因（没有失败过则为 None）。"""
    with _stock_data_lock:
        return _stock_data_cache['load_error']


def stock_data_is_loading():
    with _stock_data_lock:
        return _stock_data_cache['loading']


# ==================== 腾讯财经 API ====================

def _to_float(value, default=0.0):
    """安全地把腾讯接口字段转成 float。

    腾讯偶发返回 '-'、'' 或 '--' 之类的占位符；旧代码直接 float() 抛异常，
    会被外层 except 捕获导致整批（最多 50 只）股票数据全部丢失。
    """
    if value is None:
        return default
    try:
        text = str(value).strip()
        if not text or text in {'-', '--', 'null', 'None'}:
            return default
        return float(text)
    except (TypeError, ValueError):
        return default


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
                    "price":        _to_float(vals[3]),
                    "last_close":   _to_float(vals[4]),
                    "change_pct":   _to_float(vals[32]),
                    "turnover_pct": _to_float(vals[38]),
                    "pe_ttm":       _to_float(vals[39]),
                    "mcap_yi":      _to_float(vals[44]),
                    "pb":           _to_float(vals[46]),
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
    if df is None or df.empty:
        return df

    # 检查是否需要补充
    pe_valid = df['pe'].notna().sum() if 'pe' in df.columns else 0
    pb_valid = df['pb'].notna().sum() if 'pb' in df.columns else 0
    total = len(df)

    if pe_valid > total * 0.5 and pb_valid > total * 0.5:
        print(f"[enrich_tencent] 数据已完整(PE={pe_valid}/{total}, PB={pb_valid}/{total})，无需补充")
        return df

    # 命中缓存时用缓存数据回填（旧实现在这里直接返回未补充的 df）
    cache_age = time.time() - _tencent_fundamentals_cache['ts']
    if _tencent_fundamentals_cache['data'] and cache_age < _TENCENT_ENRICH_TTL:
        print(f"[enrich_tencent] 命中缓存({cache_age:.0f}s 前)，回填 {len(_tencent_fundamentals_cache['data'])} 只股票")
        return _apply_tencent_fundamentals(df, _tencent_fundamentals_cache['data'])

    # 获取代码列表
    code_col = 'code' if 'code' in df.columns else '代码'
    if code_col not in df.columns:
        print("[enrich_tencent] 找不到代码列，跳过")
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
        print("[enrich_tencent] 腾讯接口无数据，本次不补充")
        return df

    # 写入缓存（缓存数据本身，供后续请求回填）
    _tencent_fundamentals_cache['data'] = all_tencent
    _tencent_fundamentals_cache['ts'] = time.time()

    df = _apply_tencent_fundamentals(df, all_tencent)

    # 同步更新全局数据缓存，后续请求直接受益
    with _stock_data_lock:
        if _stock_data_cache.get('df') is not None:
            _stock_data_cache['df'] = df

    return df


def _apply_tencent_fundamentals(df, all_tencent):
    # 把腾讯行情里的 PE/PB/市值/换手率回填到 df 的缺失字段，
    # 只补缺失值，不覆盖已有有效数据。
    code_col = 'code' if 'code' in df.columns else '代码'
    if code_col not in df.columns:
        return df

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
    return df


# ==================== 蓝筹池（仅用于兜底时给出名称）====================
#
# 注意：这里**不再内置 PE/PB/市值**。此前这些字段是手写常量，
# 在真实数据源全部失败时会被当作真实基本面返回给客户端
# （见 AUDIT_REPORT.md P2-1），现改为 None，让下游筛选自然排除这些行。

BLUECHIP_POOL = {
    '000001': '平安银行',
    '000002': '万科A',
    '600036': '招商银行',
    '601318': '中国平安',
    '600519': '贵州茅台',
    '000858': '五粮液',
    '002594': '比亚迪',
    '300750': '宁德时代',
    '601398': '工商银行',
    '601288': '农业银行',
    '600900': '长江电力',
    '601888': '中国中免',
    '000333': '美的集团',
    '002415': '海康威视',
    '300059': '东方财富',
    '600276': '恒瑞医药',
    '000568': '泸州老窖',
    '002304': '洋河股份',
    '601166': '兴业银行',
    '600887': '伊利股份',
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
                    for code, pool_name in BLUECHIP_POOL.items():
                        tf_code = f"{code}.SZ" if code.startswith(('0', '3')) else f"{code}.SH"
                        try:
                            kdf = tf.klines.get(tf_code, period="1d", as_dataframe=True)
                            if kdf is not None and len(kdf) >= 2:
                                latest = kdf.iloc[-1]
                                prev = kdf.iloc[-2]
                                close = float(latest['close'])
                                prev_close = float(prev['close'])
                                pct_chg = round((close - prev_close) / prev_close * 100, 2)
                                name = str(latest.get('name', pool_name))
                                rows.append({
                                    '代码': code, '名称': name, '最新价': close,
                                    '涨跌幅': pct_chg, '市盈率-动态': None,
                                    '市净率': None, '总市值': None,
                                    '换手率': None,
                                })
                        except Exception:
                            rows.append({
                                '代码': code, '名称': pool_name, '最新价': 0,
                                '涨跌幅': 0, '市盈率-动态': None,
                                '市净率': None, '总市值': None,
                                '换手率': None,
                            })
                    df = pd.DataFrame(rows)
                    print(f"[get_stock_data] TickFlow+蓝筹池兜底成功(基本面字段为空), {len(df)} 行, 耗时 {time.time()-start:.1f}s")
                except Exception as e4:
                    errors.append(f"TickFlow: {str(e4)[:100]}")
                    print(f"[get_stock_data] TickFlow也失败: {e4}")

            if df is not None and not df.empty:
                # 归一化与基本面补充只做一次（不在请求路径里做）
                df = normalize_stock_data(df)
                try:
                    df = _enrich_with_tencent(df)
                except Exception as e:
                    print(f"[get_stock_data] 基本面补充失败(忽略): {e}")

                with _stock_data_lock:
                    _stock_data_cache['df'] = df
                    _stock_data_cache['last_update'] = time.time()
                    _stock_data_cache['load_error'] = None
                    # 关键修复：旧实现在成功后没有复位 loading，
                    # 导致 /api/stock/data_status 永远显示“加载中”
                    _stock_data_cache['loading'] = False
                    print(f"[get_stock_data] 数据加载完成, {len(df)} 行")

                _save_snapshot(df)
                return

            # 所有接口都失败，等待后重试
            print(f"[get_stock_data] 第{attempt+1}次尝试全部失败: {errors}")
            if attempt < 2:
                print("[get_stock_data] 等待10秒后重试...")
                time.sleep(10)

        # 3次都失败
        with _stock_data_lock:
            _stock_data_cache['load_error'] = "; ".join(errors)
            _stock_data_cache['loading'] = False
            print("[get_stock_data] 3次尝试均失败，放弃加载")

    except Exception as e:
        with _stock_data_lock:
            _stock_data_cache['load_error'] = str(e)
            _stock_data_cache['loading'] = False
        print(f"[get_stock_data] 加载异常: {e}")


def warmup_stock_data():
    """后台预热股票数据（幂等；后台刷新线程已覆盖，这里作为兜底）"""
    if settings.DISABLE_BACKGROUND_REFRESH:
        return
    with _stock_data_lock:
        if _stock_data_cache['loading'] or (_stock_data_cache['df'] is not None and (time.time() - _stock_data_cache['last_update']) < 7200):
            return
        _stock_data_cache['loading'] = True
        _stock_data_cache['load_error'] = None
        _stock_data_cache['load_start_time'] = time.time()
    t = threading.Thread(target=_load_stock_data, daemon=True)
    t.start()


# ==================== 数据快照与定时刷新 ====================
#
# 目标（AUDIT_REPORT.md P2-2）：把“请求内加载全量行情”改成“后台定时拉取 +
# 请求只读缓存”，并让进程重启后能先用上次快照顶上。



def _beijing_now(ts=None):
    """UTC 时间戳 -> 北京时间（避免引入 pytz 依赖）"""
    moment = datetime.fromtimestamp(ts, tz=timezone.utc) if ts else datetime.now(timezone.utc)
    return moment + timedelta(hours=8)


def is_trading_time(ts=None):
    """A股交易时段：周一~周五 09:15-11:30、13:00-15:05（北京时间）"""
    local = _beijing_now(ts)
    if local.weekday() >= 5:
        return False
    minutes = local.hour * 60 + local.minute
    return (9 * 60 + 15 <= minutes <= 11 * 60 + 30) or (13 * 60 <= minutes <= 15 * 60 + 5)


def _save_snapshot(df):
    """把当前快照落盘，进程重启后可直接使用（Render 空闲会回收实例）"""
    if df is None or df.empty:
        return
    try:
        os.makedirs(_SNAPSHOT_DIR, exist_ok=True)
        payload = {'saved_at': time.time(), 'rows': df.to_dict('records')}
        tmp_path = _SNAPSHOT_PATH + '.tmp'
        with gzip.open(tmp_path, 'wt', encoding='utf-8') as fh:
            json.dump(payload, fh, ensure_ascii=False)
        os.replace(tmp_path, _SNAPSHOT_PATH)
        print(f"[snapshot] 已保存 {len(df)} 行 -> {_SNAPSHOT_PATH}")
    except Exception as e:
        print(f"[snapshot] 保存失败: {e}")


def load_snapshot():
    """启动时加载上次快照（超过 _SNAPSHOT_MAX_AGE 则忽略）。成功返回 True。"""
    try:
        if not os.path.exists(_SNAPSHOT_PATH):
            return False
        with gzip.open(_SNAPSHOT_PATH, 'rt', encoding='utf-8') as fh:
            payload = json.load(fh)
        saved_at = float(payload.get('saved_at') or 0)
        rows = payload.get('rows') or []
        if not rows:
            return False
        if saved_at and (time.time() - saved_at) > _SNAPSHOT_MAX_AGE:
            print(f"[snapshot] 快照已过期({(time.time() - saved_at) / 3600:.1f}h)，忽略")
            return False

        df = pd.DataFrame(rows)
        with _stock_data_lock:
            _stock_data_cache['df'] = df
            _stock_data_cache['last_update'] = saved_at
            _stock_data_cache['load_error'] = None
            _stock_data_cache['loading'] = False
        age_min = (time.time() - saved_at) / 60 if saved_at else 0
        print(f"[snapshot] 已加载快照 {len(df)} 行（{age_min:.0f} 分钟前）")
        return True
    except Exception as e:
        print(f"[snapshot] 读取失败: {e}")
        return False


def _refresh_once():
    """执行一次刷新：加载 -> 归一化 -> 补充基本面 -> 落盘。成功返回 True。"""
    with _stock_data_lock:
        if _stock_data_cache['loading']:
            return False
        _stock_data_cache['loading'] = True
        _stock_data_cache['load_error'] = None
        _stock_data_cache['load_start_time'] = time.time()
    try:
        _load_stock_data()
    except Exception as e:
        with _stock_data_lock:
            _stock_data_cache['load_error'] = str(e)
        print(f"[refresh] 刷新异常: {e}")
    finally:
        with _stock_data_lock:
            _stock_data_cache['loading'] = False
            loaded = _stock_data_cache['df'] is not None
    return loaded


def start_background_refresh():
    """启动后台刷新线程（随进程启动，不在请求路径里跑）"""
    def loop():
        while True:
            try:
                _refresh_once()
            except Exception as e:  # 任何异常都不能让刷新线程退出
                print(f"[refresh] 刷新循环异常: {e}")
            interval = _REFRESH_SECONDS if is_trading_time() else _OFFHOURS_REFRESH_SECONDS
            print(f"[refresh] 下次刷新将在 {interval}s 后")
            time.sleep(max(5, interval))

    thread = threading.Thread(target=loop, name='stock-data-refresh', daemon=True)
    thread.start()
    print('[refresh] 后台刷新线程已启动')
    return thread


# 启动顺序：先读快照（冷启动即可服务），再开后台刷新
if load_snapshot():
    print('[snapshot] 冷启动使用快照数据，后台正在刷新真实行情')

if not settings.DISABLE_BACKGROUND_REFRESH:
    start_background_refresh()


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
