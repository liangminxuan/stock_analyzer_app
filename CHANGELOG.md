# 更新日志

> 版本号以 `pubspec.yaml` 为唯一来源；CI 发布 tag 也从这里读取。

## 未发布（工程修复批次）

对应 `AUDIT_REPORT.md` 的问题清单，本次修复：

### 数据可信度
- **移除全部硬编码“假行情”兜底**：行情/列表/指数接口失败时改为抛出
  `ApiException`，界面显示错误态与重试，不再返回编造的茅台 1315.0、
  上证 3100 之类的数字（P0-1）
- **移除后端兜底数据中的假基本面**：`BLUECHIP_POOL` 不再内置 PE/PB/市值（P2-1）
- 股票名称改用腾讯搜索接口（UTF-8）解析，解决 GBK 乱码导致的“名称显示为代码”（P1-7）

### 缺陷修复
- 后端基本面缓存 bug：命中缓存时不再返回未补全 PE/PB 的数据（P1-1）
- 缓存增加 TTL 与 LRU 容量上限，消除无界增长（P1-2）
- 腾讯行情字段解析容错：单个字段为 `-` 时不再整批（最多 50 只）数据丢失
- K线获取失败不再静默：Provider 会清空数据并暴露错误（P1-5）
- 13 处 `await` 之后补 `mounted` 守卫，避免页面销毁后 `setState` 崩溃（P1-5）
- 选股等待时长从 3 分钟降到 90 秒，并给出明确提示
- **后端行情改为“后台定时预拉取 + 请求只读缓存”**（P2-2）：
  - 请求路径不再阻塞：冷启动瞬间返回“行情数据正在准备中 + retry_after”，
    实测 `/api/stock/screen` 从 **120.46s → 0.002s**
  - 交易时段每 60s 刷新、非交易时段每 30 分钟（可配）
  - 行情快照落盘（gzip JSON，5000 行约 125KB），进程重启后**秒开**
  - 修复 `loading` 标志加载成功后不复位的问题（`data_status` 不再永远“加载中”）
  - gunicorn 由 2 worker 改为 **1 worker + 8 线程**，共享进程内快照、内存不翻倍

### 安全
- `/api/debug/test_akshare` 默认关闭（`ENABLE_DEBUG_ENDPOINTS=1` 才开放）（P1-3）
- CORS 默认不放开跨域，改由 `ALLOWED_ORIGINS` 环境变量控制（P1-3）
- 新增单 IP 滑动窗口限流（`RATE_LIMIT_MAX_REQUESTS` / `RATE_LIMIT_WINDOW_SECONDS`）（P1-3）
- Android 关闭全局明文流量，改用 `network_security_config.xml`（P1-9）
- release 构建支持 `android/key.properties` 正式签名，缺失时才回退 debug 签名并告警（P1-9）

### 工程
- 静态分析从 142 个问题清零（`analysis_options.yaml` 门禁）
- 新增 23 个前端单测 + 22 个后端 pytest
- 统一日志入口 `lib/utils/logger.dart`，替换 49 处 `print`
- 自选股本地持久化，重启不再丢失（P1-6）
- 删除 6 个不可达/损坏文件（含 4 处编译错误）
- 不再跟踪构建产物与 APK（跟踪文件 635 → 122）
- 移除未使用依赖 `fl_chart`
- 新增 LICENSE、本 CHANGELOG，文档与实现对齐（P2-6）

### 已知未完成（需要产品/运维决策）
- `applicationId` 仍为 `com.example.stock_analyzer_app`，上架前需改为自有域名反写
- 应用图标仅有 `mipmap-hdpi`，缺自适应图标与多分辨率
- 后端仍为单文件（未拆分分层），但已完成定时预拉取与快照（P2-2 的阻塞问题已解决）
- 未接入错误上报与埋点（P2-3）
- `get`（GetX）与 `provider` 并存，仅 AI 分析页使用（P1-4）
- `.github/workflows/build_apk.yml` 的门禁改动需有 `workflows` 权限者应用，
  内容见 `docs/ci/build_apk.yml.proposed`
