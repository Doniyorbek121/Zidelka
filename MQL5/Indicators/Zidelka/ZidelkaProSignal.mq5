//+------------------------------------------------------------------+
//|                                           ZidelkaProSignal.mq5   |
//|                                  Professional confluence system  |
//|                                                                  |
//|  Trend (Supertrend/ATR) + Yo'nalish (EMA) + Impuls (RSI)         |
//|  + Yuqori taymfreym tasdiq (MTF) + Dashboard + Alertlar          |
//+------------------------------------------------------------------+
#property copyright   "Zidelka"
#property link        "https://github.com/Doniyorbek121/Zidelka"
#property version     "1.00"
#property description "Professional konfluensiyaga asoslangan signal indikatori."
#property description "Supertrend + EMA + RSI + MTF tasdiq. BUY/SELL o'qlari va alertlar."
#property strict

//--- Indikator sozlamalari
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

//--- Plot 1: Supertrend chizig'i (pastdan, ko'tarilish trendi)
#property indicator_label1  "Trend Up"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Supertrend chizig'i (yuqoridan, tushish trendi)
#property indicator_label2  "Trend Down"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTomato
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: BUY o'qi
#property indicator_label3  "Buy Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  2

//--- Plot 4: SELL o'qi
#property indicator_label4  "Sell Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

//+------------------------------------------------------------------+
//| Kirish parametrlari                                              |
//+------------------------------------------------------------------+
input group "=== Trend (Supertrend) ==="
input int                ATR_Period      = 10;           // ATR davri
input double             ATR_Multiplier  = 3.0;          // ATR koeffitsienti

input group "=== Yo'nalish filtri (EMA) ==="
input bool               UseEMAFilter    = true;         // EMA trend filtridan foydalanish
input int                EMA_Period      = 200;          // EMA davri

input group "=== Impuls filtri (RSI) ==="
input bool               UseRSIFilter    = true;         // RSI filtridan foydalanish
input int                RSI_Period      = 14;           // RSI davri
input double             RSI_BuyLevel    = 50.0;         // BUY uchun RSI minimal darajasi
input double             RSI_SellLevel   = 50.0;         // SELL uchun RSI maksimal darajasi

input group "=== Yuqori taymfreym tasdiq (MTF) ==="
input bool               UseMTFFilter    = true;         // MTF tasdiqdan foydalanish
input ENUM_TIMEFRAMES    HigherTF        = PERIOD_H4;    // Yuqori taymfreym

input group "=== Signal va vizual ==="
input int                ArrowGapPips    = 15;           // O'q va narx orasidagi masofa (pips)
input color              BuyArrowColor   = clrLime;      // BUY o'q rangi
input color              SellArrowColor  = clrRed;       // SELL o'q rangi
input bool               ShowDashboard   = true;         // Dashboard panelini ko'rsatish

input group "=== Alertlar ==="
input bool               AlertPopup      = true;         // Ekranda ogohlantirish
input bool               AlertPush       = false;        // Mobil push-bildirishnoma
input bool               AlertEmail      = false;        // Email ogohlantirish
input bool               AlertSound      = true;         // Ovozli signal
input string             SoundFile       = "alert.wav";  // Ovoz fayli

//+------------------------------------------------------------------+
//| Buferlar                                                         |
//+------------------------------------------------------------------+
double TrendUpBuffer[];     // Ko'tarilish Supertrend chizig'i
double TrendDownBuffer[];   // Tushish Supertrend chizig'i
double BuyArrowBuffer[];    // BUY o'qlari
double SellArrowBuffer[];   // SELL o'qlari
double SupertrendBuffer[];  // Yagona Supertrend qiymati (ichki)
double DirBuffer[];         // Yo'nalish: +1 (up), -1 (down) (ichki)

//--- Indikator handle'lari
int    hATR      = INVALID_HANDLE;
int    hEMA      = INVALID_HANDLE;
int    hRSI      = INVALID_HANDLE;
int    hATR_MTF  = INVALID_HANDLE;

//--- Ichki holat
double g_point    = 0.0;
int    g_digitsAdj = 1;
datetime g_lastAlertBar = 0;
int      g_lastAlertDir = 0;   // +1 buy, -1 sell

//--- Dashboard ob'ekt prefiksi
#define DASH_PREFIX "ZPS_dash_"

