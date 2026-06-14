//+------------------------------------------------------------------+
//|                                        StochasticsDivergence.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Valenteeno"
#property link      "val.chioke@gmail.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3
//--- plot Stochastic Line
#property indicator_label1  "Stochastic"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Buy
#property indicator_label2  "Buy"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
//--- plot Sell
#property indicator_label3  "Sell"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1 80
#property indicator_level2 20

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <ChartObjects\ChartObjectsLines.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int KPeriod = 5;                      // K Period
input int DPeriod = 3;                      // D Period  
input int Slowing = 3;                      // Slowing
input bool DrawPriceLines = false;          // Draw Price Lines
input bool DrawArrows = true;               // Draw Arrows
input bool drawDivergenceLines = true;      // Draw Divergence Lines
input bool displayAlert = false;            // Display Alert

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double StochLineBuffer[];
double bullishDivergence[];
double bearishDivergence[];
double StochDiv[];

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
string indicatorName;
datetime lastAlertTime;
int stochHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers mapping
   SetIndexBuffer(0, StochLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, bullishDivergence, INDICATOR_DATA);
   SetIndexBuffer(2, bearishDivergence, INDICATOR_DATA);
   SetIndexBuffer(3, StochDiv, INDICATOR_CALCULATIONS);
   
   // Set arrow codes
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetInteger(2, PLOT_ARROW, 234);
   
   // Set empty values
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
   
   // Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, Digits() + 2);
   
   // Set indicator name
   indicatorName = "Stoch(" + (string)KPeriod + "," + (string)DPeriod + "," + (string)Slowing + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, "StochDivergence(" + (string)KPeriod + "," + (string)DPeriod + "," + (string)Slowing + ")");
   
   // CRITICAL: Set arrays as timeseries (this was missing!)
   ArraySetAsSeries(StochLineBuffer, true);
   ArraySetAsSeries(bullishDivergence, true);
   ArraySetAsSeries(bearishDivergence, true);
   ArraySetAsSeries(StochDiv, true);
   
   // Create Stochastic handle
   stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, KPeriod, DPeriod, Slowing, MODE_SMA, STO_LOWHIGH);
   if(stochHandle == INVALID_HANDLE)
   {
      Print("Failed to create Stochastic handle");
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
      if(StringFind(label, "DivergenceLine") >= 0)
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
   if(rates_total < MathMax(KPeriod, DPeriod) + Slowing)
      return 0;
   
   // Set input arrays as timeseries (only on first call for efficiency)
   static bool arraysInitialized = false;
   if(!arraysInitialized)
   {
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      arraysInitialized = true;
   }
   
   // EXACT Klinger pattern: Calculate limit
   int limit = rates_total - prev_calculated;
   if(limit > 1)
   {
      limit = rates_total - 2;
      ArrayInitialize(bullishDivergence, 0);
      ArrayInitialize(bearishDivergence, 0);
   }
   
   // Get Stochastic data efficiently - only what we need
   int dataCount = (limit > 1) ? rates_total : MathMin(50, rates_total); // Limit data for incremental updates
   if(CopyBuffer(stochHandle, 0, 0, dataCount, StochDiv) <= 0) // Direct copy to StochDiv, skip intermediate buffer
      return 0;
   
   // For efficiency, also copy to StochLineBuffer for display
   if(limit > 1) // Only on full recalculation
   {
      for(int i = 0; i < dataCount; i++)
         StochLineBuffer[i] = StochDiv[i];
   }
   
   // Calculate divergences (optimized - no double detection)
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
         int recentBar = 2;
         if(recentBar < rates_total - 5)
         {
            CatchBullishDivergence(recentBar, rates_total);
            CatchBearishDivergence(recentBar, rates_total);
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Indicator (exact Klinger pattern)                    |
//+------------------------------------------------------------------+
void CalculateIndicator(int limit, int rates_total, const datetime &time[], const double &high[], const double &low[])
{
   for(int i = limit; i >= 0; i--)
   {
      if(i >= 2)
      {
         CatchBullishDivergence(i + 2, rates_total);
         CatchBearishDivergence(i + 2, rates_total);
      }
   }
}


//+------------------------------------------------------------------+
//| Catch Bullish Divergence (MQL4 style)                         |
//+------------------------------------------------------------------+
void CatchBullishDivergence(int shift, int maxind)
{
   if(!IsIndicatorTrough(shift))
      return;
      
   int currentTrough = shift;
   int lastTrough = GetIndicatorLastTrough(shift, maxind);

   if(currentTrough == -1 || lastTrough == -1) 
      return;
   
   // Classical bullish divergence: Indicator makes higher low, price makes lower low
   // Classical bullish divergence: Indicator makes higher low, price makes lower low
   if(StochDiv[currentTrough] > StochDiv[lastTrough] && iLow(_Symbol, PERIOD_CURRENT, currentTrough) < iLow(_Symbol, PERIOD_CURRENT, lastTrough))
   {
      bullishDivergence[currentTrough] = StochDiv[currentTrough];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentTrough), iTime(_Symbol, PERIOD_CURRENT, lastTrough), 
                           iLow(_Symbol, PERIOD_CURRENT, currentTrough), iLow(_Symbol, PERIOD_CURRENT, lastTrough), clrGreen, STYLE_SOLID);
         DrawIndicatorTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentTrough), iTime(_Symbol, PERIOD_CURRENT, lastTrough), 
                               StochDiv[currentTrough], StochDiv[lastTrough], clrGreen, STYLE_SOLID, true);
      }
      if(displayAlert)
         DisplayAlert("Classical bullish divergence on: ", currentTrough);
   }
   // Reverse bullish divergence: Indicator makes lower low, price makes higher low  
   else if(StochDiv[currentTrough] < StochDiv[lastTrough] && iLow(_Symbol, PERIOD_CURRENT, currentTrough) > iLow(_Symbol, PERIOD_CURRENT, lastTrough))
   {
      bullishDivergence[currentTrough] = StochDiv[currentTrough];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentTrough), iTime(_Symbol, PERIOD_CURRENT, lastTrough), 
                           iLow(_Symbol, PERIOD_CURRENT, currentTrough), iLow(_Symbol, PERIOD_CURRENT, lastTrough), clrGreen, STYLE_DOT);
         DrawIndicatorTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentTrough), iTime(_Symbol, PERIOD_CURRENT, lastTrough), 
                               StochDiv[currentTrough], StochDiv[lastTrough], clrGreen, STYLE_DOT, true);
      }
      if(displayAlert)
         DisplayAlert("Reverse bullish divergence on: ", currentTrough);
   }
}

