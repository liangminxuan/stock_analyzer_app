"""
AI 对冲基金选股引擎 - 基于 virattt/ai-hedge-fund 项目策略
纯 Python 计算，不依赖 LLM

包含：
1. 技术分析 5 大信号（趋势/均值回归/动量/波动率/统计套利）
2. 基本面 4 维评分（盈利能力/成长性/财务健康/估值比率）
3. 风险管理（波动率仓位限制/相关性调整）
4. 加权集成算法
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple


# ==================== 辅助技术指标函数 ====================

def calculate_ema(series: pd.Series, window: int) -> pd.Series:
    """指数移动平均线"""
    return series.ewm(span=window, adjust=False).mean()


def calculate_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """相对强弱指数 RSI"""
    delta = series.diff()
    gain = delta.where(delta > 0, 0.0)
    loss = (-delta).where(delta < 0, 0.0)
    avg_gain = gain.rolling(window=period, min_periods=period).mean()
    avg_loss = loss.rolling(window=period, min_periods=period).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    rsi = 100 - (100 / (1 + rs))
    return rsi


def calculate_bollinger_bands(series: pd.Series, window: int = 20, num_std: float = 2.0) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """布林带"""
    middle = series.rolling(window=window).mean()
    std = series.rolling(window=window).std()
    upper = middle + num_std * std
    lower = middle - num_std * std
    return upper, middle, lower


def calculate_adx(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """平均趋向指数 ADX"""
    high = df['high']
    low = df['low']
    close = df['close']

    tr1 = high - low
    tr2 = abs(high - close.shift(1))
    tr3 = abs(low - close.shift(1))
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)

    plus_dm = high.diff()
    minus_dm = -low.diff()
    plus_dm = plus_dm.where((plus_dm > minus_dm) & (plus_dm > 0), 0.0)
    minus_dm = minus_dm.where((minus_dm > plus_dm) & (minus_dm > 0), 0.0)

    atr = tr.rolling(window=period).mean()
    plus_di = 100 * (plus_dm.rolling(window=period).mean() / atr.replace(0, np.nan))
    minus_di = 100 * (minus_dm.rolling(window=period).mean() / atr.replace(0, np.nan))

    dx = 100 * abs(plus_di - minus_di) / (plus_di + minus_di).replace(0, np.nan)
    adx = dx.ewm(span=period, adjust=False).mean()
    return adx


def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """真实波动幅度 ATR"""
    high = df['high']
    low = df['low']
    close = df['close']
    tr1 = high - low
    tr2 = abs(high - close.shift(1))
    tr3 = abs(low - close.shift(1))
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    return tr.rolling(window=period).mean()


def calculate_hurst_exponent(series: pd.Series, max_lag: int = 20) -> float:
    """Hurst 指数 - R/S 分析法
    H < 0.5: 均值回归序列
    H = 0.5: 随机游走
    H > 0.5: 趋势序列
    """
    series = series.dropna().values
    if len(series) < max_lag * 2:
        return 0.5  # 数据不足，返回随机游走

    lags = range(2, max_lag + 1)
    rs_list = []
    for lag in lags:
        # 将序列分成若干子段
        n = len(series) // lag
        if n < 1:
            continue
        rs_values = []
        for i in range(n):
            segment = series[i * lag:(i + 1) * lag]
            if len(segment) < 2:
                continue
            mean = np.mean(segment)
            std = np.std(segment)
            if std == 0:
                continue
            cumdev = np.cumsum(segment - mean)
            rs = (np.max(cumdev) - np.min(cumdev)) / std
            rs_values.append(rs)
        if rs_values:
            rs_list.append(np.log(np.mean(rs_values)))
        else:
            rs_list.append(np.nan)

    if len(rs_list) < 2:
        return 0.5

    log_lags = np.log(list(lags)[:len(rs_list)])
    log_rs = np.array(rs_list)
    valid = ~np.isnan(log_rs)
    if valid.sum() < 2:
        return 0.5

    try:
        slope = np.polyfit(log_lags[valid], log_rs[valid], 1)[0]
        return min(max(slope, 0.0), 1.0)
    except:
        return 0.5


# ==================== 技术分析 5 大信号 ====================

def calc_trend_signal(df: pd.DataFrame) -> Dict:
    """趋势信号 - EMA 交叉 + ADX 趋势强度"""
    if len(df) < 55:
        return {"signal": "neutral", "confidence": 0.5, "details": "数据不足"}

    close = df['close']
    ema8 = calculate_ema(close, 8)
    ema21 = calculate_ema(close, 21)
    ema55 = calculate_ema(close, 55)
    adx = calculate_adx(df, 14)

    latest_ema8 = ema8.iloc[-1]
    latest_ema21 = ema21.iloc[-1]
    latest_ema55 = ema55.iloc[-1]
    latest_adx = adx.iloc[-1] if not pd.isna(adx.iloc[-1]) else 20

    short_bullish = latest_ema8 > latest_ema21
    mid_bullish = latest_ema21 > latest_ema55

    if short_bullish and mid_bullish:
        signal = "bullish"
    elif not short_bullish and not mid_bullish:
        signal = "bearish"
    else:
        signal = "neutral"

    confidence = min(latest_adx / 100, 1.0) if signal != "neutral" else 0.5

    return {
        "signal": signal,
        "confidence": round(confidence, 3),
        "details": f"EMA8={latest_ema8:.2f} EMA21={latest_ema21:.2f} EMA55={latest_ema55:.2f} ADX={latest_adx:.1f}",
        "indicators": {
            "ema8": round(latest_ema8, 2),
            "ema21": round(latest_ema21, 2),
            "ema55": round(latest_ema55, 2),
            "adx": round(latest_adx, 1),
            "short_trend": "上升" if short_bullish else "下降",
            "mid_trend": "上升" if mid_bullish else "下降",
        }
    }


def calc_mean_reversion_signal(df: pd.DataFrame) -> Dict:
    """均值回归信号 - Z-Score + 布林带 + RSI"""
    if len(df) < 50:
        return {"signal": "neutral", "confidence": 0.5, "details": "数据不足"}

    close = df['close']

    # Z-Score
    ma50 = close.rolling(50).mean()
    std50 = close.rolling(50).std()
    z_score = ((close.iloc[-1] - ma50.iloc[-1]) / std50.iloc[-1]) if std50.iloc[-1] > 0 else 0

    # Bollinger Bands
    bb_upper, bb_middle, bb_lower = calculate_bollinger_bands(close, 20)
    latest_close = close.iloc[-1]
    bb_width = bb_upper.iloc[-1] - bb_lower.iloc[-1]
    price_vs_bb = (latest_close - bb_lower.iloc[-1]) / bb_width if bb_width > 0 else 0.5

    # RSI
    rsi14 = calculate_rsi(close, 14)
    rsi28 = calculate_rsi(close, 28)
    latest_rsi14 = rsi14.iloc[-1] if not pd.isna(rsi14.iloc[-1]) else 50
    latest_rsi28 = rsi28.iloc[-1] if not pd.isna(rsi28.iloc[-1]) else 50

    # 信号判断
    if z_score < -2 and price_vs_bb < 0.2:
        signal = "bullish"
        confidence = min(abs(z_score) / 4, 1.0)
    elif z_score > 2 and price_vs_bb > 0.8:
        signal = "bearish"
        confidence = min(abs(z_score) / 4, 1.0)
    elif latest_rsi14 < 30:
        signal = "bullish"
        confidence = 0.6
    elif latest_rsi14 > 70:
        signal = "bearish"
        confidence = 0.6
    else:
        signal = "neutral"
        confidence = 0.5

    return {
        "signal": signal,
        "confidence": round(confidence, 3),
        "details": f"Z-Score={z_score:.2f} 价格位置={price_vs_bb:.2f} RSI14={latest_rsi14:.1f}",
        "indicators": {
            "z_score": round(z_score, 2),
            "price_vs_bb": round(price_vs_bb, 2),
            "rsi_14": round(latest_rsi14, 1),
            "rsi_28": round(latest_rsi28, 1),
            "bb_upper": round(bb_upper.iloc[-1], 2),
            "bb_lower": round(bb_lower.iloc[-1], 2),
        }
    }


def calc_momentum_signal(df: pd.DataFrame) -> Dict:
    """动量信号 - 多周期动量 + 成交量确认"""
    if len(df) < 126:
        return {"signal": "neutral", "confidence": 0.5, "details": "数据不足"}

    close = df['close']
    volume = df['volume']

    # 多周期动量
    mom_1m = (close.iloc[-1] / close.iloc[-22] - 1) if len(close) >= 22 else 0
    mom_3m = (close.iloc[-1] / close.iloc[-63] - 1) if len(close) >= 63 else 0
    mom_6m = (close.iloc[-1] / close.iloc[-126] - 1) if len(close) >= 126 else 0

    # 加权动量评分
    momentum_score = 0.4 * mom_1m + 0.3 * mom_3m + 0.3 * mom_6m

    # 成交量动量
    avg_vol_21 = volume.tail(21).mean()
    current_vol = volume.iloc[-1]
    volume_momentum = current_vol / avg_vol_21 if avg_vol_21 > 0 else 1.0

    # 信号判断
    if momentum_score > 0.05 and volume_momentum > 1.0:
        signal = "bullish"
        confidence = min(abs(momentum_score) * 5, 1.0)
    elif momentum_score < -0.05 and volume_momentum > 1.0:
        signal = "bearish"
        confidence = min(abs(momentum_score) * 5, 1.0)
    else:
        signal = "neutral"
        confidence = 0.5

    return {
        "signal": signal,
        "confidence": round(confidence, 3),
        "details": f"1月动量={mom_1m*100:.1f}% 3月={mom_3m*100:.1f}% 6月={mom_6m*100:.1f}% 量比={volume_momentum:.2f}",
        "indicators": {
            "momentum_1m": round(mom_1m * 100, 2),
            "momentum_3m": round(mom_3m * 100, 2),
            "momentum_6m": round(mom_6m * 100, 2),
            "volume_momentum": round(volume_momentum, 2),
            "momentum_score": round(momentum_score * 100, 2),
        }
    }


def calc_volatility_signal(df: pd.DataFrame) -> Dict:
    """波动率信号 - 历史波动率 + 波动率体制 + ATR"""
    if len(df) < 63:
        return {"signal": "neutral", "confidence": 0.5, "details": "数据不足"}

    close = df['close']
    returns = close.pct_change().dropna()

    # 历史波动率（年化）
    daily_vol = returns.tail(21).std()
    annualized_vol = daily_vol * np.sqrt(252)

    # 波动率体制
    rolling_vol = returns.rolling(63).std() * np.sqrt(252)
    vol_mean = rolling_vol.tail(63).mean()
    vol_regime = annualized_vol / vol_mean if vol_mean > 0 else 1.0

    # 波动率 Z-Score
    vol_std = rolling_vol.tail(63).std()
    vol_z = (annualized_vol - vol_mean) / vol_std if vol_std > 0 else 0

    # ATR 比率
    atr = calculate_atr(df, 14)
    atr_ratio = atr.iloc[-1] / close.iloc[-1] if close.iloc[-1] > 0 else 0

    # 信号判断
    if vol_regime < 0.8 and vol_z < -1:
        signal = "bullish"  # 低波动率，可能扩张
        confidence = min(abs(vol_z) / 3, 1.0)
    elif vol_regime > 1.2 and vol_z > 1:
        signal = "bearish"  # 高波动率，风险增大
        confidence = min(abs(vol_z) / 3, 1.0)
    else:
        signal = "neutral"
        confidence = 0.5

    return {
        "signal": signal,
        "confidence": round(confidence, 3),
        "details": f"年化波动率={annualized_vol*100:.1f}% 体制={vol_regime:.2f} ATR比率={atr_ratio:.4f}",
        "indicators": {
            "historical_volatility": round(annualized_vol * 100, 2),
            "volatility_regime": round(vol_regime, 2),
            "volatility_z_score": round(vol_z, 2),
            "atr_ratio": round(atr_ratio, 4),
        }
    }


def calc_stat_arb_signal(df: pd.DataFrame) -> Dict:
    """统计套利信号 - 偏度 + 峰度 + Hurst 指数"""
    if len(df) < 63:
        return {"signal": "neutral", "confidence": 0.5, "details": "数据不足"}

    close = df['close']
    returns = close.pct_change().dropna().tail(63)

    # 偏度和峰度
    skewness = float(returns.skew())
    kurtosis = float(returns.kurtosis())

    # Hurst 指数
    hurst = calculate_hurst_exponent(close.tail(126))

    # 信号判断
    if hurst < 0.4 and skewness > 1:
        signal = "bullish"  # 均值回归 + 正偏度
        confidence = (0.5 - hurst) * 2
    elif hurst < 0.4 and skewness < -1:
        signal = "bearish"  # 均值回归 + 负偏度
        confidence = (0.5 - hurst) * 2
    else:
        signal = "neutral"
        confidence = 0.5

    # Hurst 含义
    if hurst < 0.4:
        hurst_desc = "均值回归趋势"
    elif hurst > 0.6:
        hurst_desc = "强趋势延续"
    else:
        hurst_desc = "随机游走"

    return {
        "signal": signal,
        "confidence": round(confidence, 3),
        "details": f"Hurst={hurst:.3f}({hurst_desc}) 偏度={skewness:.2f} 峰度={kurtosis:.2f}",
        "indicators": {
            "hurst_exponent": round(hurst, 3),
            "skewness": round(skewness, 2),
            "kurtosis": round(kurtosis, 2),
            "hurst_interpretation": hurst_desc,
        }
    }


def calculate_technical_signals(df: pd.DataFrame) -> Dict:
    """技术分析综合信号 - 5 大策略加权集成"""
    if df is None or len(df) < 20:
        return {"overall": {"signal": "neutral", "confidence": 0, "score": 0}, "strategies": {}}

    # 确保 DataFrame 有正确的列
    required_cols = ['open', 'high', 'low', 'close', 'volume']
    for col in required_cols:
        if col not in df.columns:
            return {"overall": {"signal": "neutral", "confidence": 0, "score": 0, "error": f"缺少{col}列"}, "strategies": {}}

    # 计算各策略信号
    strategies = {
        "trend": calc_trend_signal(df),
        "mean_reversion": calc_mean_reversion_signal(df),
        "momentum": calc_momentum_signal(df),
        "volatility": calc_volatility_signal(df),
        "stat_arb": calc_stat_arb_signal(df),
    }

    # 加权集成
    weights = {
        "trend": 0.25,
        "mean_reversion": 0.20,
        "momentum": 0.25,
        "volatility": 0.15,
        "stat_arb": 0.15,
    }

    signal_map = {"bullish": 1, "neutral": 0, "bearish": -1}
    weighted_sum = 0
    total_confidence = 0

    for name, strategy in strategies.items():
        s = strategy.get("signal", "neutral")
        c = strategy.get("confidence", 0.5)
        w = weights.get(name, 0.2)
        weighted_sum += signal_map.get(s, 0) * w * c
        total_confidence += w * c

    final_score = weighted_sum / total_confidence if total_confidence > 0 else 0

    if final_score > 0.2:
        overall_signal = "bullish"
    elif final_score < -0.2:
        overall_signal = "bearish"
    else:
        overall_signal = "neutral"

    return {
        "overall": {
            "signal": overall_signal,
            "confidence": round(abs(final_score), 3),
            "score": round(final_score, 3),
            "description": _signal_to_chinese(overall_signal),
        },
        "strategies": strategies,
        "weights": weights,
    }


def _signal_to_chinese(signal: str) -> str:
    """信号转中文"""
    mapping = {
        "bullish": "看多（买入信号）",
        "bearish": "看空（卖出信号）",
        "neutral": "中性（观望）",
    }
    return mapping.get(signal, "未知")


# ==================== 基本面 4 维评分 ====================

def calculate_fundamental_score(metrics: Dict) -> Dict:
    """
    基本面 4 维评分

    输入 metrics 字典：
    - roe: 净资产收益率 (%)
    - net_margin: 净利率 (%)
    - operating_margin: 营业利润率 (%)
    - revenue_growth: 营收增长率 (%)
    - earnings_growth: 盈利增长率 (%)
    - book_value_growth: 账面价值增长率 (%)
    - current_ratio: 流动比率
    - debt_to_equity: 负债权益比
    - fcf_per_share: 每股自由现金流
    - eps: 每股收益
    - pe: 市盈率
    - pb: 市净率
    - ps: 市销率（可选）
    """
    dimensions = {}

    # 维度1: 盈利能力
    profitability_signals = []
    if metrics.get("roe") and metrics["roe"] > 15:
        profitability_signals.append("bullish")
    elif metrics.get("roe") and metrics["roe"] < 8:
        profitability_signals.append("bearish")
    else:
        profitability_signals.append("neutral")

    if metrics.get("net_margin") and metrics["net_margin"] > 20:
        profitability_signals.append("bullish")
    elif metrics.get("net_margin") and metrics["net_margin"] < 5:
        profitability_signals.append("bearish")
    else:
        profitability_signals.append("neutral")

    if metrics.get("operating_margin") and metrics["operating_margin"] > 15:
        profitability_signals.append("bullish")
    elif metrics.get("operating_margin") and metrics["operating_margin"] < 5:
        profitability_signals.append("bearish")
    else:
        profitability_signals.append("neutral")

    bull_count = profitability_signals.count("bullish")
    bear_count = profitability_signals.count("bearish")
    if bull_count >= 2:
        dimensions["profitability"] = {"signal": "bullish", "score": bull_count / 3,
            "details": f"ROE={metrics.get('roe','N/A')}% 净利率={metrics.get('net_margin','N/A')}%"}
    elif bear_count >= 2:
        dimensions["profitability"] = {"signal": "bearish", "score": bear_count / 3,
            "details": f"ROE={metrics.get('roe','N/A')}% 净利率={metrics.get('net_margin','N/A')}%"}
    else:
        dimensions["profitability"] = {"signal": "neutral", "score": 0.5,
            "details": f"ROE={metrics.get('roe','N/A')}% 净利率={metrics.get('net_margin','N/A')}%"}

    # 维度2: 成长性
    growth_signals = []
    for key, label in [("revenue_growth", "营收"), ("earnings_growth", "盈利"), ("book_value_growth", "账面价值")]:
        val = metrics.get(key)
        if val and val > 10:
            growth_signals.append("bullish")
        elif val and val < 0:
            growth_signals.append("bearish")
        else:
            growth_signals.append("neutral")

    bull_count = growth_signals.count("bullish")
    bear_count = growth_signals.count("bearish")
    if bull_count >= 2:
        dimensions["growth"] = {"signal": "bullish", "score": bull_count / 3,
            "details": f"营收增长={metrics.get('revenue_growth','N/A')}% 盈利增长={metrics.get('earnings_growth','N/A')}%"}
    elif bear_count >= 2:
        dimensions["growth"] = {"signal": "bearish", "score": bear_count / 3,
            "details": f"营收增长={metrics.get('revenue_growth','N/A')}% 盈利增长={metrics.get('earnings_growth','N/A')}%"}
    else:
        dimensions["growth"] = {"signal": "neutral", "score": 0.5,
            "details": f"营收增长={metrics.get('revenue_growth','N/A')}% 盈利增长={metrics.get('earnings_growth','N/A')}%"}

    # 维度3: 财务健康
    health_signals = []
    if metrics.get("current_ratio") and metrics["current_ratio"] > 1.5:
        health_signals.append("bullish")
    elif metrics.get("current_ratio") and metrics["current_ratio"] < 1.0:
        health_signals.append("bearish")
    else:
        health_signals.append("neutral")

    if metrics.get("debt_to_equity") and metrics["debt_to_equity"] < 0.5:
        health_signals.append("bullish")
    elif metrics.get("debt_to_equity") and metrics["debt_to_equity"] > 1.5:
        health_signals.append("bearish")
    else:
        health_signals.append("neutral")

    fcf = metrics.get("fcf_per_share", 0)
    eps = metrics.get("eps", 0)
    if fcf and eps and fcf / eps > 0.8:
        health_signals.append("bullish")
    elif fcf and eps and fcf < 0:
        health_signals.append("bearish")
    else:
        health_signals.append("neutral")

    bull_count = health_signals.count("bullish")
    bear_count = health_signals.count("bearish")
    if bull_count >= 2:
        dimensions["financial_health"] = {"signal": "bullish", "score": bull_count / 3,
            "details": f"流动比率={metrics.get('current_ratio','N/A')} 负债率={metrics.get('debt_to_equity','N/A')}"}
    elif bear_count >= 2:
        dimensions["financial_health"] = {"signal": "bearish", "score": bear_count / 3,
            "details": f"流动比率={metrics.get('current_ratio','N/A')} 负债率={metrics.get('debt_to_equity','N/A')}"}
    else:
        dimensions["financial_health"] = {"signal": "neutral", "score": 0.5,
            "details": f"流动比率={metrics.get('current_ratio','N/A')} 负债率={metrics.get('debt_to_equity','N/A')}"}

    # 维度4: 估值比率（反向指标）
    valuation_signals = []
    if metrics.get("pe") and metrics["pe"] > 0:
        if metrics["pe"] < 15:
            valuation_signals.append("bullish")
        elif metrics["pe"] > 35:
            valuation_signals.append("bearish")
        else:
            valuation_signals.append("neutral")
    else:
        valuation_signals.append("neutral")

    if metrics.get("pb") and metrics["pb"] > 0:
        if metrics["pb"] < 1.5:
            valuation_signals.append("bullish")
        elif metrics["pb"] > 4:
            valuation_signals.append("bearish")
        else:
            valuation_signals.append("neutral")
    else:
        valuation_signals.append("neutral")

    bull_count = valuation_signals.count("bullish")
    bear_count = valuation_signals.count("bearish")
    if bull_count >= 1:
        dimensions["valuation"] = {"signal": "bullish", "score": (bull_count + 1) / 3,
            "details": f"PE={metrics.get('pe','N/A')} PB={metrics.get('pb','N/A')}"}
    elif bear_count >= 1:
        dimensions["valuation"] = {"signal": "bearish", "score": (bear_count + 1) / 3,
            "details": f"PE={metrics.get('pe','N/A')} PB={metrics.get('pb','N/A')}"}
    else:
        dimensions["valuation"] = {"signal": "neutral", "score": 0.5,
            "details": f"PE={metrics.get('pe','N/A')} PB={metrics.get('pb','N/A')}"}

    # 综合评分
    all_bullish = sum(1 for d in dimensions.values() if d["signal"] == "bullish")
    all_bearish = sum(1 for d in dimensions.values() if d["signal"] == "bearish")
    total = len(dimensions)

    if all_bullish > all_bearish:
        overall_signal = "bullish"
    elif all_bearish > all_bullish:
        overall_signal = "bearish"
    else:
        overall_signal = "neutral"

    overall_confidence = max(all_bullish, all_bearish) / total

    return {
        "overall": {
            "signal": overall_signal,
            "confidence": round(overall_confidence, 3),
            "description": _signal_to_chinese(overall_signal),
            "bullish_dimensions": all_bullish,
            "bearish_dimensions": all_bearish,
        },
        "dimensions": dimensions,
    }


# ==================== 风险管理 ====================

def calculate_risk_metrics(df: pd.DataFrame) -> Dict:
    """计算风险指标和仓位限制"""
    if df is None or len(df) < 60:
        return {"error": "数据不足（需要至少60个交易日）"}

    close = df['close']
    returns = close.pct_change().dropna()

    # 波动率
    daily_vol = returns.tail(60).std()
    annualized_vol = daily_vol * np.sqrt(252)

    # 波动率历史分位数
    rolling_30d_vol = returns.tail(60).rolling(30).std() * np.sqrt(252)
    vol_percentile = (rolling_30d_vol <= annualized_vol).mean() * 100

    # 最大回撤
    cummax = close.cummax()
    drawdown = (close - cummax) / cummax
    max_drawdown = drawdown.min()

    # 波动率调整仓位上限
    base_limit = 20  # 基础仓位上限 20%
    if annualized_vol < 0.15:
        vol_multiplier = 1.25
    elif annualized_vol < 0.30:
        vol_multiplier = 1.0 - (annualized_vol - 0.15) * 2
    elif annualized_vol < 0.50:
        vol_multiplier = 0.75 - (annualized_vol - 0.30) * 2.5
    else:
        vol_multiplier = 0.25

    vol_multiplier = max(0.25, min(1.25, vol_multiplier))
    vol_adjusted_limit = base_limit * vol_multiplier

    # 风险等级
    if annualized_vol < 0.20:
        risk_level = "低风险"
        risk_color = "green"
    elif annualized_vol < 0.35:
        risk_level = "中等风险"
        risk_color = "yellow"
    elif annualized_vol < 0.50:
        risk_level = "高风险"
        risk_color = "orange"
    else:
        risk_level = "极高风险"
        risk_color = "red"

    return {
        "annualized_volatility": round(annualized_vol * 100, 2),
        "volatility_percentile": round(vol_percentile, 1),
        "max_drawdown": round(max_drawdown * 100, 2),
        "daily_volatility": round(daily_vol * 100, 4),
        "position_limit_pct": round(vol_adjusted_limit, 1),
        "risk_level": risk_level,
        "risk_color": risk_color,
        "suggestion": f"建议单只股票仓位不超过总资金的 {vol_adjusted_limit:.1f}%",
    }


# ==================== 综合分析 ====================

def full_ai_analysis(df: pd.DataFrame, metrics: Optional[Dict] = None) -> Dict:
    """
    完整的 AI 选股分析

    参数:
    - df: OHLCV DataFrame (至少 126 行，列: open/high/low/close/volume)
    - metrics: 基本面指标字典 (可选)

    返回: 综合分析结果
    """
    result = {}

    # 1. 技术分析
    result["technical"] = calculate_technical_signals(df)

    # 2. 基本面分析
    if metrics:
        result["fundamental"] = calculate_fundamental_score(metrics)
    else:
        result["fundamental"] = None

    # 3. 风险管理
    result["risk"] = calculate_risk_metrics(df)

    # 4. 综合评分
    tech_score = result["technical"]["overall"]["score"]  # -1 to 1
    tech_conf = result["technical"]["overall"]["confidence"]

    # 综合信号（技术 60% + 基本面 40%）
    if result["fundamental"]:
        fund_signal = result["fundamental"]["overall"]["signal"]
        fund_map = {"bullish": 1, "neutral": 0, "bearish": -1}
        fund_score = fund_map.get(fund_signal, 0) * result["fundamental"]["overall"]["confidence"]
        final_score = tech_score * 0.6 + fund_score * 0.4
    else:
        final_score = tech_score
        fund_score = 0

    if final_score > 0.2:
        final_signal = "bullish"
    elif final_score < -0.2:
        final_signal = "bearish"
    else:
        final_signal = "neutral"

    result["overall"] = {
        "signal": final_signal,
        "confidence": round(abs(final_score), 3),
        "score": round(final_score, 3),
        "description": _signal_to_chinese(final_signal),
        "tech_weight": 0.6,
        "fund_weight": 0.4,
    }

    # 5. 操作建议
    risk = result.get("risk", {})
    position_limit = risk.get("position_limit_pct", 20)

    if final_signal == "bullish" and final_score > 0.4:
        action = "建议买入"
        action_detail = f"技术面和基本面共振看多，建议仓位不超过 {position_limit:.0f}%"
    elif final_signal == "bullish":
        action = "可考虑买入"
        action_detail = f"信号偏多但强度一般，建议仓位不超过 {position_limit * 0.5:.0f}%"
    elif final_signal == "bearish" and final_score < -0.4:
        action = "建议回避"
        action_detail = "技术面和基本面共振看空，建议减仓或观望"
    elif final_signal == "bearish":
        action = "谨慎观望"
        action_detail = "信号偏空但强度一般，建议控制仓位"
    else:
        action = "观望等待"
        action_detail = "多空信号不明确，建议等待 clearer 信号"

    result["action"] = {
        "recommendation": action,
        "detail": action_detail,
        "position_limit": position_limit,
    }

    return result
