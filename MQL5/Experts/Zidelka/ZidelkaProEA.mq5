//+------------------------------------------------------------------+
//|                                                ZidelkaProEA.mq5   |
//|            Zidelka Pro Signal indikatoriga asoslangan Expert      |
//|                                                                  |
//|  Supertrend + EMA + RSI + MTF konfluensiyasi bo'yicha savdo:     |
//|  risk asosida lot, ATR/Supertrend SL/TP, Supertrend trailing.    |
//+------------------------------------------------------------------+
#property copyright "Zidelka"
#property link      "https://github.com/Doniyorbek121/Zidelka"
#property version   "1.00"
#property description "Zidelka Pro Signal asosidagi avtomatik savdo roboti (EA)."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Kirish parametrlari — INDIKATOR (iCustom bilan mos bo'lishi shart)|
//| Bu qiymatlar indikator buferlarini shakllantiradi, shuning uchun |
//| grafikdagi indikator sozlamalari bilan bir xil bo'lishi kerak.   |
//+------------------------------------------------------------------+
input group "=== Indikator sozlamalari ==="
input int             InpATRPeriod    = 10;        // ATR davri
input double          InpATRMult      = 3.0;       // ATR koeffitsienti
input bool            InpUseEMA       = true;      // EMA filtri
input int             InpEMAPeriod    = 200;       // EMA davri
input bool            InpUseRSI       = true;      // RSI filtri
input int             InpRSIPeriod    = 14;        // RSI davri
input double          InpRSIBuy       = 50.0;      // RSI BUY darajasi
input double          InpRSISell      = 50.0;      // RSI SELL darajasi
input bool            InpUseMTF       = true;      // MTF filtri
input ENUM_TIMEFRAMES InpHigherTF     = PERIOD_H4; // Yuqori taymfreym
input int             InpArrowGap     = 15;        // O'q masofasi (pips)

input group "=== Likvidlik zonalari (indikator bilan mos) ==="
input bool            InpUseFVG       = true;      // Imbalance (FVG) zonalari
input bool            InpUsePools     = true;      // Stop-pool (swing) zonalari
input int             InpZonePivotL   = 8;         // Pivot chap
input int             InpZonePivotR   = 3;         // Pivot o'ng
input double          InpZoneMinATR   = 0.10;      // Min zona balandligi (ATR)
input double          InpZonePoolATR  = 0.30;      // Stop-pool balandligi (ATR)
input int             InpZoneLookback = 500;       // Zona qidirish oralig'i (bar)
input int             InpMaxZones     = 24;        // Maksimal faol zonalar
input bool            InpUseLiqFilter = false;     // Signalni zonalar bilan filtrlash
input double          InpZoneProxATR  = 2.0;       // Zona yaqinligi (ATR)

input group "=== Savdo boshqaruvi ==="
input long            InpMagic        = 20260720;  // Magic number
input string          InpComment      = "ZidelkaPro"; // Buyurtma izohi
input int             InpDeviation    = 20;        // Maksimal slippage (points)
input int             InpMaxSpread    = 30;        // Maksimal spread (points, 0=cheksiz)
input bool            InpReverse      = true;      // Qarama-qarshi signalda pozitsiyani teskarilash
input int             InpMaxPositions = 1;         // Bir vaqtda maks. pozitsiyalar (magic bo'yicha)

input group "=== Risk / Lot ==="
enum ENUM_LOT_MODE { LOT_FIXED, LOT_RISK_PERCENT };
input ENUM_LOT_MODE   InpLotMode      = LOT_RISK_PERCENT; // Lot rejimi
input double          InpFixedLot     = 0.10;      // Fiksatsiyalangan lot
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

int      g_handle    = INVALID_HANDLE;
int      g_atrHandle = INVALID_HANDLE;
datetime g_lastBar   = 0;
double   g_point     = 0.0;