//+------------------------------------------------------------------+
//| Catch Bearish Divergence (MQL4 style)                         |
//+------------------------------------------------------------------+
void CatchBearishDivergence(int shift, int maxind)
{
   if(IsIndicatorPeak(shift) == false)
      return;
   int currentPeak = shift;
   int lastPeak = GetIndicatorLastPeak(shift, maxind);

   if(currentPeak == -1) return;
   if(lastPeak == -1) return;

   // Classical bearish divergence: Indicator makes lower high, price makes higher high
   if(StochDiv[currentPeak] < StochDiv[lastPeak] && iHigh(_Symbol, PERIOD_CURRENT, currentPeak) > iHigh(_Symbol, PERIOD_CURRENT, lastPeak))
   {
      bearishDivergence[currentPeak] = StochDiv[currentPeak];
      if(drawDivergenceLines == true)
      {
         DrawPriceTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentPeak), iTime(_Symbol, PERIOD_CURRENT, lastPeak), 
                           iHigh(_Symbol, PERIOD_CURRENT, currentPeak), iHigh(_Symbol, PERIOD_CURRENT, lastPeak), clrRed, STYLE_SOLID);
         DrawIndicatorTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentPeak), iTime(_Symbol, PERIOD_CURRENT, lastPeak), 
                               StochDiv[currentPeak], StochDiv[lastPeak], clrRed, STYLE_SOLID, false);
      }
      if(displayAlert == true)
         DisplayAlert("Classical bearish divergence on: ", currentPeak);
   }
   // Reverse bearish divergence: Indicator makes higher high, price makes lower high
   else if(StochDiv[currentPeak] > StochDiv[lastPeak] && iHigh(_Symbol, PERIOD_CURRENT, currentPeak) < iHigh(_Symbol, PERIOD_CURRENT, lastPeak))
   {
      bearishDivergence[currentPeak] = StochDiv[currentPeak];
      if(drawDivergenceLines == true)
      {
         DrawPriceTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentPeak), iTime(_Symbol, PERIOD_CURRENT, lastPeak), 
                           iHigh(_Symbol, PERIOD_CURRENT, currentPeak), iHigh(_Symbol, PERIOD_CURRENT, lastPeak), clrRed, STYLE_DOT);
         DrawIndicatorTrendLine(iTime(_Symbol, PERIOD_CURRENT, currentPeak), iTime(_Symbol, PERIOD_CURRENT, lastPeak), 
                               StochDiv[currentPeak], StochDiv[lastPeak], clrRed, STYLE_DOT, false);
      }
      if(displayAlert == true)
         DisplayAlert("Reverse bearish divergence on: ", currentPeak);
   }
}

