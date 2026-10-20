"""后端配置：所有可调项集中在这里（全部来自环境变量）。

约定：本模块只读取环境变量，不做任何 I/O；测试可通过 monkeypatch
环境变量 + 重新导入的方式覆盖，或在代码里直接 patch 使用方的模块变量。
"""

import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ---------- 进程内缓存 ----------
CACHE_MAX_ENTRIES = 256

# ---------- 行情快照 ----------
SNAPSHOT_DIR = os.environ.get(
    'STOCK_SNAPSHOT_DIR',
    os.path.join(BASE_DIR, '.cache'),
)
SNAPSHOT_PATH = os.path.join(SNAPSHOT_DIR, 'stock_snapshot.json.gz')
SNAPSHOT_MAX_AGE_SECONDS = int(os.environ.get('STOCK_SNAPSHOT_MAX_AGE_SECONDS', '86400'))

# ---------- 刷新节奏 ----------
REFRESH_SECONDS = int(os.environ.get('STOCK_DATA_REFRESH_SECONDS', '60'))
OFFHOURS_REFRESH_SECONDS = int(os.environ.get('STOCK_DATA_OFFHOURS_REFRESH_SECONDS', '1800'))

# ---------- 腾讯基本面补充 ----------
TENCENT_ENRICH_TTL = 600          # 秒

# ---------- 限流 ----------
RATE_LIMIT_MAX_KEYS = 4096

# ---------- 开关（导入时读取，测试需在 import 前设置） ----------
DISABLE_BACKGROUND_REFRESH = os.environ.get('DISABLE_BACKGROUND_REFRESH') == '1'

# 跨域：默认不允许（原生 App 不需要 CORS）
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get('ALLOWED_ORIGINS', '').split(',')
    if origin.strip()
]
