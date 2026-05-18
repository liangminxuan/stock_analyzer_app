# 股票分析助手 - AI驱动的股票投资分析APP

专为股市小白打造的智能股票分析工具，通过AI解读K线图、财报、公告，提供通俗易懂的投资分析建议。

## 功能特性

### 核心功能

1. **实时行情**
   - 大盘指数实时展示
   - 个股行情数据
   - 自选股管理

2. **K线分析**
   - 日/周/月K线展示
   - MA均线指标
   - AI智能解读K线形态
   - 支撑阻力位分析
   - 买卖建议

3. **财报解读**
   - 财务数据可视化
   - 关键指标提取
   - 同比环比分析
   - 财务健康度评分
   - 风险提示

4. **公告解读**
   - 公告分类展示
   - 利好/利空判断
   - 影响分析
   - 操作建议

5. **智能选股**
   - 多维度筛选
   - 热门策略推荐
   - AI智能推荐

### 技术特点

- **跨平台**: 基于Flutter，一套代码支持Android和iOS
- **免费数据源**: 集成新浪财经、腾讯财经、东方财富等免费API
- **AI分析**: 内置AI分析引擎，提供专业解读
- **响应式设计**: 适配各种屏幕尺寸

## 安装说明

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK >= 21
- iOS >= 11.0

### 安装步骤

1. 克隆项目
```bash
git clone <repository-url>
cd stock_analyzer_app
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行应用
```bash
# 开发模式
flutter run

# 构建Release版本
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── app.dart                  # 应用配置
├── config/                   # 配置文件
│   ├── theme.dart           # 主题配置
│   ├── routes.dart          # 路由配置
│   └── constants.dart       # 常量定义
├── models/                   # 数据模型
│   ├── stock.dart           # 股票模型
│   ├── kline.dart           # K线数据
│   ├── financial.dart       # 财务数据
│   └── announcement.dart    # 公告模型
├── services/                 # 服务层
│   ├── api_service.dart     # API服务
│   ├── stock_service.dart   # 股票数据服务
│   └── ai_service.dart      # AI分析服务
├── providers/                # 状态管理
│   ├── stock_provider.dart
│   ├── market_provider.dart
│   └── user_provider.dart
├── screens/                  # 页面
│   ├── main/                # 主框架
│   ├── home/                # 首页
│   ├── market/              # 行情
│   ├── finance/             # 财报
│   ├── news/                # 公告
│   ├── discovery/           # 选股
│   └── profile/             # 个人中心
└── widgets/                  # 通用组件
    ├── stock_card.dart
    ├── kline_chart.dart
    └── loading_widget.dart
```

## 数据源

### 免费API

1. **新浪财经**
   - 实时行情: `http://hq.sinajs.cn/list=sh600519`
   - K线图: `http://image.sinajs.cn/newchart/daily/n/sh600519.gif`

2. **腾讯财经**
   - 实时行情: `https://qt.gtimg.cn/q=sh600519`

3. **东方财富**
   - 历史K线: `https://push2his.eastmoney.com/api/qt/stock/kline/get`

## 免责声明

本应用提供的股票分析和建议仅供参考，不构成投资建议。股市有风险，投资需谨慎。用户应独立做出投资决策，并承担相应风险。

## 许可证

MIT License

## 更新日志

### v1.0.0 (2025-01)
- 初始版本发布
- 实现基础行情功能
- 实现K线展示和分析
- 实现AI解读功能
- 实现自选股管理
