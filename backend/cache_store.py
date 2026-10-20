"""进程内 TTL/LRU 缓存与单 IP 限流（不引入额外依赖）。"""

import functools
import os
import threading
import time
from collections import OrderedDict

from flask import jsonify, request

# 缓存：减少重复请求（带 TTL + 容量上限，避免无界增长）
_cache = OrderedDict()          # key -> (过期时间戳, 数据)
_CACHE_MAX_ENTRIES = 256

def get_cached(key, timeout_seconds=300):
    """获取缓存数据（过期自动失效并清理）"""
    entry = _cache.get(key)
    if entry is None:
        return None
    expires_at, data = entry
    if time.time() >= expires_at:
        _cache.pop(key, None)
        return None
    _cache.move_to_end(key)
    return data

def set_cached(key, data, timeout_seconds=300):
    """设置缓存数据（超出容量时淘汰最久未使用的条目）"""
    _cache[key] = (time.time() + timeout_seconds, data)
    _cache.move_to_end(key)
    while len(_cache) > _CACHE_MAX_ENTRIES:
        _cache.popitem(last=False)


# ==================== 简易限流（不引入额外依赖）====================
#
# 背景（AUDIT_REPORT.md P1-3）：所有接口此前无任何速率限制，
# 一个脚本就能把免费实例刷爆。这里做单 IP 滑动窗口限流。
_rate_limit_lock = threading.Lock()
_rate_limit_hits = {}          # ip -> [命中时间戳]
_RATE_LIMIT_MAX_KEYS = 4096    # 防止 IP 维度内存无界增长

def _client_ip():
    forwarded = request.headers.get('X-Forwarded-For', '')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.remote_addr or 'unknown'

def rate_limit(func):
    """单 IP 滑动窗口限流装饰器。

    可用环境变量调整：RATE_LIMIT_MAX_REQUESTS（默认 60）、
    RATE_LIMIT_WINDOW_SECONDS（默认 60）。
    """
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        limit = int(os.environ.get('RATE_LIMIT_MAX_REQUESTS', '60'))
        window = int(os.environ.get('RATE_LIMIT_WINDOW_SECONDS', '60'))
        if limit <= 0:
            return func(*args, **kwargs)

        key = _client_ip()
        now = time.time()
        with _rate_limit_lock:
            hits = [t for t in _rate_limit_hits.get(key, []) if now - t < window]
            if len(hits) >= limit:
                return jsonify({'success': False, 'error': '请求过于频繁，请稍后重试'}), 429
            hits.append(now)
            _rate_limit_hits[key] = hits
            if len(_rate_limit_hits) > _RATE_LIMIT_MAX_KEYS:
                for stale in list(_rate_limit_hits)[:len(_rate_limit_hits) - _RATE_LIMIT_MAX_KEYS]:
                    _rate_limit_hits.pop(stale, None)
        return func(*args, **kwargs)

    return wrapper
