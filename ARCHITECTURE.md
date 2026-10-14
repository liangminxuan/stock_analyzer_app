# 股票分析助手 APP - 架构设计文档

## 1. 项目概述

为股市小白打造的智能股票分析APP，通过AI解读K线图、财报、公告，提供通俗易懂的投分析建议。

## 2. 技术栈选择

### 2.1 开发框架
- **Flutter**: 跨平台开发，一套代码同时支持Android和iOS
- **Dart语言**: Flutter官方语言，性能优秀

### 2.2 数据层
- **免费股票数据源**:
  - 新浪财经API: `http://hq.sinajs.cn/list=` (实时行情)
  - 腾讯财经API: `https://qt.gtimg.cn/q=` (实时行情)
  - 东方财富API: 历史K线数据
  - BaoStock: 免费A股历史数据

### 2.3 分析层（现状：量化规则引擎）
- **后端 `backend/ai_engine.py`**: EMA / RSI / BOLL / ADX / ATR / Hurst 等技术指标计算，
  技术面 0.6 + 基本面 0.4 加权评分，输出信号/置信度/仓位建议
- **不依赖大模型**: 无 LLM 调用、无 API Key、结果可复现
- 若后续要接入 LLM，请在 `ai_engine.py` 之外新增独立服务，并做好缓存与降级

### 2.4 图表
- **自绘 CustomPainter**: `lib/widgets/kline_chart.dart`（蜡烛图 + 均线 + 成交量），
  未使用第三方图表库

## 3. 功能模块设计

### 3.1 核心功能模块

```
┌─────────────────────────────────────────────────────────────┐
│                    股票分析助手 APP                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  行情数据    │  │  K线分析    │  │  财报解读           │  │
│  │  -实时价格   │  │  -趋势识别  │  │  -关键指标提取       │  │
│  │  -涨跌幅     │  │  -形态分析  │  │  -健康度评分         │  │
│  │  -成交量     │  │  -买卖信号  │  │  -风险提示           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  公告解读    │  │  智能选股    │  │  投资组合           │  │
│  │  -利好利空   │  │  -多维度筛选 │  │  -自选股管理         │  │
│  │  -影响分析   │  │  -评分排序   │  │  -盈亏追踪           │  │
│  │  -操作建议   │  │  -推荐列表   │  │  -收益分析           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 页面结构

```
├── 首页 (Home)
│   ├── 大盘指数概览
│   ├── 自选股列表
│   └── 热门股票推荐
│
├── 行情页 (Market)
│   ├── 股票搜索
│   ├── 股票详情
│   │   ├── 实时行情卡片
│   │   ├── K线图（日/周/月）
│   │   ├── 技术指标
│   │   └── AI解读
│   └── 行业板块
│
├── 财报页 (Finance)
│   ├── 财务概览
│   ├── 利润表分析
│   ├── 资产负债表
│   ├── 现金流量表
│   └── AI财报解读
│
├── 公告页 (News)
│   ├── 最新公告列表
│   ├── 公告详情
│   └── AI公告解读
│
├── 选股页 (Discovery)
│   ├── 智能选股器
│   ├── 选股结果
│   └── 股票对比
│
└── 我的 (Profile)
    ├── 投资组合
    ├── 自选股管理
    ├── 分析历史
    └── 设置
