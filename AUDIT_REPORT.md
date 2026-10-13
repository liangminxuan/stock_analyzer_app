# 项目提升空间评估报告 · 股票分析助手

> 评估对象：`stock_analyzer_app`（Flutter 前端 + Flask 后端）
> 评估方式：静态分析（Flutter 3.24.5 `flutter analyze`）、依赖可达性扫描、代码走查、线上后端与数据源真实压测
> 评估范围：`lib/` 13,383 行 Dart、`backend/` 2,280 行 Python、构建/发布/CI/文档

---

## 0. 结论速览

**综合成熟度：3.4 / 10。可提升空间约 60%–70%，折算工程量约 6–8 人周。**

功能骨架（行情 / K线 / 选股 / 公告 / AI 分析页）已经打通并能出 APK，属于"能跑的原型（MVP+）"；
但从**数据可信度、可测试性、可维护性、发布合规**四个维度看，距离"可上架、可长期维护的产品"还有一整段路。

| 维度 | 现状 | 说明 |
|---|---|---|
| 功能完整度 | 6.5 / 10 | 主流程可用，但多处依赖后端慢接口 |
| 数据可信度 | **2.5 / 10** | 接口失败时回退到**硬编码假行情**；"AI"实为规则引擎 |
| 代码质量 | 4.0 / 10 | 开启 lints 后 142 条问题；23.6% 代码不可达；4 处编译错误 |
| 测试与 CI | **1.0 / 10** | 0 个测试，CI 只打包不检查 |
| 后端工程质量 | 3.0 / 10 | 单文件 1511 行、全局可变状态、无鉴权、缓存逻辑有 bug |
| 性能与体验 | 3.5 / 10 | 冷启动 26s，选股首调 **120s**；无本地持久化 |
| 安全与合规 | 3.0 / 10 | 全局明文流量、debug 签名、无 LICENSE / 隐私政策 |
| 文档 | 6.0 / 10 | 文档量大（1242 行）但与实现严重不一致 |
| 仓库卫生 | **2.0 / 10** | git pack 316MB，约 500MB 构建产物与 APK 入库 |

### 五个"最贵"的问题（先修这些，收益最大）

1. **假数据兜底**：行情接口失败时返回写死的价格（贵州茅台 1315.0 等），用户无法分辨真假 —— 金融类 App 的信任/合规红线。`lib/services/api_service.dart:407-423`
2. **"AI"名不副实**：后端 `ai_engine.py:3` 自述"纯 Python 计算，不依赖 LLM"，前端 `ai_service.dart` 全是 `_mock*`（且已是死代码），而 README/ARCHITECTURE 宣称"集成 OpenAI/Claude"。宣传与实现不符。
3. **不可测试**：`lib/` 与 `backend/` 下 0 个测试文件，CI（`.github/workflows/build_apk.yml`）只有 `pub get` + `build apk`，没有 analyze/test 门禁；解析逻辑（GBK、腾讯 88 字段、均线、K线）全靠手工回归。
4. **仓库被二进制撑爆**：`git count-objects` 显示 pack **316.62 MiB**，`android/app/build/`、`.dart_tool/` 共 **517 个文件**入库，另有 27 个 APK/zip（每个 21–24MB）提交在根目录。
5. **慢后端 + 长轮询**：线上实测 `/health` 冷启动 **25.9s**，`/api/stock/screen` 首调 **120.4s**；客户端 `discovery_service.dart` 用"最多等 3 分钟"的轮询硬扛，Dio 超时设到 180s。

---

## 1. 评估方法与可复现证据

```bash
# 1) 静态分析（Flutter 3.24.5，项目未提供 analysis_options.yaml）
flutter analyze
#  → 28 issues：其中 4 个 error（编译级）、17 warning、7 info

# 2) 加上 flutter_lints 后的真实基线
printf 'include: package:flutter_lints/flutter.yaml\n' > analysis_options.yaml && flutter analyze
#  → 142 issues（avoid_print 63、prefer_const_constructors 20、
#     curly_braces_in_flow_control_structures 20、unused_* 18 …）

# 3) 依赖可达性扫描（从 lib/main.dart 出发做 import 图遍历）
#  → 33 个 dart 文件中 9 个不可达，合计 3161 行，占 23.6%

# 4) 线上后端压测（Render 免费实例）
curl -w '%{http_code} %{time_total}s' https://stock-analyzer-app-1-j7jd.onrender.com/health
```

实测原始数据（2026-10-13）：

| 请求 | 状态 | 耗时 |
|---|---|---|
| `GET /health`（冷启动） | 200 | **25.95 s** |
| `GET /api/stock/screen?pe_max=20`（首次，触发全市场数据加载） | 200 | **120.46 s** |
| `GET /api/stock/recommend?count=5`（命中缓存） | 200 | 0.60 s |
| `GET /api/stock/ai_analysis?code=600519` | 200 | 1.49 s |
| `GET /api/stock/data_status`（加载中） | 200 | `{"loaded":false,"loading":true,"loading_elapsed":38.6}` |

数据源可用性实测（均正常，但均为第三方非授权接口）：

| 数据源 | 结果 | 备注 |
|---|---|---|
| `qt.gtimg.cn/q=sh600519` | 200 | **GBK 编码**，中文名乱码，需自行解码 |
| `smartbox.gtimg.cn/s3/?q=茅台` | 200 | 返回 `\uXXXX` 转义，需 `json.decode` 二次解码 |
| `push2his.eastmoney.com` K线 | 200 | 正常，UTF-8 JSON |
| `http://hq.sinajs.cn/list=` | 200 | **明文 HTTP**，需 Referer，且已在 Android 上被 `usesCleartextTraffic` 放开 |
