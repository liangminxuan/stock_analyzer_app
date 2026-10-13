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

---

## 2. 问题清单（按优先级）

每条含：现象 → 证据（可定位到文件行） → 影响 → 建议 → 工作量估计。

### P0 — 本周就该修（合计约 2–3 人日）

#### P0-1 接口失败时返回"假行情"，且界面上无法分辨 ★最高危
- **现象**：行情/指数接口一旦失败，函数不是抛错，而是返回写死的数字。
- **证据**：`lib/services/api_service.dart`
  - `:407-415` `_getDefaultHotStocks()` 硬编码 `贵州茅台 1315.0 / 中国平安 45.0 / 招商银行 32.0 …`
  - `:417-423` `_defaultIndices()` 硬编码 `上证指数 3100.0 / 深证成指 9500.0 / 创业板指 1800.0`
  - `:385-405` `_emptyQuote()` 全部字段填 0
  - 失败分支：`:246 / :253`（详情）、`:290 / :293`（列表）、`:323 / :326`（指数）
- **影响**：实测茅台现价 **1274.89**，而兜底值是 **1315.0**。用户看到的是一个"像真的一样的假价格"，没有任何标识 —— 对金融类应用这是信任与合规红线（可能被认定为误导性信息）。
- **建议**：删除全部兜底假数据，改为抛 `ApiException`；UI 统一"空态 + 错误原因 + 重试"；如确实需要占位，必须显式标注"示例数据"。
- **工作量**：0.5 天。

#### P0-2 "AI 分析"名不副实，宣传与实现不符
- **现象**：项目主打"AI 驱动"，实际是纯规则计算；文档却声称接了 LLM。
- **证据**：
  - `backend/ai_engine.py:3` 文件头自述：**"纯 Python 计算，不依赖 LLM"**（实现为 EMA/RSI/BOLL/ADX/ATR/Hurst + 技术 0.6 / 基本面 0.4 加权评分）
  - `lib/services/ai_service.dart:29 / :53 / :75` 三个方法体直接 `return _mockXxx(...)`，且该文件整体**不可达**（见 P0-3）
  - `ARCHITECTURE.md:22` 写"本地 AI 模型：使用轻量级 LLM"、"云端 AI API：集成 OpenAI/Claude API（可选）"；`README.md:43` 写"内置 AI 分析引擎"
  - 输出质量旁证：线上实测返回 `"多空信号不明确，建议等待 clearer 信号"` —— 中英夹杂，来自 `full_ai_analysis()` 的 `action_detail` 文案
- **影响**：对外表述与实现不一致，属于宣传风险；同时"AI"这一卖点目前没有技术护城河（规则引擎人人可写）。
- **建议**：二选一 ——（a）改口径为"量化规则引擎/技术指标分析"，如实描述；（b）真接 LLM，并在后端做提示词模板 + 结果缓存 + 成本上限。建议先做（a），再评估（b）。
- **工作量**：改口径 0.5 天；接 LLM 3–5 天（含缓存与降级）。

#### P0-3 23.6% 的代码不可达，其中含 4 处编译错误
- **现象**：`flutter analyze` 报 4 个 **error 级**问题，但项目仍能构建 —— 因为这些代码压根没被任何文件 import。
- **证据**：
  - `flutter analyze` 输出：`undefined_method` × 3（`stock_service.dart:16 / :20 / :34`）、`undefined_named_parameter` × 1（`:56`）
  - 删除 `lib/services/stock_service.dart` 后重跑，**error 归零**（28 → 24 issues）
  - import 可达性扫描（从 `lib/main.dart` 遍历）：**9/33 个文件不可达，共 3161 行 = 23.6%**
    `config/constants.dart`(182)、`models/announcement.dart`(512)、`models/financial.dart`(727)、`providers/announcement_provider.dart`(110)、`services/ai_service.dart`(513)、`services/announcement_service.dart`(157)、`services/news_service.dart`(72)、`services/stock_service.dart`(544)、`widgets/ai_analysis_card.dart`(344)
- **影响**：三份重复的"K线/财务/公告分析"实现（`stock_provider` 里在用的、`stock_service` 里的、`ai_service` 里的）；模型层（financial/announcement）形同虚设，页面直接用 `Map<String, dynamic>`；新人无法判断哪份是权威实现。
- **建议**：先删不可达文件（或先 `git mv` 到 `attic/` 留档），保留的在用逻辑补测试；`models/*` 要么接入 JSON 反序列化，要么删除。
- **工作量**：0.5 天（删除）+ 1 天（接入模型层，可选）。

#### P0-4 仓库被构建产物和 APK 撑到 316MB
- **现象**：克隆仓库要拉 300MB+ 无用二进制。
- **证据**：
  - `git count-objects -vH` → `size-pack: 316.62 MiB`
  - `git ls-files` 共 635 个文件，其中 **517 个**在 `android/app/build/` 或 `.dart_tool/` 下（含两个 27MB 的 `program.dill` / `app.dill`）
  - 根目录另有 27 个 APK/zip，单个 21–24MB（`stock_analyzer_v2.8.0_*.apk`、`run72.zip`、`apk_download.zip` …）
  - `.gitignore` 里虽然写了 `android/app/build/`、`.dart_tool/`，但**文件早已被跟踪，gitignore 对已跟踪文件无效**
- **影响**：clone/CI 变慢；`git status` 噪声；仓库接近无法维护。
- **建议**：
  ```bash
  git rm -r --cached android/app/build .dart_tool
  printf '\n# 构建产物与发布包\n*.apk\n*.zip\nrun*.zip\napk_*.zip\n' >> .gitignore
  # 可选（需团队协调，会改历史）：用 git-filter-repo 从历史中彻底剔除
  ```
- **工作量**：0.5 小时（不含历史重写）。

#### P0-5 零测试 + CI 无任何质量门禁
- **现象**：没有任何测试文件，CI 只负责打包。
- **证据**：`find . -name '*_test.dart'` 无结果，无 `test/` 目录；`.github/workflows/build_apk.yml` 步骤仅 `pub get → build apk → upload artifact → create release`；`codemagic.yaml` 同样。
- **影响**：所有解析逻辑（腾讯 88 字段、GBK、均线、K线、财报字段）只能靠手工回归；提交历史显示数据源已反复返工（sina → eastmoney → tencent 三次替换 K 线源）。
- **建议**：先在 CI 加 `flutter analyze`（当前 142 issues，可先只 fail on error/warning）+ `pytest` 骨架；再针对 `_parseTencentLine`、`getKLineData`、`_calculateMA`、后端 `normalize_stock_data` 补单测（这些是纯函数，最容易测）。
- **工作量**：CI 门禁 0.5 天；首批 20 个单测 1 天。

