//+------------------------------------------------------------------+
//|                                                ZidelkaProEA.mq5   |
//|            Zidelka Pro — mustaqil avtomatik savdo roboti (EA)     |
//|                                                                  |
//|  Supertrend + EMA + RSI + MTF konfluensiyasi bo'yicha savdo.     |
//|  MUHIM: EA signalni O'ZI hisoblaydi (iCustom/indikator KERAK     |
//|  EMAS). Shu sababli 4002 kabi xatolar bo'lmaydi va quyidagi      |
//|  barcha sozlamalar HAQIQATAN ishlaydi — signal chastotasini       |
//|  o'zingiz boshqarasiz.                                            |
//+------------------------------------------------------------------+
#property copyright "Zidelka"
#property link      "https://github.com/Doniyorbek121/Zidelka"
#property version   "2.00"
#property description "Mustaqil (iCustomsiz) Supertrend+EMA+RSI+MTF savdo roboti."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Kirish parametrlari — SIGNAL (endi HAQIQATAN ishlaydi)           |
//+------------------------------------------------------------------+
input group "=== Signal (Supertrend + filtrlar) ==="
input int             InpATRPeriod    = 10;        // ATR davri
input double          InpATRMult      = 3.0;       // ATR koeff. (kichik = KO'P signal)
input bool            InpUseEMA       = true;      // EMA trend filtri
input int             InpEMAPeriod    = 200;       // EMA davri
input bool            InpUseRSI       = true;      // RSI impuls filtri
input int             InpRSIPeriod    = 14;        // RSI davri
input double          InpRSIBuy       = 50.0;      // RSI BUY minimal darajasi
input double          InpRSISell      = 50.0;      // RSI SELL maksimal darajasi
input bool            InpUseMTF       = true;      // MTF (yuqori TF) filtri
input ENUM_TIMEFRAMES InpHigherTF     = PERIOD_H4; // Yuqori taymfreym

input group "=== Savdo boshqaruvi ==="
input long            InpMagic        = 20260720;  // Magic number
input string          InpComment      = "ZidelkaPro"; // Buyurtma izohi
input int             InpDeviation    = 20;        // Maksimal slippage (points)
input int             InpMaxSpread    = 30;        // Maksimal spread (points, 0=cheksiz)
input bool            InpReverse      = true;      // Qarama-qarshi signalda teskarilash
input int             InpMaxPositions = 1;         // Bir vaqtda maks. pozitsiyalar

input group "=== Risk / Lot ==="
enum ENUM_LOT_MODE { LOT_FIXED, LOT_RISK_PERCENT };
input ENUM_LOT_MODE   InpLotMode      = LOT_FIXED; // Lot rejimi
input double          InpFixedLot     = 0.01;      // Fiksatsiyalangan lot
input double          InpRiskPercent  = 1.0;       // Balansdan risk (%)

input group "=== Stop Loss / Take Profit ==="
enum ENUM_SL_MODE { SL_ATR, SL_SUPERTREND, SL_FIXED };
input ENUM_SL_MODE    InpSLMode       = SL_ATR;    // SL rejimi
input double          InpSLatrMult    = 1.5;       // SL = ATR × koeffitsient
input int             InpSLfixed      = 300;       // SL (points, FIXED rejimida)
input double          InpTPratio      = 2.0;       // TP = SL × R:R (0 = TPsiz)

input group "=== Trailing Stop ==="
input bool            InpUseTrailing  = true;      // Supertrend bo'ylab trailing
input int             InpTrailStartPts= 100;       // Trailing boshlanadigan foyda (points)
input int             InpTrailBufferPts= 20;       // Supertrend'dan qo'shimcha bufer (points)

input group "=== Vaqt filtri ==="
input bool            InpUseHours     = false;     // Savdo soatlari filtri
input int             InpStartHour    = 8;         // Boshlanish soati (server vaqti)
input int             InpEndHour      = 22;        // Tugash soati (server vaqti)

//+------------------------------------------------------------------+
//| Global ob'ektlar                                                 |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  pos;

int      g_atrHandle    = INVALID_HANDLE;
int      g_emaHandle    = INVALID_HANDLE;
int      g_rsiHandle    = INVALID_HANDLE;
int      g_atrMtfHandle = INVALID_HANDLE;

