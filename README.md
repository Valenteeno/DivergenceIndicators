# DivergenceIndicators

Indicators for MetaTrader 5 that detect divergence between price and the Klinger Oscillator or the Stochastic.

> **Proprietary software.** © Teenodi Ltd. All rights reserved. The code is shared for viewing only. It is not licensed for reuse or redistribution. See [LICENSE](LICENSE).

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

## Risk note

Trading carries risk. This code shows how the strategy is built. It is not financial advice.

## License

Proprietary. © Teenodi Ltd. All rights reserved. The code is shared for viewing only. See [LICENSE](LICENSE).
