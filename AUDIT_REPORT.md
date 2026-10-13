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

### P1 — 1~2 周内（合计约 1.5–2 人周）

#### P1-1 后端缓存逻辑有 bug：10 分钟内二次调用会返回"未补全"的数据
- **证据**：`backend/app.py` `_enrich_with_tencent()`（`:147` 起）
  ```python
  if _tencent_enrich_cache is not None:
      cache_age = time.time() - _tencent_enrich_cache
      if cache_age < 600:
          return df      # ← 该变量只记录时间戳、不缓存数据，返回的是未补 PE/PB 的 df
  ```
- **影响**：同一筛选条件在 10 分钟窗口内结果会时好时坏（PE/PB 缺失 → 被筛选条件静默过滤掉），表现为"选股结果不稳定"。
- **建议**：缓存补充后的 DataFrame（或 `{code: {pe, pb, cap}}` 字典）而非时间戳；用 TTL 结构替代手写时间戳。
- **工作量**：0.5 天。

#### P1-2 后端单文件 1511 行 + 全局可变状态 + 多 worker 状态不一致
- **证据**：
  - `backend/app.py` 1511 行、13 个路由集中在一个文件；模块级可变全局：`_cache`、`_cache_timeout`、`_stock_data_cache`、`_tencent_enrich_cache`（`:23-50`）
  - 后台线程加载 + 请求线程轮询等待：`:52-85`（最多等 **120s**，等待期间占住一个 worker）
  - `render.yaml` / `backend/render.yaml`：`gunicorn --workers 2` → 两个 worker **各自**加载一份全市场快照（内存翻倍、缓存互不相通）
  - `get_cached()`（`:26-38`）**无淘汰策略**，key 由 9 个筛选参数拼接（`cache_key = f'screen_{pe_min}_{...}_{industry}'`），随组合无限增长
  - `_enrich_with_tencent` 按 200 只分批调腾讯（`:186-192`）→ 全市场 5400 只约 27 次外部 HTTP；且用 `df.iterrows()` 逐行回填
- **建议**：拆分为「数据源层 / 缓存层 / 业务层 / 路由层」；缓存换 Redis 或 SQLite 并加 LRU/TTL；预拉取改成定时任务，请求路径只读缓存。
- **工作量**：3–5 天（重构）；1 天（仅修缓存与淘汰）。

#### P1-3 无鉴权、无限流，debug 端点在线上公开
- **证据**：`app.py:20` `CORS(app)`（放开全部来源）；`app.py:456` `/api/debug/test_akshare` 无需任何凭证且会触发 akshare 全量拉取；全部接口无 token、无速率限制。
- **影响**：可被脚本刷爆免费实例（实测该实例并发与内存都很紧张），或通过 debug 接口做放大攻击。
- **建议**：`CORS(app, resources={...})` 限域；debug 路由加 `ENABLE_DEBUG` 环境开关；引入 Flask-Limiter 基础限流。
- **工作量**：0.5 天。

#### P1-4 双状态管理混用（Provider + GetX）
- **证据**：`pubspec.yaml` 同时声明 `provider: ^6.1.1` 与 `get: ^4.6.6`；全仓 `package:get` 仅 1 处引用 —— `lib/screens/discovery/ai_analysis_screen.dart:4`，其余页面全用 Provider；该页内又混用 `GetBuilder(init:)`（`:16`）与 `Obx`（`:26`）。
- **建议**：统一到 Provider（或统一 GetX），移除另一个依赖；该页 `Obx` 包在 `GetBuilder` 内属于冗余建模。
- **工作量**：0.5–1 天。

#### P1-5 静默失败、无生命周期守卫、无自动刷新
- **证据**：
  - `print(` 共 **63 处**，无 logger、无级别、无脱敏
  - K 线失败只 print 不写 `_error`：`lib/providers/stock_provider.dart:85-87`；UI 因此没有任何失败提示
  - `mounted` 仅 3 处、`if (!mounted)` **0 处**，而 `await` 后直接 `setState` 的写法存在（如 `lib/screens/finance/finance_screen.dart:36-47`）→ 典型"页面已销毁仍 setState"隐患
  - 全仓无 `Timer.periodic`，行情页只能手动下拉刷新（`Future.delayed` 仅用于 `discovery_service.dart` 的轮询等待）