//--- indikator bufer indekslari
#define BUF_BUY   2
#define BUF_SELL  3
#define BUF_ST    4
#define BUF_DIR   5

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Indikator handle'i. MUHIM: iCustom PARAMETRSIZ chaqiriladi.
   //--- Ba'zi MT5 build'larda iCustom uzatilgan parametrlar sonini indikator
   //--- inputlari soniga AYNAN mos kelishini talab qiladi; mos kelmasa 4002
   //--- ("cannot load custom indicator") xatosi chiqadi. Parametrsiz chaqiruv
   //--- indikatorni STANDART sozlamalari bilan yuklaydi (aynan kerakli sozlama)
   //--- va hech qanday moslik talab qilinmaydi. EA baribir 2/3/4/5 buferlarni
   //--- (BUY/SELL/Supertrend/Dir) o'qiydi — ular sozlamaga bog'liq emas.
   g_handle = iCustom(_Symbol, _Period, "Zidelka\\ZidelkaProSignal");

   if(g_handle == INVALID_HANDLE)
     {
      Print("Xato: ZidelkaProSignal indikatorini yuklab bo'lmadi. ",
            "MQL5/Indicators/Zidelka/ papkasida ekanligini tekshiring.");
      return(INIT_FAILED);
     }

   //--- SL uchun doimiy ATR handle'i (SL_ATR rejimida ishlatiladi)
   g_atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
     {
      Print("Xato: ATR handle yaratilmadi.");
      return(INIT_FAILED);
     }

   //--- CTrade sozlamalari
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetMarginMode();

   g_point = _Point;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_handle    != INVALID_HANDLE) IndicatorRelease(g_handle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
  }

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- trailing har tikda ishlaydi (agar yoqilgan bo'lsa)
   if(InpUseTrailing)
      ManageTrailing();

   //--- signal faqat yangi bar ochilganda tekshiriladi (bar yopilgach)
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBar == g_lastBar)
      return;
   g_lastBar = curBar;

   //--- oxirgi YOPILGAN bardagi signalni o'qiymiz (shift = 1)
   double buy[], sell[];
   if(CopyBuffer(g_handle, BUF_BUY,  1, 1, buy)  != 1) return;
   if(CopyBuffer(g_handle, BUF_SELL, 1, 1, sell) != 1) return;

   bool buySignal  = (buy[0]  > 0.0 && buy[0]  != EMPTY_VALUE);
   bool sellSignal = (sell[0] > 0.0 && sell[0] != EMPTY_VALUE);

   if(!buySignal && !sellSignal)
      return;

   //--- vaqt filtri
   if(!TradingHoursOK())
      return;

   //--- spread filtri
   if(InpMaxSpread > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpread)
        {
         Print("Signal o'tkazib yuborildi: spread (", spread, ") juda yuqori.");
         return;
        }
     }

   if(buySignal)  ProcessSignal(ORDER_TYPE_BUY);
   if(sellSignal) ProcessSignal(ORDER_TYPE_SELL);
  }

//+------------------------------------------------------------------+
//| Signalni qayta ishlash                                           |
//+------------------------------------------------------------------+
void ProcessSignal(ENUM_ORDER_TYPE type)
  {
   //--- mavjud pozitsiyalarni tekshirish
   int    same = 0, opposite = 0;
   CountPositions(type, same, opposite);

   //--- qarama-qarshi pozitsiyani yopish (teskarilash)
   if(opposite > 0)
     {
      if(InpReverse)
         CloseAllPositions();
      else
         return; // teskari signal, lekin teskarilash o'chirilgan
     }

   //--- allaqachon ochiq bir xil yo'nalishdagi pozitsiya soni cheklovi
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

   double slDist = StopLossDistance(type, price);   // narx birligida
   if(slDist <= 0)
     {
      Print("Xato: SL masofasi noto'g'ri hisoblandi.");
      return;
     }

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

   //--- broker minimal masofasini hurmat qilish
   sl = EnforceStops(type, price, sl, true);
   if(tp != 0.0)
      tp = EnforceStops(type, price, tp, false);

   double lot = CalcLot(slDist);
   if(lot <= 0)
     {
      Print("Xato: lot hajmi 0. Riskni yoki balansni tekshiring.");
      return;
     }

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
//| SL masofasini narx birligida hisoblash                           |
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
         double st[];
         if(CopyBuffer(g_handle, BUF_ST, 1, 1, st) != 1 || st[0] <= 0.0)
            return(InpSLfixed * g_point);
         double dist = MathAbs(price - st[0]) + InpTrailBufferPts * g_point;
         return(dist);
        }
     }
   return(InpSLfixed * g_point);
  }

//+------------------------------------------------------------------+
//| Lot hajmini hisoblash                                            |
//+------------------------------------------------------------------+
double CalcLot(double slDist)
  {
   if(InpLotMode == LOT_FIXED)
      return(NormalizeLot(InpFixedLot));

   //--- risk asosida
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickValue <= 0)
      return(NormalizeLot(InpFixedLot));

   //--- 1 lot uchun SL masofasidagi zarar
   double lossPerLot = (slDist / tickSize) * tickValue;
   if(lossPerLot <= 0)
      return(NormalizeLot(InpFixedLot));

   double lot = riskMoney / lossPerLot;
   return(NormalizeLot(lot));
  }

//+------------------------------------------------------------------+
//| Lotni broker qadamiga moslashtirish                              |
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
   //--- SL uchun: narxdan yetarlicha uzoq bo'lishi kerak
   if(isSL)
     {
      if(buy  && (price - level) < minDist) level = price - minDist;
      if(!buy && (level - price) < minDist) level = price + minDist;
     }
   else //--- TP
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
   double st[];
   if(CopyBuffer(g_handle, BUF_ST, 1, 1, st) != 1 || st[0] <= 0.0)
      return;

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
         //--- yetarli foyda bormi?
         if(bid - openPrice < InpTrailStartPts * g_point) continue;
         double newSL = st[0] - buffer;
         //--- faqat yuqoriga siljitamiz va narxdan pastda bo'lishi kerak
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
         double newSL = st[0] + buffer;
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
//| Pozitsiyalarni sanash (magic + symbol bo'yicha)                  |
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
//| Ushbu symbol/magic bo'yicha barcha pozitsiyalarni yopish         |
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
   //--- kechasi orqali o'tuvchi oraliq (masalan 22 -> 6)
   return(h >= InpStartHour || h < InpEndHour);
  }
//+------------------------------------------------------------------+
