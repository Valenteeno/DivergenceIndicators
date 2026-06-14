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
input bool DrawPriceLines = true;           // Draw Price Lines (FIXED: changed default to true)
input bool DrawArrows = true;               // Draw Arrows
input bool drawDivergenceLines = true;      // Draw Divergence Lines
input bool displayAlert = false;            // Display Alert

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double StochLineBuffer[];
double BuyBuffer[];
double SellBuffer[];
double StochDiv[];

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
string indicatorName;
datetime lastAlertTime;
int stoch_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers mapping
   SetIndexBuffer(0, StochLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SellBuffer, INDICATOR_DATA);
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
   
   // Create stochastic handle
   stoch_handle = iStochastic(NULL, PERIOD_CURRENT, KPeriod, DPeriod, Slowing, MODE_SMA, STO_LOWHIGH);
   if(stoch_handle == INVALID_HANDLE)
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
      if(StringFind(label, "DivergenceLine") >= 0 || StringFind(label, "Stoch_DivergenceLine") >= 0)
         ObjectDelete(0, label);
   }
   
   // Remove arrows
   for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
   {
      string label = ObjectName(0, i, -1, OBJ_ARROW);
      if(StringFind(label, "StochD") >= 0)
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
      
   int limit = prev_calculated - 1;
   if(limit <= 0)
   {
      limit = rates_total - MathMax(KPeriod, DPeriod) - Slowing - 1;
      ArrayInitialize(StochLineBuffer, 0);
      ArrayInitialize(BuyBuffer, 0);
      ArrayInitialize(SellBuffer, 0);
      ArrayInitialize(StochDiv, 0);
   }
   
   // Copy stochastic values
   int copied = CopyBuffer(stoch_handle, 0, 0, rates_total, StochLineBuffer);
   if(copied != rates_total)
      return 0;
   
   // Calculate indicator
   CalculateIndicator(limit, rates_total, time, high, low);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Indicator                                              |
//+------------------------------------------------------------------+
void CalculateIndicator(int limit, int rates_total, const datetime &time[], const double &high[], const double &low[])
{
   for(int i = limit; i >= 0; i--)
   {
      CalculateStochDiv(i);
      if(i >= 2)
      {
         CatchBullishDivergence(i + 2, rates_total, time, low);
         CatchBearishDivergence(i + 2, rates_total, time, high);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Stochastic Divergence                                 |
//+------------------------------------------------------------------+
void CalculateStochDiv(int i)
{
   StochDiv[i] = StochLineBuffer[i];
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
   if(StochDiv[currentTrough] > StochDiv[lastTrough] && low[currentTrough] < low[lastTrough])
   {
      BuyBuffer[currentTrough] = StochDiv[currentTrough];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentTrough], time[lastTrough], low[currentTrough],
                           low[lastTrough], clrGreen, STYLE_SOLID);
         DrawIndicatorTrendLine(time[currentTrough], time[lastTrough], StochDiv[currentTrough],
                               StochDiv[lastTrough], clrGreen, STYLE_SOLID, true);
      }
      if(displayAlert)
         DisplayAlert("Classical bullish divergence on: ", currentTrough);
   }
   
   // Reverse bullish divergence
   if(StochDiv[currentTrough] < StochDiv[lastTrough] && low[currentTrough] > low[lastTrough])
   {
      BuyBuffer[currentTrough] = StochDiv[currentTrough];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentTrough], time[lastTrough], low[currentTrough],
                           low[lastTrough], clrGreen, STYLE_DOT);
         DrawIndicatorTrendLine(time[currentTrough], time[lastTrough], StochDiv[currentTrough],
                               StochDiv[lastTrough], clrGreen, STYLE_DOT, true);
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
   if(StochDiv[currentPeak] < StochDiv[lastPeak] && high[currentPeak] > high[lastPeak])
   {
      SellBuffer[currentPeak] = StochDiv[currentPeak];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentPeak], time[lastPeak], high[currentPeak],
                           high[lastPeak], clrRed, STYLE_SOLID);
         DrawIndicatorTrendLine(time[currentPeak], time[lastPeak], StochDiv[currentPeak],
                               StochDiv[lastPeak], clrRed, STYLE_SOLID, false);
      }
      if(displayAlert)
         DisplayAlert("Classical bearish divergence on: ", currentPeak);
   }
   
   // Reverse bearish divergence
   if(StochDiv[currentPeak] > StochDiv[lastPeak] && high[currentPeak] < high[lastPeak])
   {
      SellBuffer[currentPeak] = StochDiv[currentPeak];
      if(drawDivergenceLines)
      {
         DrawPriceTrendLine(time[currentPeak], time[lastPeak], high[currentPeak],
                           high[lastPeak], clrRed, STYLE_DOT);
         DrawIndicatorTrendLine(time[currentPeak], time[lastPeak], StochDiv[currentPeak],
                               StochDiv[lastPeak], clrRed, STYLE_DOT, false);
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
   if(shift <= 0 || shift >= ArraySize(StochDiv) - 2)
      return false;
      
   if(StochDiv[shift] >= StochDiv[shift + 1] && StochDiv[shift] > StochDiv[shift + 2] && 
      StochDiv[shift] > StochDiv[shift - 1])
      return true;
   else
      return false;
}

//+------------------------------------------------------------------+
//| Check if indicator is at trough                                 |
//+------------------------------------------------------------------+
bool IsIndicatorTrough(int shift)
{
   if(shift <= 0 || shift >= ArraySize(StochDiv) - 2)
      return false;
      
   if(StochDiv[shift] <= StochDiv[shift + 1] && StochDiv[shift] < StochDiv[shift + 2] && 
      StochDiv[shift] < StochDiv[shift - 1])
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
      if(StochLineBuffer[i] >= StochLineBuffer[i + 1] && StochLineBuffer[i] >= StochLineBuffer[i + 2] &&
         StochLineBuffer[i] >= StochLineBuffer[i - 1] && StochLineBuffer[i] >= StochLineBuffer[i - 2])
      {
         for(int j = i; j < maxind - 2; j++)
         {
            if(StochDiv[j] >= StochDiv[j + 1] && StochDiv[j] > StochDiv[j + 2] &&
               StochDiv[j] >= StochDiv[j - 1] && StochDiv[j] > StochDiv[j - 2])
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
      if(StochLineBuffer[i] <= StochLineBuffer[i + 1] && StochLineBuffer[i] <= StochLineBuffer[i + 2] &&
         StochLineBuffer[i] <= StochLineBuffer[i - 1] && StochLineBuffer[i] <= StochLineBuffer[i - 2])
      {
         for(int j = i; j < maxind - 2; j++)
         {
            if(StochDiv[j] <= StochDiv[j + 1] && StochDiv[j] < StochDiv[j + 2] &&
               StochDiv[j] <= StochDiv[j - 1] && StochDiv[j] < StochDiv[j - 2])
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
   // FIXED: Removed the condition that was preventing price lines from being drawn
   // The DrawPriceLines parameter now controls this at the input level
   if(!DrawPriceLines) return;
   
   string label = "DivergenceLine2.1# " + (string)x1;
   ObjectDelete(0, label);
   ObjectCreate(0, label, OBJ_TREND, 0, x1, y1, x2, y2);
   ObjectSetInteger(0, label, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, label, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, label, OBJPROP_STYLE, style);
   ObjectSetInteger(0, label, OBJPROP_WIDTH, 1); // ADDED: Set line width
}

//+------------------------------------------------------------------+
//| Draw Indicator Trend Line                                       |
//+------------------------------------------------------------------+
void DrawIndicatorTrendLine(datetime x1, datetime x2, double y1, double y2, color lineColor, int style, bool bullishDivergence)
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
   ObjectSetInteger(0, label, OBJPROP_WIDTH, 1); // ADDED: Set line width
   
   if(DrawArrows)
   {
      if(bullishDivergence)
      {
         ObjectCreate(0, labelArrow, OBJ_ARROW, indicatorWindow, x1, y1 - 1);
         ObjectSetInteger(0, labelArrow, OBJPROP_COLOR, lineColor);
         //ObjectSetInteger(0, labelArrow, OBJPROP_ARROWCODE, SYMBOL_ARROWUP); // ADDED: Set arrow type
      }
      else
      {
         ObjectCreate(0, labelArrow, OBJ_ARROW, indicatorWindow, x1, y1 + 11);
         ObjectSetInteger(0, labelArrow, OBJPROP_COLOR, lineColor);
         //ObjectSetInteger(0, labelArrow, OBJPROP_ARROWCODE, SYMBOL_ARROWDOWN); // ADDED: Set arrow type
      }
   }
}