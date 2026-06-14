//+------------------------------------------------------------------+
//|                                        KlingerDivergence.mq5     |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Valenteeno"
#property link      "val.chioke@gmail.com"
#property version   "1.00"
#property description "Klinger Oscillator with Divergence Detection"
#property indicator_separate_window
#property indicator_buffers 11
#property indicator_plots   4
//--- plot Klinger Line
#property indicator_label1  "Klinger"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Signal Line
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot Buy
#property indicator_label3  "Buy"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
//--- plot Sell
#property indicator_label4  "Sell"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <ChartObjects\ChartObjectsLines.mqh>
#include <MovingAverages.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input uint     InpPeriodFast  =  34;            // Fast period
input uint     InpPeriodSlow  =  55;            // Slow period
input uint     InpPeriodSig   =  13;            // Signal period
input bool     DrawPriceLines = false;          // Draw Price Lines
input bool     DrawArrows = true;               // Draw Arrows
input bool     drawDivergenceLines = true;      // Draw Divergence Lines
input bool     displayAlert = false;            // Display Alert

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double BufferKlinger[];
double BufferSignal[];
double BuyBuffer[];
double SellBuffer[];
double BufferDM[];
double BufferCM[];
double BufferTR[];
double BufferVF[];
double BufferAvgFVF[];
double BufferAvgSVF[];
double BufferMA[];

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
string indicatorName;
datetime lastAlertTime;
int handle_ma;
int period_fast;
int period_slow;
int period_max;
int period_sig;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set global variables
   period_fast = int(InpPeriodFast < 2 ? 2 : InpPeriodFast);
   period_slow = int(InpPeriodSlow < 2 ? 2 : InpPeriodSlow);
   period_sig = int(InpPeriodSig < 2 ? 2 : InpPeriodSig);
   period_max = fmax(period_fast, fmax(period_slow, period_sig));
   
   // Set indicator buffers mapping
   SetIndexBuffer(0, BufferKlinger, INDICATOR_DATA);
   SetIndexBuffer(1, BufferSignal, INDICATOR_DATA);
   SetIndexBuffer(2, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, BufferDM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferCM, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferTR, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufferVF, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, BufferAvgFVF, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, BufferAvgSVF, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, BufferMA, INDICATOR_CALCULATIONS);
   
   // Set arrow codes
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   
   // Set empty values
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0);
   
   // Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, Digits() + 2);
   
   // Set indicator name
   indicatorName = "Klinger(" + (string)period_fast + "," + (string)period_slow + "," + (string)period_sig + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, "KlingerDivergence(" + (string)period_fast + "," + (string)period_slow + "," + (string)period_sig + ")");
   
   // Setting plot buffer parameters
   PlotIndexSetString(0, PLOT_LABEL, "Klinger(" + (string)period_fast + "," + (string)period_slow + ")");
   PlotIndexSetString(1, PLOT_LABEL, "Signal(" + (string)period_sig + ")");
   
   // Setting buffer arrays as timeseries
   ArraySetAsSeries(BufferKlinger, true);
   ArraySetAsSeries(BufferSignal, true);
   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);
   ArraySetAsSeries(BufferDM, true);
   ArraySetAsSeries(BufferCM, true);
   ArraySetAsSeries(BufferTR, true);
   ArraySetAsSeries(BufferVF, true);
   ArraySetAsSeries(BufferAvgFVF, true);
   ArraySetAsSeries(BufferAvgSVF, true);
   ArraySetAsSeries(BufferMA, true);
   
   // Create MA's handles
   ResetLastError();
   handle_ma = iMA(NULL, PERIOD_CURRENT, 1, 0, MODE_SMA, PRICE_TYPICAL);
   if(handle_ma == INVALID_HANDLE)
   {
      Print("The iMA(1) by PRICE_TYPICAL object was not created: Error ", GetLastError());
      return INIT_FAILED;
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove divergence lines
   for(int i = ObjectsTotal(0, -1, OBJ_TREND) - 1; i >= 0; i--)
   {
      string label = ObjectName(0, i, -1, OBJ_TREND);
      if(StringFind(label, "DivergenceLine") >= 0 || StringFind(label, "Klinger_DivergenceLine") >= 0)
         ObjectDelete(0, label);
   }
   
   // Remove arrows
   for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
   {
      string label = ObjectName(0, i, -1, OBJ_ARROW);
      if(StringFind(label, "KlingerD") >= 0)
         ObjectDelete(0, label);
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Setting buffer arrays as timeseries (only on first call for efficiency)
   static bool arraysInitialized = false;
   if(!arraysInitialized)
   {
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(tick_volume, true);
      ArraySetAsSeries(time, true);
      arraysInitialized = true;
   }
   
   // Check and calculate number of calculated bars
   if(rates_total < fmax(period_max, 4)) return 0;
   
   // Check and calculate number of calculated bars
   int limit = rates_total - prev_calculated;
   if(limit > 1)
   {
      limit = rates_total - 2;
      ArrayInitialize(BufferKlinger, 0);
      ArrayInitialize(BufferSignal, 0);
      ArrayInitialize(BuyBuffer, 0);
      ArrayInitialize(SellBuffer, 0);
      ArrayInitialize(BufferDM, 0);
      ArrayInitialize(BufferCM, 0);
      ArrayInitialize(BufferTR, 0);
      ArrayInitialize(BufferVF, 0);
      ArrayInitialize(BufferAvgFVF, 0);
      ArrayInitialize(BufferAvgSVF, 0);
      ArrayInitialize(BufferMA, 0);
   }
   
   // Prepare data
   int count = (limit > 1 ? rates_total : 1), copied = 0;
   copied = CopyBuffer(handle_ma, 0, 0, count, BufferMA);
   if(copied != count) return 0;
   
   // Calculate Klinger components (optimized - removed unnecessary initializations)
   for(int i = limit; i >= 0 && !IsStopped(); i--)
   {
      BufferDM[i] = high[i] - low[i];
      BufferTR[i] = (BufferMA[i] > BufferMA[i+1] ? 1 : BufferMA[i] < BufferMA[i+1] ? -1 : BufferTR[i+1]);
      BufferCM[i] = (BufferTR[i] == BufferTR[i+1] ? BufferCM[i] + BufferDM[i] : BufferDM[i+1] + BufferDM[i]);
      BufferVF[i] = (BufferCM[i] == 0 ? 0 : tick_volume[i] * fabs(2.0 * BufferDM[i] / BufferCM[i] + 1) * BufferTR[i] * 100.0);
   }
   
   if(ExponentialMAOnBuffer(rates_total, prev_calculated, 0, period_fast, BufferVF, BufferAvgFVF) == 0)
      return 0;
   if(ExponentialMAOnBuffer(rates_total, prev_calculated, 0, period_slow, BufferVF, BufferAvgSVF) == 0)
      return 0;
   
   // Calculate Klinger Oscillator
   for(int i = limit; i >= 0 && !IsStopped(); i--)
      BufferKlinger[i] = BufferAvgFVF[i] - BufferAvgSVF[i];
   
   if(ExponentialMAOnBuffer(rates_total, prev_calculated, 0, period_sig, BufferKlinger, BufferSignal) == 0)
      return 0;
   
   // Calculate divergences (optimized - avoid double detection)
   if(limit > 1)
   {
      // Full recalculation: process all bars
      CalculateIndicator(limit, rates_total, time, high, low);
   }
   else
   {
      // Incremental update: use fallback detection for recent bars only
      if(rates_total > 10)
      {
         int recentBar = 2; // Check bar index 2 (3rd most recent)
         if(recentBar < rates_total - 5)
         {
            CatchBullishDivergence(recentBar, rates_total, time, low);
            CatchBearishDivergence(recentBar, rates_total, time, high);
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Indicator                                              |
//+------------------------------------------------------------------+
void CalculateIndicator(int limit, int rates_total, const datetime &time[], const double &high[], const double &low[])
{
   for(int i = limit; i >= 0; i--)
   {
      if(i >= 2)
      {
         CatchBullishDivergence(i + 2, rates_total, time, low);
         CatchBearishDivergence(i + 2, rates_total, time, high);
      }
   }
}

//+------------------------------------------------------------------+
//| Catch Bullish Divergence                                        |
//+------------------------------------------------------------------+
void CatchBullishDivergence(int shift, int maxind, const datetime &time[], const double &low[])
{
   if(!IsIndicatorTrough(shift))
      return;
      
   int currentTrough = shift;
   int lastTrough = GetIndicatorLastTrough(shift, maxind);
   
   if(currentTrough == -1 || lastTrough == -1)
      return;
   
   // Classical bullish divergence
   if(BufferKlinger[currentTrough] > BufferKlinger[lastTrough] && low[currentTrough] < low[lastTrough])
   {
      BuyBuffer[currentTrough] = BufferKlinger[currentTrough];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentTrough], time[lastTrough], low[currentTrough],
                           low[lastTrough], clrGreen, STYLE_SOLID);
         DrawIndicatorTrendLine(time[currentTrough], time[lastTrough], BufferKlinger[currentTrough],
                               BufferKlinger[lastTrough], clrGreen, STYLE_SOLID, true);
      }
      if(displayAlert)
         DisplayAlert("Classical bullish divergence on: ", currentTrough);
   }
   
   // Reverse bullish divergence
   if(BufferKlinger[currentTrough] < BufferKlinger[lastTrough] && low[currentTrough] > low[lastTrough])
   {
      BuyBuffer[currentTrough] = BufferKlinger[currentTrough];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentTrough], time[lastTrough], low[currentTrough],
                           low[lastTrough], clrGreen, STYLE_DOT);
         DrawIndicatorTrendLine(time[currentTrough], time[lastTrough], BufferKlinger[currentTrough],
                               BufferKlinger[lastTrough], clrGreen, STYLE_DOT, true);
      }
      if(displayAlert)
         DisplayAlert("Reverse bullish divergence on: ", currentTrough);
   }
}