datetime g_lastBar   = 0;
double   g_point     = 0.0;
double   g_stValue   = 0.0;   // oxirgi yopilgan bar Supertrend qiymati (SL/trailing)
int      g_dirNow    = 0;     // joriy yo'nalish

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE){ Print("ATR handle xato"); return(INIT_FAILED); }

   if(InpUseEMA)
     {
      g_emaHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_emaHandle == INVALID_HANDLE){ Print("EMA handle xato"); return(INIT_FAILED); }
     }
   if(InpUseRSI)
     {
      g_rsiHandle = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
      if(g_rsiHandle == INVALID_HANDLE){ Print("RSI handle xato"); return(INIT_FAILED); }
     }
   if(InpUseMTF)
     {
      g_atrMtfHandle = iATR(_Symbol, InpHigherTF, InpATRPeriod);
      if(g_atrMtfHandle == INVALID_HANDLE){ Print("MTF ATR handle xato"); return(INIT_FAILED); }
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetMarginMode();

   g_point = _Point;
   Print("ZidelkaProEA v2.00 ishga tushdi (mustaqil signal, iCustomsiz).");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_atrHandle    != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaHandle    != INVALID_HANDLE) IndicatorRelease(g_emaHandle);
   if(g_rsiHandle    != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_atrMtfHandle != INVALID_HANDLE) IndicatorRelease(g_atrMtfHandle);
  }

//+------------------------------------------------------------------+
//| Yuqori TF Supertrend yo'nalishi: +1 up, -1 down, 0 noma'lum      |
//+------------------------------------------------------------------+
int HigherTFDirection()
  {
   double atr[];
   if(CopyBuffer(g_atrMtfHandle, 0, 0, 3, atr) < 3) return(0);
   ArraySetAsSeries(atr, false);

   MqlRates r[];
   if(CopyRates(_Symbol, InpHigherTF, 0, 3, r) < 3) return(0);
   ArraySetAsSeries(r, false);

   double hl2   = (r[1].high + r[1].low) / 2.0;
   double upper = hl2 + InpATRMult * atr[1];
   double lower = hl2 - InpATRMult * atr[1];
   if(r[1].close > upper) return(+1);
   if(r[1].close < lower) return(-1);
   return(r[1].close >= hl2 ? +1 : -1);
  }

//+------------------------------------------------------------------+
//| Signalni ICHKI hisoblash (indikatorsiz).                         |
//| Qaytaradi: +1 BUY flip, -1 SELL flip, 0 signal yo'q.             |
//| Yon ta'sir: g_stValue va g_dirNow yangilanadi.                   |
//+------------------------------------------------------------------+
int ComputeSignal()
  {
   int need = MathMax(InpEMAPeriod + 60, 350);

   double atr[], hi[], lo[], cl[], ema[], rsi[];
   if(CopyBuffer(g_atrHandle, 0, 0, need, atr) != need) return(0);
   if(CopyHigh (_Symbol, _Period, 0, need, hi) != need) return(0);
   if(CopyLow  (_Symbol, _Period, 0, need, lo) != need) return(0);
   if(CopyClose(_Symbol, _Period, 0, need, cl) != need) return(0);
   ArraySetAsSeries(atr, false); ArraySetAsSeries(hi, false);
   ArraySetAsSeries(lo,  false); ArraySetAsSeries(cl, false);

   if(InpUseEMA){ if(CopyBuffer(g_emaHandle, 0, 0, need, ema) != need) return(0); ArraySetAsSeries(ema, false); }
   if(InpUseRSI){ if(CopyBuffer(g_rsiHandle, 0, 0, need, rsi) != need) return(0); ArraySetAsSeries(rsi, false); }

   //--- Supertrend'ni oldinga (chapdan o'ngga) rekursiv hisoblaymiz
   double stArr[]; ArrayResize(stArr, need);
   int    dirArr[]; ArrayResize(dirArr, need);
   stArr[0]  = lo[0];
   dirArr[0] = +1;
   for(int i = 1; i < need; i++)
     {
      double hl2   = (hi[i] + lo[i]) / 2.0;
      double up    = hl2 + InpATRMult * atr[i];
      double dn    = hl2 - InpATRMult * atr[i];
      double prevSt = stArr[i-1];
      int    prevD  = dirArr[i-1];
      if(prevD > 0) dn = MathMax(dn, prevSt);
      else          up = MathMin(up, prevSt);

      int d = prevD; double s;
      if(prevD > 0){ if(cl[i] < dn){ d = -1; s = up; } else { d = +1; s = dn; } }
      else         { if(cl[i] > up){ d = +1; s = dn; } else { d = -1; s = up; } }
      stArr[i]  = s;
      dirArr[i] = d;
     }

   //--- need-1 = shakllanayotgan bar; need-2 = oxirgi YOPILGAN bar
   int lastClosed = need - 2;
   int prevClosed = need - 3;
   g_stValue = stArr[lastClosed];
   g_dirNow  = dirArr[lastClosed];

   int dLast = dirArr[lastClosed];
   int dPrev = dirArr[prevClosed];
   bool flipUp   = (dLast > 0 && dPrev <= 0);
   bool flipDown = (dLast < 0 && dPrev >= 0);
   if(!flipUp && !flipDown) return(0);

   int dir = flipUp ? +1 : -1;
   double price = cl[lastClosed];

   //--- filtrlar
   if(InpUseEMA)
     {
      if(dir > 0 && price < ema[lastClosed]) return(0);
      if(dir < 0 && price > ema[lastClosed]) return(0);
     }
   if(InpUseRSI)
     {
      if(dir > 0 && rsi[lastClosed] < InpRSIBuy)  return(0);
      if(dir < 0 && rsi[lastClosed] > InpRSISell) return(0);
     }
   if(InpUseMTF)
     {
      int m = HigherTFDirection();
      if(m != 0)
        {
         if(dir > 0 && m < 0) return(0);
         if(dir < 0 && m > 0) return(0);
        }
     }
   return(dir);
  }

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(InpUseTrailing)
      ManageTrailing();

   //--- signal faqat yangi bar ochilganda (bar yopilgach)
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBar == g_lastBar)
      return;
   g_lastBar = curBar;

   int sig = ComputeSignal();   // +1 buy, -1 sell, 0 yo'q
   if(sig == 0)
      return;

   if(!TradingHoursOK())
      return;

   if(InpMaxSpread > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpread)
        {
         Print("Signal o'tkazib yuborildi: spread (", spread, ") juda yuqori.");
         return;
        }
     }

   ProcessSignal(sig > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
  }