//+------------------------------------------------------------------+
//| Check if indicator is at peak (MQL4 style)                    |
//+------------------------------------------------------------------+
bool IsIndicatorPeak(int shift)
{
   if(shift <= 1 || shift >= ArraySize(StochDiv) - 2)
      return false;
      
   if(StochDiv[shift] >= StochDiv[shift+1] && StochDiv[shift] > StochDiv[shift+2] && 
      StochDiv[shift] > StochDiv[shift-1])
      return(true);
   else
      return(false);
}

//+------------------------------------------------------------------+
//| Check if indicator is at trough (MQL4 style)                  |
//+------------------------------------------------------------------+
bool IsIndicatorTrough(int shift)
{
   if(shift <= 1 || shift >= ArraySize(StochDiv) - 2)
      return false;
      
   if(StochDiv[shift] <= StochDiv[shift+1] && StochDiv[shift] < StochDiv[shift+2] && 
      StochDiv[shift] < StochDiv[shift-1])
      return(true);
   else
      return(false);
}

//+------------------------------------------------------------------+
//| Get Last Peak (MQL4 style)                                    |
//+------------------------------------------------------------------+
int GetIndicatorLastPeak(int shift, int maxind)
{
   // Optimized: Search directly for peaks in StochDiv, limit search range
   int searchLimit = MathMin(shift + 50, maxind - 2); // Limit search to 50 bars
   for(int i = shift + 5; i < searchLimit; i++)
   {
      if(IsIndicatorPeak(i))
         return i;
   }
   return(-1);
}

//+------------------------------------------------------------------+
//| Get Last Trough (MQL4 style)                                  |
//+------------------------------------------------------------------+
int GetIndicatorLastTrough(int shift, int maxind)
{
   // Optimized: Search directly for troughs in StochDiv, limit search range
   int searchLimit = MathMin(shift + 50, maxind - 2); // Limit search to 50 bars
   for(int i = shift + 5; i < searchLimit; i++)
   {
      if(IsIndicatorTrough(i))
         return i;
   }
   return(-1);
}

//+------------------------------------------------------------------+
//| Display Alert (MQL4 style)                                    |
//+------------------------------------------------------------------+
void DisplayAlert(string message, int shift)
{
   if(shift <= 2 && iTime(_Symbol, PERIOD_CURRENT, shift) != lastAlertTime)
   {
      lastAlertTime = iTime(_Symbol, PERIOD_CURRENT, shift);
      Alert(message, Symbol(), " , ", PeriodSeconds() / 60, " minutes chart");
   }
}

//+------------------------------------------------------------------+
//| Draw Price Trend Line (MQL4 style)                           |
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
//| Draw Indicator Trend Line (MQL4 style)                       |
//+------------------------------------------------------------------+
void DrawIndicatorTrendLine(datetime x1, datetime x2, double y1, double y2, color lineColor, int style, bool isBullish)
{
   int indicatorWindow = ChartWindowFind(0, indicatorName);
   if(indicatorWindow < 0) 
      indicatorWindow = ChartWindowFind(0, "StochDivergence");
   if(indicatorWindow < 0) return;

   string label = "Stoch_DivergenceLine - " + (string)x1;
   string labelArrow = "StochD" + (string)x1 + "-" + (string)y1;
   
   ObjectDelete(0, label);
   ObjectDelete(0, labelArrow);
   
   ObjectCreate(0, label, OBJ_TREND, indicatorWindow, x1, y1, x2, y2);
   ObjectSetInteger(0, label, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, label, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, label, OBJPROP_STYLE, style);
   
   if(DrawArrows)
   {
      if(isBullish)
      {
         ObjectCreate(0, labelArrow, OBJ_ARROW, indicatorWindow, x1, y1 - 1);
         ObjectSetInteger(0, labelArrow, OBJPROP_COLOR, lineColor);
      }
      else
      {
         ObjectCreate(0, labelArrow, OBJ_ARROW, indicatorWindow, x1, y1 + 11);
         ObjectSetInteger(0, labelArrow, OBJPROP_COLOR, lineColor);
      }
      ChartRedraw();
   }
}