//+------------------------------------------------------------------+
//| Catch Bearish Divergence                                        |
//+------------------------------------------------------------------+
void CatchBearishDivergence(int shift, int maxind, const datetime &time[], const double &high[])
{
   if(!IsIndicatorPeak(shift))
      return;
      
   int currentPeak = shift;
   int lastPeak = GetIndicatorLastPeak(shift, maxind);
   
   if(currentPeak == -1 || lastPeak == -1)
      return;
   
   // Classical bearish divergence
   if(BufferKlinger[currentPeak] < BufferKlinger[lastPeak] && high[currentPeak] > high[lastPeak])
   {
      SellBuffer[currentPeak] = BufferKlinger[currentPeak];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentPeak], time[lastPeak], high[currentPeak],
                           high[lastPeak], clrRed, STYLE_SOLID);
         DrawIndicatorTrendLine(time[currentPeak], time[lastPeak], BufferKlinger[currentPeak],
                               BufferKlinger[lastPeak], clrRed, STYLE_SOLID, false);
      }
      if(displayAlert)
         DisplayAlert("Classical bearish divergence on: ", currentPeak);
   }
   
   // Reverse bearish divergence
   if(BufferKlinger[currentPeak] > BufferKlinger[lastPeak] && high[currentPeak] < high[lastPeak])
   {
      SellBuffer[currentPeak] = BufferKlinger[currentPeak];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentPeak], time[lastPeak], high[currentPeak],
                           high[lastPeak], clrRed, STYLE_DOT);
         DrawIndicatorTrendLine(time[currentPeak], time[lastPeak], BufferKlinger[currentPeak],
                               BufferKlinger[lastPeak], clrRed, STYLE_DOT, false);
      }
      if(displayAlert)
         DisplayAlert("Reverse bearish divergence on: ", currentPeak);
   }
}