- **建议**：引入 logger（或 `debugPrint` + `kDebugMode` 包裹）；失败统一写入 `error` 并在 UI 呈现；所有 `await` 后补 `if (!mounted) return;`；行情页加可关闭的定时刷新（仅交易时段）。
- **工作量**：1 天。

#### P1-6 无本地持久化：自选股/持仓/历史杀进程即丢
- **证据**：全仓无 `shared_preferences` / `hive` / `sqflite` / `path_provider` 依赖与引用；`lib/providers/user_provider.dart` 的自选股 `_watchlist`、持仓 `_portfolio`、分析历史 `_analysisHistory` 全为内存 `List`，由 `main.dart:35` 直接 new。
- **影响**：核心留存功能（自选股）重启即清零，用户无法建立使用习惯。
- **建议**：`shared_preferences`（JSON 序列化）或 `hive`；Provider 初始化时 hydrate、变更时持久化；后续可上云同步。
- **工作量**：0.5–1 天。

#### P1-7 GBK 未解码，非预定义股票名称退化成代码
- **证据**：实测 `curl https://qt.gtimg.cn/q=sh600519` 返回 GBK（名称乱码）；`lib/services/api_service.dart:184` `_getName()` 兜底顺序为 `_nameCache → _stockNames(仅 40 只预定义) → 返回纯代码`；`:177` 注释自述"不依赖 GBK 解码名称"。
- **影响**：除搜索过的股票外，大量股票名称显示为代码；因列表首屏恰好是预定义的那 30 只，问题被掩盖。
- **建议**：用 `package:charset_converter` 解 GBK，或统一改走返回 UTF-8 的东财接口取名称；40 只的硬编码名称表只作兜底。
- **工作量**：1 天（含真机回归）。

#### P1-8 版本与发布流程混乱
- **证据**：`pubspec.yaml:5` `version: 1.0.0+1`；CI 打 tag `v1.0.${{ github.run_number }}`；根目录 APK 命名已到 `v2.8.0`；`README.md` 更新日志停在 `v1.0.0 (2025-01)`；README 声明 MIT 但**仓库无 LICENSE 文件**，也无 CHANGELOG。
- **建议**：以 `pubspec.yaml` 为唯一版本源，CI 从中读取版本打 tag；补 LICENSE、CHANGELOG；根目录 APK 改走 Release 分发。
- **工作量**：0.5 天。

#### P1-9 发布工程不达标（签名、包名、图标、明文流量）
- **证据**：
  - `android/app/build.gradle:48` release 构建使用 `signingConfig signingConfigs.debug`（无法上架/无法覆盖升级）
  - `android/app/build.gradle:39` `applicationId "com.example.stock_analyzer_app"`（示例包名）
  - `android/app/src/main/res/` 仅 `mipmap-hdpi/ic_launcher.png`：缺 xhdpi/xxhdpi/xxxhdpi 与自适应图标（已有 `drawable/ic_launcher_foreground.xml` 却未接入 `mipmap-anydpi-v26`）
  - `AndroidManifest.xml` 中 `android:usesCleartextTraffic="true"` 全局放开明文
  - `lib/config/constants.dart:11` 新浪数据源为 `http://hq.sinajs.cn`（明文；实测需 Referer 才可用）
- **建议**：正式 keystore + `key.properties`（不入库）；包名改自有域名反写；补齐图标与启动图；用 `network_security_config.xml` 只对必要域名放行明文。
- **工作量**：1 天（含上架物料）。

### P2 — 1 个月以上（架构与产品化，合计约 3–5 人周）

#### P2-1 数据源全部依赖第三方非授权接口，无 SLA
- **证据**：`lib/config/constants.dart:11-14`（新浪 http、腾讯、东财）+ `backend/app.py:5` 声明的优先级链 `东方财富(AKShare) → 新浪 → TickFlow(免费层+蓝筹池)`；`BLUECHIP_POOL`（`app.py:263-283`）里的 PE/PB/市值全是**手写常量**，作为兜底基本面。
- **旁证**：提交历史与根目录 APK 命名记录了三次数据源返工（`sina_kline` → `eastmoney_kline` → `tencent_kline`），最新提交 `5256588` 即"改用腾讯K线API替代akshare，解决 connection abort 问题"。
- **建议**：把数据源抽象成可插拔 provider + 熔断/降级/一致性校验（多源交叉比对，偏差过大告警）；评估正式行情源（含授权与费用）；`BLUECHIP_POOL` 的假基本面必须删除或标注。
- **工作量**：1–2 周（取决于是否采购数据源）。

