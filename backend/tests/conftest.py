"""pytest 公共配置。

说明：app.py 顶部 `import akshare as ak`，而 akshare 会拉一堆重依赖
（真实环境见 requirements.txt）。单元测试只关心解析/缓存/路由逻辑，
这里用桩模块替换 akshare 与 tickflow，避免测试依赖外部网络与重依赖。
"""

import os
import sys
import types

import pytest

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)


def _install_stub(name, **attrs):
    if name in sys.modules:
        return sys.modules[name]
    module = types.ModuleType(name)
    for key, value in attrs.items():
        setattr(module, key, value)
    sys.modules[name] = module
    return module


def _missing(*_args, **_kwargs):
    raise RuntimeError('测试中不应真正调用 akshare/tickflow')


# 在导入 app 之前装好桩
_install_stub('akshare', stock_zh_a_spot_em=_missing, stock_zh_a_spot=_missing)
_install_stub('tickflow', TickFlow=types.SimpleNamespace(free=_missing))

import app as backend_app  # noqa: E402  (必须在桩安装之后导入)


@pytest.fixture
def client():
    backend_app.app.config.update(TESTING=True)
    with backend_app.app.test_client() as test_client:
        yield test_client


@pytest.fixture(autouse=True)
def reset_state():
    """每个用例前后都清理全局缓存，避免用例互相污染"""
    backend_app._cache.clear()
    backend_app._tencent_fundamentals_cache['ts'] = 0.0
    backend_app._tencent_fundamentals_cache['data'] = {}
    backend_app._stock_data_cache.update({
        'df': None,
        'last_update': 0,
        'loading': False,
        'load_error': None,
        'load_start_time': 0,
    })
    yield
    backend_app._cache.clear()