//+------------------------------------------------------------------+
//| Signalni qayta ishlash                                           |
//+------------------------------------------------------------------+
void ProcessSignal(ENUM_ORDER_TYPE type)
  {
   int same = 0, opposite = 0;
   CountPositions(type, same, opposite);

   if(opposite > 0)
     {
      if(InpReverse) CloseAllPositions();
      else           return;
     }
   if(same >= InpMaxPositions)
      return;

   OpenTrade(type);
  }

//+------------------------------------------------------------------+
//| Savdoni ochish                                                   |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type)
  {
   double price = (type == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDist = StopLossDistance(type, price);
   if(slDist <= 0){ Print("Xato: SL masofasi noto'g'ri."); return; }

   double sl, tp;
   if(type == ORDER_TYPE_BUY)
     {
      sl = price - slDist;
      tp = (InpTPratio > 0) ? price + slDist * InpTPratio : 0.0;
     }
   else
     {
      sl = price + slDist;
      tp = (InpTPratio > 0) ? price - slDist * InpTPratio : 0.0;
     }

   sl = EnforceStops(type, price, sl, true);
   if(tp != 0.0) tp = EnforceStops(type, price, tp, false);

   double lot = CalcLot(slDist);
   if(lot <= 0){ Print("Xato: lot 0. Risk/balansni tekshiring."); return; }

   bool ok = (type == ORDER_TYPE_BUY)
             ? trade.Buy(lot, _Symbol, 0.0, sl, tp, InpComment)
             : trade.Sell(lot, _Symbol, 0.0, sl, tp, InpComment);

   if(!ok)
      Print("Savdo ochilmadi. Retcode: ", trade.ResultRetcode(),
            " (", trade.ResultRetcodeDescription(), ")");
   else
      Print((type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " ochildi | lot=", DoubleToString(lot, 2),
            " SL=", DoubleToString(sl, _Digits),
            " TP=", DoubleToString(tp, _Digits));
  }

//+------------------------------------------------------------------+
//| SL masofasi (narx birligida)                                     |
//+------------------------------------------------------------------+
double StopLossDistance(ENUM_ORDER_TYPE type, double price)
  {
   switch(InpSLMode)
     {
      case SL_FIXED:
         return(InpSLfixed * g_point);

      case SL_ATR:
        {
         double atr[];
         if(CopyBuffer(g_atrHandle, 0, 1, 1, atr) != 1)
            return(InpSLfixed * g_point);
         return(atr[0] * InpSLatrMult);
        }

      case SL_SUPERTREND:
        {
         if(g_stValue <= 0.0)
            return(InpSLfixed * g_point);
         return(MathAbs(price - g_stValue) + InpTrailBufferPts * g_point);
        }
     }
   return(InpSLfixed * g_point);
  }

//+------------------------------------------------------------------+
//| Lot hisoblash                                                    |
//+------------------------------------------------------------------+
double CalcLot(double slDist)
  {
   if(InpLotMode == LOT_FIXED)
      return(NormalizeLot(InpFixedLot));

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickValue <= 0)
      return(NormalizeLot(InpFixedLot));

   double lossPerLot = (slDist / tickSize) * tickValue;
   if(lossPerLot <= 0)
      return(NormalizeLot(InpFixedLot));

   return(NormalizeLot(riskMoney / lossPerLot));
  }

//+------------------------------------------------------------------+
//| Lotni broker qadamiga moslash                                    |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return(NormalizeDouble(lot, 2));
  }