#### P2-2 后端架构升级
- **现状**：Flask 同步 + gunicorn 2 worker；请求路径内触发全市场加载（实测 120s）。
- **建议**：FastAPI/ASGI + 后台定时预拉取（交易时段每 1–3 分钟）+ 持久化缓存（Redis/SQLite/文件快照）+ 请求路径只读缓存；把"数据是否就绪"变成部署时保证而非运行时等待；客户端随之删除 3 分钟轮询逻辑（`discovery_service.dart:16-53`）。
- **工作量**：1–2 周。

#### P2-3 可观测性缺失
- **证据**：无结构化日志（仅 `print`：前端 63 处、后端多处 `print(f"[...]")`）；无错误上报（无 Sentry/Crashlytics）；无监控/告警/`/metrics`；`/api/stock/data_status` 是唯一的"健康度"入口。
- **建议**：后端接入 structlog + Sentry + 基础指标；前端接入 Crashlytics/Sentry + 关键路径埋点（首屏耗时、接口失败率）。
- **工作量**：3–5 天。

#### P2-4 国际化与无障碍
- **证据**：文案全部硬编码中文，无 `flutter_localizations`/arb；全仓无 `Semantics`；涨跌色仅靠红绿（`lib/config/theme.dart:12-13`），色盲用户不可辨。
- **建议**：引入 `intl` + arb；涨跌增加箭头/正负号等非颜色编码；补 `Semantics` 标签。
- **工作量**：3–5 天。

#### P2-5 性能与体积
- **证据**：`lib/widgets/kline_chart.dart` 自绘 CustomPainter 每次 build 重算；非懒加载列表 `news_screen.dart:737 / :964`、`finance_screen.dart:360` 使用 `ListView(children: [...])`；APK 21–24MB；`fl_chart` 依赖已声明但**全仓 0 处使用**（`grep -rn 'package:fl_chart' lib/` 为空）。
- **建议**：移除未用依赖；长列表改 `ListView.builder`；图表数据与画笔缓存、限制重绘；构建加 `--split-debug-info`/`--obfuscate` 并分析体积。
- **工作量**：3–5 天。

#### P2-6 文档与实现脱节
- **证据**：`ARCHITECTURE.md:22` 声称 LLM/OpenAI；README 结构树里的 `lib/app.dart` **并不存在**（`ls lib` 无此文件）；README 把死代码 `ai_service.dart` 列为"AI分析服务"；`QUICK_START.md`/`BUILD_GUIDE.md`/`INSTALL.md` 三份文档内容高度重叠（合计 1242 行）。
- **建议**：文档以代码为准全面校订；合并重复文档；补 CHANGELOG；把本报告当作待办清单跟踪。
- **工作量**：1 天。

---

## 3. 提升空间量化

评分口径：0–10 分，10 = 业界良好水平。

| 维度 | 现状 | 目标（6–8 人周后） | 提升幅度 | 关键动作 | 工时 |
|---|---|---|---|---|---|
| 数据可信度 | 2.5 | 8.0 | **+220%** | 去假数据兜底、多源校验、清理假基本面 | 3 天 |
| 测试与 CI | 1.0 | 7.5 | **+650%** | analyze+test 门禁、纯函数单测、pytest | 2 天 |
| 仓库卫生 | 2.0 | 9.0 | **+350%** | 剔除 517 个构建产物 + 27 个 APK | 0.5 天 |
| 代码质量 | 4.0 | 8.0 | **+100%** | 删 3161 行死代码、63 处 print、mounted 守卫 | 2 天 |
| 后端工程质量 | 3.0 | 7.5 | **+150%** | 修缓存 bug、鉴权限流、缓存淘汰、分层 | 1.5 周 |
| 性能与体验 | 3.5 | 8.0 | **+130%** | 本地持久化、去 3 分钟轮询、懒加载、去未用依赖 | 1 周 |
| 安全与合规 | 3.0 | 8.0 | **+165%** | 正式签名、限域 CORS、明文收敛、LICENSE/隐私政策 | 3 天 |
| 文档 | 6.0 | 8.5 | +40% | 校订一致性、合并、CHANGELOG | 1 天 |
| 功能完整度 | 6.5 | 8.5 | +30% | 真 AI（可选）、自选股云同步、推送 | 2 周 |