```

## 4. 数据模型设计

### 4.1 股票基础信息 (Stock)
```dart
class Stock {
  final String code;           // 股票代码
  final String name;           // 股票名称
  final String market;         // 市场 (sh/sz)
  final double currentPrice;   // 当前价格
  final double change;         // 涨跌额
  final double changePercent;  // 涨跌幅
  final int volume;            // 成交量
  final double turnover;       // 成交额
  final List<double> bidPrices;    // 买1-5价格
  final List<int> bidVolumes;      // 买1-5数量
  final List<double> askPrices;    // 卖1-5价格
  final List<int> askVolumes;      // 卖1-5数量
  final DateTime updateTime;   // 更新时间
}
```

### 4.2 K线数据 (KLineData)
```dart
class KLineData {
  final DateTime time;         // 时间
  final double open;           // 开盘价
  final double high;           // 最高价
  final double low;            // 最低价
  final double close;          // 收盘价
  final int volume;            // 成交量
  final double amount;         // 成交额
}
```

### 4.3 财务数据 (FinancialData)
```dart
class FinancialData {
  final String reportDate;     // 报告期
  final double revenue;        // 营业收入
  final double netProfit;      // 净利润
  final double totalAssets;    // 总资产
  final double totalLiabilities; // 总负债
  final double equity;         // 股东权益
  final double eps;            // 每股收益
  final double roe;            // 净资产收益率
  final double grossMargin;    // 毛利率
  final double netMargin;      // 净利率
}
```

## 5. AI分析功能设计

### 5.1 K线分析
- **趋势识别**: 上升/下降/震荡趋势判断
- **形态识别**: 头肩顶/底、双顶/底、三角形等
- **技术指标**: MA、MACD、KDJ、RSI等计算和解读
- **买卖信号**: 基于技术形态的入场/出场建议

### 5.2 财报解读
- **关键指标提取**: 自动提取营收、利润、ROE等核心指标
- **同比环比分析**: 计算增长率，判断业绩趋势
- **健康度评分**: 基于财务指标的综合评分
- **风险提示**: 识别财务异常和风险点

### 5.3 公告解读
- **情感分析**: 判断公告利好/利空
- **关键信息提取**: 提取重要事项、数据变化
- **影响分析**: 分析对股价的潜在影响
- **操作建议**: 基于公告内容的操作建议

## 6. 免费数据源API

### 6.1 新浪财经API
```
实时行情: http://hq.sinajs.cn/list=sh600519
多股查询: http://hq.sinajs.cn/list=sh600519,sz000001
分时图:   http://image.sinajs.cn/newchart/min/n/sh600519.gif
日K线图:  http://image.sinajs.cn/newchart/daily/n/sh600519.gif
周K线图:  http://image.sinajs.cn/newchart/weekly/n/sh600519.gif
月K线图:  http://image.sinajs.cn/newchart/monthly/n/sh600519.gif
```

### 6.2 腾讯财经API
```
实时行情: https://qt.gtimg.cn/q=sh600519
多股查询: https://qt.gtimg.cn/q=sh600519,sz000001
```

### 6.3 东方财富API
```
历史K线: https://push2his.eastmoney.com/api/qt/stock/kline/get
股票列表: http://api.finance.ifeng.com/stock/...
```

## 7. 项目文件结构

```
stock_analyzer_app/
├── android/                    # Android 原生配置
├── lib/                        # Flutter 客户端
│   ├── main.dart
│   ├── config/                 # theme / routes / constants
│   ├── models/                 # stock / kline / financial / announcement
│   ├── services/               # api_service / api_exception / backend_service
│   │                           # discovery_service / user_data_store
│   ├── providers/              # stock / market / user（Provider 状态管理）
│   ├── screens/                # main / home / market / finance / news
│   │                           # discovery / profile
│   ├── utils/logger.dart       # 统一日志入口
│   └── widgets/                # stock_card / kline_chart / loading_widget
├── test/                       # 前端单元测试（flutter test）
├── backend/                    # Flask 后端
│   ├── app.py                  # 路由 + 缓存 + 限流 + 数据源
│   ├── ai_engine.py            # 量化规则引擎（技术指标 + 评分）
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── tests/                  # pytest 测试
├── docs/ci/                    # 待应用的 CI 门禁改动
├── analysis_options.yaml       # 静态分析门禁
├── pubspec.yaml
└── README.md
```

## 8. 核心依赖包

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 网络请求
  dio: ^5.4.0

  # 状态管理
  provider: ^6.1.1
  get: ^4.6.6            # 仅 AI 分析页在用（待统一，见审计 P1-4）

  # 本地持久化
  shared_preferences: ^2.2.0

  # UI 组件
  flutter_screenutil: ^5.9.0
  shimmer: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

> K线图为自绘 `CustomPainter`，未引入第三方图表库。
```

## 9. 开发计划

### 第一阶段: 基础框架 (Week 1)
- [ ] 项目初始化
- [ ] 主题和路由配置
- [ ] 基础组件开发
- [ ] API服务封装

### 第二阶段: 行情模块 (Week 2)
- [ ] 股票搜索功能
- [ ] 实时行情展示
- [ ] K线图绘制
- [ ] 自选股功能

### 第三阶段: AI分析 (Week 3)
- [ ] K线分析引擎
- [ ] 财报数据获取
- [ ] 财报解读功能
- [ ] 公告解读功能

### 第四阶段: 高级功能 (Week 4)
- [ ] 智能选股器
- [ ] 投资组合管理
- [ ] 数据持久化
- [ ] 性能优化

## 10. 使用说明

### 10.1 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK >= 21
- iOS >= 11.0

### 10.2 运行步骤
```bash
# 1. 克隆项目
git clone <repo-url>

# 2. 安装依赖
flutter pub get

# 3. 运行应用
flutter run

# 4. 构建Release版本
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## 11. 注意事项

1. **数据合规**: 免费API仅供学习使用，商业用途需获取授权
2. **频率限制**: 注意API调用频率，避免被封IP
3. **免责声明**: APP提供分析仅供参考，不构成投资建议
4. **数据延迟**: 免费数据源可能存在延迟，不适合高频交易