//+------------------------------------------------------------------+
//| Initsializatsiya                                                 |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- buferlarni bog'lash
   SetIndexBuffer(0, TrendUpBuffer,    INDICATOR_DATA);
   SetIndexBuffer(1, TrendDownBuffer,  INDICATOR_DATA);
   SetIndexBuffer(2, BuyArrowBuffer,   INDICATOR_DATA);
   SetIndexBuffer(3, SellArrowBuffer,  INDICATOR_DATA);
   SetIndexBuffer(4, SupertrendBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, DirBuffer,        INDICATOR_CALCULATIONS);

   //--- o'q kodlari (Wingdings): 233 yuqoriga, 234 pastga
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, BuyArrowColor);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, SellArrowColor);

   //--- bo'sh qiymatlar (0.0 chizilmaydi)
   for(int p = 0; p < 4; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, 0.0);

   ArraySetAsSeries(TrendUpBuffer,    false);
   ArraySetAsSeries(TrendDownBuffer,  false);
   ArraySetAsSeries(BuyArrowBuffer,   false);
   ArraySetAsSeries(SellArrowBuffer,  false);
   ArraySetAsSeries(SupertrendBuffer, false);
   ArraySetAsSeries(DirBuffer,        false);

   //--- Point/Digits sozlash (5/3 xonali kotirovkalar uchun pips)
   g_point = _Point;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_digitsAdj = (digits == 3 || digits == 5) ? 10 : 1;

   //--- handle'larni yaratish
   hATR = iATR(_Symbol, _Period, ATR_Period);
   if(hATR == INVALID_HANDLE)
     {
      Print("ATR handle yaratilmadi");
      return(INIT_FAILED);
     }

   if(UseEMAFilter)
     {
      hEMA = iMA(_Symbol, _Period, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(hEMA == INVALID_HANDLE){ Print("EMA handle xato"); return(INIT_FAILED); }
     }

   if(UseRSIFilter)
     {
      hRSI = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
      if(hRSI == INVALID_HANDLE){ Print("RSI handle xato"); return(INIT_FAILED); }
     }

   if(UseMTFFilter)
     {
      hATR_MTF = iATR(_Symbol, HigherTF, ATR_Period);
      if(hATR_MTF == INVALID_HANDLE){ Print("MTF ATR handle xato"); return(INIT_FAILED); }
     }

   //--- indikator nomi va aniqlik
   IndicatorSetString(INDICATOR_SHORTNAME, "Zidelka Pro Signal");
   IndicatorSetInteger(INDICATOR_DIGITS, digits);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitsializatsiya                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hATR     != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hEMA     != INVALID_HANDLE) IndicatorRelease(hEMA);
   if(hRSI     != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATR_MTF != INVALID_HANDLE) IndicatorRelease(hATR_MTF);
   ObjectsDeleteAll(0, DASH_PREFIX);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Supertrend yo'nalishini yuqori TFda hisoblash                    |
//| Qaytaradi: +1 (up), -1 (down), 0 (ma'lumot yo'q)                 |
//+------------------------------------------------------------------+
int HigherTFDirection()
  {
   if(!UseMTFFilter) return(0);

   //--- yuqori TF uchun ATR va narxlarni olamiz
   double atr[];
   if(CopyBuffer(hATR_MTF, 0, 0, 3, atr) < 3) return(0);

   MqlRates r[];
   if(CopyRates(_Symbol, HigherTF, 0, 3, r) < 3) return(0);

   //--- oddiy 2-barli Supertrend yo'nalish taxminini hisoblaymiz
   double hl2  = (r[1].high + r[1].low) / 2.0;
   double upper = hl2 + ATR_Multiplier * atr[1];
   double lower = hl2 - ATR_Multiplier * atr[1];

   if(r[1].close > upper) return(+1);
   if(r[1].close < lower) return(-1);

   //--- oraliqda bo'lsa oldingi yopilishga qarab yo'nalish
   return(r[1].close >= hl2 ? +1 : -1);
  }