//+------------------------------------------------------------------+
//| Broker minimal stop masofasini ta'minlash                        |
//+------------------------------------------------------------------+
double EnforceStops(ENUM_ORDER_TYPE type, double price, double level, bool isSL)
  {
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  = stopsLevel * g_point;
   if(minDist <= 0)
      return(NormalizeDouble(level, _Digits));

   bool buy = (type == ORDER_TYPE_BUY);
   if(isSL)
     {
      if(buy  && (price - level) < minDist) level = price - minDist;
      if(!buy && (level - price) < minDist) level = price + minDist;
     }
   else
     {
      if(buy  && (level - price) < minDist) level = price + minDist;
      if(!buy && (price - level) < minDist) level = price - minDist;
     }
   return(NormalizeDouble(level, _Digits));
  }

//+------------------------------------------------------------------+
//| Supertrend bo'ylab trailing stop                                 |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   if(g_stValue <= 0.0) return;
   double buffer = InpTrailBufferPts * g_point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != InpMagic) continue;

      double openPrice = pos.PriceOpen();
      double curSL     = pos.StopLoss();

      if(pos.PositionType() == POSITION_TYPE_BUY)
        {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - openPrice < InpTrailStartPts * g_point) continue;
         double newSL = g_stValue - buffer;
         if(newSL > curSL && newSL < bid)
           {
            newSL = EnforceStops(ORDER_TYPE_BUY, bid, newSL, true);
            if(newSL > curSL)
               trade.PositionModify(pos.Ticket(), newSL, pos.TakeProfit());
           }
        }
      else if(pos.PositionType() == POSITION_TYPE_SELL)
        {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(openPrice - ask < InpTrailStartPts * g_point) continue;
         double newSL = g_stValue + buffer;
         if((curSL == 0.0 || newSL < curSL) && newSL > ask)
           {
            newSL = EnforceStops(ORDER_TYPE_SELL, ask, newSL, true);
            if(curSL == 0.0 || newSL < curSL)
               trade.PositionModify(pos.Ticket(), newSL, pos.TakeProfit());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Pozitsiyalarni sanash (magic + symbol)                           |
//+------------------------------------------------------------------+
void CountPositions(ENUM_ORDER_TYPE signalType, int &same, int &opposite)
  {
   same = 0; opposite = 0;
   ENUM_POSITION_TYPE sigPos = (signalType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != InpMagic) continue;
      if(pos.PositionType() == sigPos) same++;
      else                             opposite++;
     }
  }

//+------------------------------------------------------------------+
//| Symbol/magic bo'yicha barcha pozitsiyalarni yopish               |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != InpMagic) continue;
      trade.PositionClose(pos.Ticket());
     }
  }

//+------------------------------------------------------------------+
//| Savdo soatlari filtri                                            |
//+------------------------------------------------------------------+
bool TradingHoursOK()
  {
   if(!InpUseHours) return(true);
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int h = t.hour;
   if(InpStartHour <= InpEndHour)
      return(h >= InpStartHour && h < InpEndHour);
   return(h >= InpStartHour || h < InpEndHour);
  }
//+------------------------------------------------------------------+