**加权结论**：整体从 **3.4 / 10 → 约 8.0 / 10**，即**提升空间约 65%**。
工时拆分：P0 ≈ 2–3 人日；P1 ≈ 1.5–2 人周；P2 ≈ 3–5 人周 → **合计 6–8 人周（1 人）或 3–4 周（2 人并行）**。

> 说明：这里衡量的是"工程成熟度"而非"功能数量"。项目缺的不是新功能，而是**可信数据 + 可验证 + 可维护**这三块地基。

---

## 4. 建议的落地路线

### 阶段 0：止血（0.5–1 天，改动小、收益立竿见影）

**1) 仓库瘦身**（体积从 316MB 量级回落）
```bash
git rm -r --cached android/app/build .dart_tool
cat >> .gitignore <<'EOF'

# 构建产物与发布包（不再入库）
*.apk
*.zip
run*.zip
apk_*.zip
EOF
git commit -m "chore: 停止跟踪构建产物与 APK"
# 可选（会改历史，需团队协调）：git filter-repo --path android/app/build --path .dart_tool --invert-paths
```

**2) 加静态门禁**：新增 `analysis_options.yaml`（本分支已附带），CI 增加一步：
```yaml
      - name: Analyze
        run: flutter analyze
```

**3) 删除不可达代码（3161 行）**：建议先 `git mv` 到 `attic/` 留档一个版本再删。
```bash
git rm lib/services/stock_service.dart lib/services/ai_service.dart \
       lib/services/announcement_service.dart lib/services/news_service.dart \
       lib/widgets/ai_analysis_card.dart lib/providers/announcement_provider.dart
# models/financial.dart、models/announcement.dart、config/constants.dart 若要保留，需真正接入
```

### 阶段 1：可信数据与可验证（约 1 周）

4. **去假数据**：`_getDefaultHotStocks` / `_defaultIndices` / `_emptyQuote` 改为抛异常，UI 统一错误态 + 重试。
5. **修后端缓存 bug**：`_enrich_with_tencent` 缓存数据本身（或引入 `cachetools.TTLCache`），不要缓存时间戳。
6. **补首批单测**（优先纯函数）：`mkdir -p test && flutter test`，覆盖 `_parseTencentLine`、`getKLineData` 解析、`_calculateMA`、后端 `normalize_stock_data`。
7. **自选股持久化**：`shared_preferences` + JSON 序列化，Provider 初始化时 hydrate。
8. **日志与生命周期**：63 处 `print` → logger（`kDebugMode` 保护）；所有 `await` 后补 `if (!mounted) return;`。

### 阶段 2：工程化（2–3 周）

9. **统一状态管理**：二选一（建议保留 Provider，移除 `get`）。
10. **后端分层 + 定时预拉取 + 持久缓存**；客户端删除 3 分钟轮询（`discovery_service.dart:16-53`）。
11. **安全基线**：CORS 限域、加限流、debug 端点加环境开关。
12. **发布工程**：正式 keystore（`key.properties` 不入库）、包名、全套图标、`network_security_config.xml`、LICENSE、隐私政策/用户协议。

### 阶段 3：产品化（3–5 周）

13. **真 AI（若确定要做）**：后端提示词模板 + 结果缓存 + 成本上限 + 失败降级到规则引擎；否则统一改口径。
14. **数据源可插拔 + 熔断 + 多源交叉校验**；评估付费数据源；清理 `BLUECHIP_POOL` 假基本面。
15. **可观测性**：Sentry/Crashlytics + 关键路径埋点 + 后端告警。
16. **i18n / 无障碍 / 性能与体积**。

### 验收标准（Definition of Done）

- [ ] `flutter analyze` 0 error 0 warning，CI 绿
- [ ] `flutter test` 覆盖解析层核心函数（目标 ≥ 60%）
- [ ] 断网/接口失败时界面显示明确错误态，且**不出现任何硬编码行情数字**（可写成测试断言）
- [ ] 冷启动首屏可用 < 3s；选股首调 < 5s（靠预拉取，而非运行时加载）
- [ ] 仓库 clone < 50MB；根目录无 APK
- [ ] release 包使用正式签名；`usesCleartextTraffic` 只对必要域名放行