//+------------------------------------------------------------------+
//| Asosiy hisoblash                                                 |
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
   //--- kamida ATR uchun yetarli bar bo'lishi kerak
   int minBars = ATR_Period + 2;
   if(UseEMAFilter) minBars = MathMax(minBars, EMA_Period + 2);
   if(rates_total < minBars) return(0);

   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   //--- ATR/EMA/RSI qiymatlarini olamiz.
   //--- Muhim: massivlar buferlar (rates_total) bilan bir xil o'lchamda va
   //--- moslashgan bo'lishi shart, aks holda indekslar siljib ketadi.
   //--- To'liq nusxa ko'chirilmasa, keyingi tikda qayta uriniladi.
   double atr[], ema[], rsi[];
   if(CopyBuffer(hATR, 0, 0, rates_total, atr) != rates_total) return(0);
   ArraySetAsSeries(atr, false);

   if(UseEMAFilter)
     {
      if(CopyBuffer(hEMA, 0, 0, rates_total, ema) != rates_total) return(0);
      ArraySetAsSeries(ema, false);
     }
   if(UseRSIFilter)
     {
      if(CopyBuffer(hRSI, 0, 0, rates_total, rsi) != rates_total) return(0);
      ArraySetAsSeries(rsi, false);
     }

   //--- boshlanish indeksi
   int start;
   if(prev_calculated == 0)
     {
      start = ATR_Period + 1;
      //--- boshlang'ich holatni tozalash
      for(int i = 0; i < start; i++)
        {
         TrendUpBuffer[i]    = 0.0;
         TrendDownBuffer[i]  = 0.0;
         BuyArrowBuffer[i]   = 0.0;
         SellArrowBuffer[i]  = 0.0;
         SupertrendBuffer[i] = 0.0;
         DirBuffer[i]        = +1;
        }
     }
   else
      start = prev_calculated - 1;

   double arrowGap = ArrowGapPips * g_point * g_digitsAdj;

   //--- MTF yo'nalish (joriy holatga)
   int mtfDir = HigherTFDirection();

   //--- Supertrend rekursiv hisoblash
   for(int i = start; i < rates_total; i++)
     {
      double hl2   = (high[i] + low[i]) / 2.0;
      double upBand = hl2 + ATR_Multiplier * atr[i];
      double dnBand = hl2 - ATR_Multiplier * atr[i];

      double prevSt  = (i > 0) ? SupertrendBuffer[i-1] : dnBand;
      int    prevDir = (i > 0) ? (int)DirBuffer[i-1]   : +1;

      //--- bandlarni "yopishqoq" qilish (klassik Supertrend)
      if(prevDir > 0)
         dnBand = MathMax(dnBand, prevSt); // ko'tarilishda pastki band pasaymaydi
      else
         upBand = MathMin(upBand, prevSt); // tushishda yuqori band ko'tarilmaydi

      int dir = prevDir;
      double st;

      if(prevDir > 0)
        {
         //--- ko'tarilish trendi: narx pastki bandni teshsa -> tushishga o'tadi
         if(close[i] < dnBand){ dir = -1; st = upBand; }
         else                 { dir = +1; st = dnBand; }
        }
      else
        {
         //--- tushish trendi: narx yuqori bandni teshsa -> ko'tarilishga o'tadi
         if(close[i] > upBand){ dir = +1; st = dnBand; }
         else                 { dir = -1; st = upBand; }
        }

      SupertrendBuffer[i] = st;
      DirBuffer[i]        = dir;

      //--- chiziqlarni bo'yash
      if(dir > 0){ TrendUpBuffer[i] = st;  TrendDownBuffer[i] = 0.0; }
      else       { TrendDownBuffer[i] = st; TrendUpBuffer[i]  = 0.0; }

      //--- o'qlarni tozalash
      BuyArrowBuffer[i]  = 0.0;
      SellArrowBuffer[i] = 0.0;

      //--- signal faqat yo'nalish o'zgargan barda
      int prevDir2 = (i > 0) ? (int)DirBuffer[i-1] : dir;
      bool flipUp   = (dir > 0 && prevDir2 <= 0);
      bool flipDown = (dir < 0 && prevDir2 >= 0);

      if(flipUp && PassesFilters(+1, i, close[i], ema, rsi, mtfDir))
        {
         BuyArrowBuffer[i] = low[i] - arrowGap;
        }
      else if(flipDown && PassesFilters(-1, i, close[i], ema, rsi, mtfDir))
        {
         SellArrowBuffer[i] = high[i] + arrowGap;
        }
     }

   //--- alertlar: faqat yopilgan oxirgi barda
   HandleAlerts(rates_total, time, close);

   //--- dashboard
   if(ShowDashboard)
      UpdateDashboard(close[rates_total-1], (int)DirBuffer[rates_total-1],
                      (UseRSIFilter ? rsi[rates_total-1] : 0.0), mtfDir);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Filtrlar: yo'nalish (dir=+1 buy, -1 sell) mos keladimi?          |
