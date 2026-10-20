"""
股票数据后端服务 - 多数据源获取公告、新闻、财报、选股数据

部署:
    gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 8 --timeout 60 app:app

分层结构（app.py 只做装配，不含业务逻辑）：

    settings.py        配置（全部来自环境变量）
    cache_store.py     进程内 TTL/LRU 缓存 + 单 IP 限流
    market_data.py     行情数据层（多数据源加载、腾讯基本面补充、快照、后台刷新）
    ai_engine.py       量化规则引擎（技术指标 + 基本面评分，非 LLM）
    routes_market.py   行情类路由（健康检查、快照状态、选股筛选、策略推荐、行业）
    routes_content.py  内容类路由（公告、新闻、财报、综合分析、公告解读、AI 评分、调试）
"""

import os

from flask import Flask
from flask_cors import CORS

import settings
from routes_content import content_bp
from routes_market import market_bp

app = Flask(__name__)

# CORS：默认不允许跨域（App 为原生客户端，不需要 CORS）。
# 如需给浏览器端调试，显式设置环境变量 ALLOWED_ORIGINS（逗号分隔）。
CORS(app, resources={r"/api/*": {"origins": settings.ALLOWED_ORIGINS}})

app.register_blueprint(market_bp)
app.register_blueprint(content_bp)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"股票数据后端服务启动... 端口: {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
