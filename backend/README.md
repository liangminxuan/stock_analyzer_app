# 后端服务（Flask）

行情/公告/新闻/财报/选股的聚合服务，前端通过 `lib/services/backend_service.dart` 调用。

## 数据流（P2-2 改造后）

```
启动 ──► 读取上次快照(backend/.cache/stock_snapshot.json.gz) ──► 立即可服务
   │
   └──► 后台刷新线程（不在请求路径里）
            │  交易时段每 60s / 非交易时段每 30min
            ├─ 拉全量行情（东财 akshare → 新浪 → TickFlow+蓝筹池）
            ├─ 归一化列名 + 腾讯基本面补充
            └─ 写回内存缓存 + 落盘快照

请求 ──► 只读内存缓存（命中即返回，毫秒级）
           └─ 未就绪：返回 success=false + “行情数据正在准备中” + retry_after
```

**请求路径不再阻塞**：改造前 `/api/stock/screen` 首次调用会等全量加载（实测 120.46s），
现在冷启动返回 **0.002s**（携带 `retry_after`），数据就绪后为 **0.0009s**。

## 本地运行

```bash
cd backend
pip install -r requirements.txt
python app.py                      # 开发：127.0.0.1:5000

# 生产（单 worker + 多线程，共享进程内快照）
gunicorn --bind 0.0.0.0:8000 --workers 1 --threads 8 --timeout 60 app:app
```

> 为什么是 1 个 worker：行情快照缓存在进程内，多 worker 会各存一份（内存翻倍、重复拉上游）。
> 并发由线程数保证（`--threads 8`）。

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `STOCK_DATA_REFRESH_SECONDS` | 60 | 交易时段刷新间隔 |
| `STOCK_DATA_OFFHOURS_REFRESH_SECONDS` | 1800 | 非交易时段刷新间隔 |
| `STOCK_SNAPSHOT_DIR` | `backend/.cache` | 快照目录 |
| `STOCK_SNAPSHOT_MAX_AGE_SECONDS` | 86400 | 超过该年龄的快照不加载 |
| `RATE_LIMIT_MAX_REQUESTS` | 60 | 单 IP 窗口内请求上限（0 = 关闭限流） |
| `RATE_LIMIT_WINDOW_SECONDS` | 60 | 限流窗口 |
| `ALLOWED_ORIGINS` | 空 | 允许的跨域来源，逗号分隔（默认不允许跨域） |
| `ENABLE_DEBUG_ENDPOINTS` | 未设置 | 设为 1 才开放 `/api/debug/*` |
| `DISABLE_BACKGROUND_REFRESH` | 未设置 | 设为 1 关闭后台刷新（测试用） |

## 接口与错误语义

| 接口 | 说明 |
|---|---|
| `GET /health` | 健康检查（不阻塞） |
| `GET /api/stock/data_status` | 快照状态：`loaded` / `loading` / `row_count` / `age_seconds` / `stale` / `trading_time` / `refresh_interval` |
| `GET /api/stock/screen` | 条件选股 |
| `GET /api/stock/recommend` | 策略推荐 |
| `GET /api/stock/ai_analysis` | 技术+基本面评分（规则引擎，非 LLM） |
| `GET /api/announcements` / `GET /api/stock/news` / `GET /api/stock/financial` | 公告/新闻/财报 |
| `GET /api/announcement/detail` | 公告详情解读 |

数据未就绪时统一返回 HTTP 200：

```json
{"success": false, "error": "行情数据正在准备中，请稍后重试", "loading": true, "retry_after": 10, "data": []}
```

加载失败时额外带 `detail` 字段说明上游错误；限流触发返回 **429**。

## 测试

```bash
cd backend
pip install -r requirements-dev.txt
python -m pytest tests -q          # 39 个用例
```

测试用桩模块替换 `akshare` / `tickflow`，不依赖外网；并通过
`DISABLE_BACKGROUND_REFRESH=1` 关闭后台刷新线程。