//+------------------------------------------------------------------+
bool PassesFilters(int dir, int i, double price, const double &ema[], const double &rsi[], int mtfDir)
  {
   //--- EMA yo'nalish filtri
   if(UseEMAFilter)
     {
      if(dir > 0 && price < ema[i]) return(false);
      if(dir < 0 && price > ema[i]) return(false);
     }

   //--- RSI impuls filtri
   if(UseRSIFilter)
     {
      if(dir > 0 && rsi[i] < RSI_BuyLevel)  return(false);
      if(dir < 0 && rsi[i] > RSI_SellLevel) return(false);
     }

   //--- MTF tasdiq
   if(UseMTFFilter && mtfDir != 0)
     {
      if(dir > 0 && mtfDir < 0) return(false);
      if(dir < 0 && mtfDir > 0) return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Alertlar                                                         |
//+------------------------------------------------------------------+
void HandleAlerts(int rates_total, const datetime &time[], const double &close[])
  {
   int sig = rates_total - 2;                // oxirgi yopilgan bar

   if(sig < 0) return;

   int dir = 0;
   if(BuyArrowBuffer[sig]  > 0.0) dir = +1;
   if(SellArrowBuffer[sig] > 0.0) dir = -1;
   if(dir == 0) return;

   //--- bir bar uchun bir marta
   if(g_lastAlertBar == time[sig] && g_lastAlertDir == dir) return;
   g_lastAlertBar = time[sig];
   g_lastAlertDir = dir;

   string dirTxt = (dir > 0) ? "BUY ▲" : "SELL ▼";
   string msg = StringFormat("Zidelka Pro: %s signal | %s %s | Narx: %s",
                             dirTxt, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
                             DoubleToString(close[sig], _Digits));

   if(AlertPopup) Alert(msg);
   if(AlertPush)  SendNotification(msg);
   if(AlertEmail) SendMail("Zidelka Pro Signal", msg);
   if(AlertSound) PlaySound(SoundFile);
  }

//+------------------------------------------------------------------+
//| Dashboard paneli                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard(double price, int dir, double rsiVal, int mtfDir)
  {
   int x = 12, y = 22, w = 210, rowH = 20;
   string bg = DASH_PREFIX + "bg";

   //--- fon
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, x - 6);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, y - 6);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, rowH * 5 + 12);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'20,24,33');
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, C'60,70,90');
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);

   color trendColor = (dir > 0) ? clrDeepSkyBlue : clrTomato;
   string trendTxt  = (dir > 0) ? "KO'TARILISH ▲" : "TUSHISH ▼";

   DashLabel("t0", x, y + rowH*0, "ZIDELKA PRO SIGNAL", clrGold, 10, true);
   DashLabel("t1", x, y + rowH*1, "Trend:  " + trendTxt, trendColor, 9, false);

   if(UseRSIFilter)
      DashLabel("t2", x, y + rowH*2, "RSI:    " + DoubleToString(rsiVal, 1), clrSilver, 9, false);
   else
      DashLabel("t2", x, y + rowH*2, "RSI:    o'chirilgan", clrGray, 9, false);

   if(UseMTFFilter)
     {
      string mtfTxt = (mtfDir > 0) ? "KO'TARILISH ▲" : (mtfDir < 0 ? "TUSHISH ▼" : "—");
      color  mtfCol = (mtfDir > 0) ? clrDeepSkyBlue : (mtfDir < 0 ? clrTomato : clrGray);
      DashLabel("t3", x, y + rowH*3, "MTF ("+EnumToString(HigherTF)+"): "+mtfTxt, mtfCol, 9, false);
     }
   else
      DashLabel("t3", x, y + rowH*3, "MTF:    o'chirilgan", clrGray, 9, false);

   DashLabel("t4", x, y + rowH*4, "Narx:   " + DoubleToString(price, _Digits), clrSilver, 9, false);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Dashboard yozuv yordamchisi                                      |
//+------------------------------------------------------------------+
void DashLabel(string id, int x, int y, string text, color clr, int fontSize, bool bold)
  {
   string name = DASH_PREFIX + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString (0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }
//+------------------------------------------------------------------+
