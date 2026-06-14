# DivergenceIndicators

Two divergence indicators: Klinger Oscillator with divergence detection, and Stochastic with divergence detection.

> **Proprietary software** — © Teenodi Ltd. All rights reserved. Private repository; not for distribution. See [LICENSE](LICENSE).

## KlingerDivergence.mq5

_Klinger Oscillator with Divergence Detection_

### Inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `InpPeriodFast` | uint | `34` | Fast period |
| `InpPeriodSlow` | uint | `55` | Slow period |
| `InpPeriodSig` | uint | `13` | Signal period |
| `DrawPriceLines` | bool | `false` | Draw Price Lines |
| `DrawArrows` | bool | `true` | Draw Arrows |
| `drawDivergenceLines` | bool | `true` | Draw Divergence Lines |
| `displayAlert` | bool | `false` | Display Alert |

## StochasticsDivergence.mq5

### Inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `KPeriod` | int | `5` | K Period |
| `DPeriod` | int | `3` | D Period   |
| `Slowing` | int | `3` | Slowing |
| `DrawPriceLines` | bool | `false` | Draw Price Lines |
| `DrawArrows` | bool | `true` | Draw Arrows |
| `drawDivergenceLines` | bool | `true` | Draw Divergence Lines |
| `displayAlert` | bool | `false` | Display Alert |

## Archive

Earlier versions / forks are preserved under [`archive/`](archive/) for reference.

## Install

1. Copy the source file(s) into your MetaTrader 5 `MQL5/` tree (`Experts/`, `Indicators/`, or `Scripts/` as appropriate).
2. In MetaEditor, open the file and compile (**F7**).
3. Attach the compiled program to a chart from the terminal Navigator.

## License

Proprietary and confidential. © Teenodi Ltd. All rights reserved. See [LICENSE](LICENSE).