//+------------------------------------------------------------------+
//| Check if indicator is at peak                                   |
//+------------------------------------------------------------------+
bool IsIndicatorPeak(int shift)
{
   if(shift <= 0 || shift >= ArraySize(BufferKlinger) - 2)
      return false;
      
   if(BufferKlinger[shift] >= BufferKlinger[shift + 1] && BufferKlinger[shift] > BufferKlinger[shift + 2] && 
      BufferKlinger[shift] > BufferKlinger[shift - 1])
      return true;
   else
      return false;
}

//+------------------------------------------------------------------+
//| Check if indicator is at trough                                 |
//+------------------------------------------------------------------+
bool IsIndicatorTrough(int shift)
{
   if(shift <= 0 || shift >= ArraySize(BufferKlinger) - 2)
      return false;
      
   if(BufferKlinger[shift] <= BufferKlinger[shift + 1] && BufferKlinger[shift] < BufferKlinger[shift + 2] && 
      BufferKlinger[shift] < BufferKlinger[shift - 1])
      return true;
   else
      return false;
}

//+------------------------------------------------------------------+
//| Get Last Peak                                                   |
//+------------------------------------------------------------------+
int GetIndicatorLastPeak(int shift, int maxind)
{
   for(int i = shift + 5; i < maxind - 2; i++)
   {
      if(BufferKlinger[i] >= BufferKlinger[i + 1] && BufferKlinger[i] >= BufferKlinger[i + 2] &&
         BufferKlinger[i] >= BufferKlinger[i - 1] && BufferKlinger[i] >= BufferKlinger[i - 2])
      {
         for(int j = i; j < maxind - 2; j++)
         {
            if(BufferKlinger[j] >= BufferKlinger[j + 1] && BufferKlinger[j] > BufferKlinger[j + 2] &&
               BufferKlinger[j] >= BufferKlinger[j - 1] && BufferKlinger[j] > BufferKlinger[j - 2])
               return j;
         }
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Get Last Trough                                                 |
//+------------------------------------------------------------------+
int GetIndicatorLastTrough(int shift, int maxind)
{
   for(int i = shift + 5; i < maxind - 2; i++)
   {
      if(BufferKlinger[i] <= BufferKlinger[i + 1] && BufferKlinger[i] <= BufferKlinger[i + 2] &&
         BufferKlinger[i] <= BufferKlinger[i - 1] && BufferKlinger[i] <= BufferKlinger[i - 2])
      {
         for(int j = i; j < maxind - 2; j++)
         {
            if(BufferKlinger[j] <= BufferKlinger[j + 1] && BufferKlinger[j] < BufferKlinger[j + 2] &&
               BufferKlinger[j] <= BufferKlinger[j - 1] && BufferKlinger[j] < BufferKlinger[j - 2])
               return j;
         }
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Display Alert                                                   |
//+------------------------------------------------------------------+
void DisplayAlert(string message, int shift)
{
   if(shift <= 2 && iTime(NULL, PERIOD_CURRENT, shift) != lastAlertTime)
   {
      lastAlertTime = iTime(NULL, PERIOD_CURRENT, shift);
      Alert(message, Symbol(), " , ", PeriodSeconds() / 60, " minutes chart");
   }
}

//+------------------------------------------------------------------+
//| Draw Price Trend Line                                           |
//+------------------------------------------------------------------+
void DrawPriceTrendLine(datetime x1, datetime x2, double y1, double y2, color lineColor, int style)
{
   if(!DrawPriceLines) return;
   
   string label = "DivergenceLine2.1# " + (string)x1;
   ObjectDelete(0, label);
   ObjectCreate(0, label, OBJ_TREND, 0, x1, y1, x2, y2);
   ObjectSetInteger(0, label, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, label, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, label, OBJPROP_STYLE, style);
}

//+------------------------------------------------------------------+
//| Draw Indicator Trend Line                                       |
//+------------------------------------------------------------------+
void DrawIndicatorTrendLine(datetime x1, datetime x2, double y1, double y2, color lineColor, int style, bool bullishDivergence)
{
   int indicatorWindow = ChartWindowFind(0, indicatorName);
   if(indicatorWindow < 0) 
      indicatorWindow = ChartWindowFind(0, "KlingerDivergence");
   if(indicatorWindow < 0) return;
   
   string label = "Klinger_DivergenceLine - " + (string)x1;
   string labelArrow = "KlingerD" + (string)x1 + "-" + (string)y1;
   
   ObjectDelete(0, label);
   ObjectDelete(0, labelArrow);
   
   ObjectCreate(0, label, OBJ_TREND, indicatorWindow, x1, y1, x2, y2);
   ObjectSetInteger(0, label, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, label, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, label, OBJPROP_STYLE, style);
   
   if(DrawArrows)
   {
      if(bullishDivergence)
      {
         ObjectCreate(0, labelArrow, OBJ_ARROW, indicatorWindow, x1, y1 - 1);
         ObjectSetInteger(0, labelArrow, OBJPROP_COLOR, lineColor);
      }
      else
      {
         ObjectCreate(0, labelArrow, OBJ_ARROW, indicatorWindow, x1, y1 + 11);
         ObjectSetInteger(0, labelArrow, OBJPROP_COLOR, lineColor);
      }
   }
}