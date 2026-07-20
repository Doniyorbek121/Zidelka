//+------------------------------------------------------------------+
//|                                           ZidelkaProSignal.mq5   |
//|                                  Professional confluence system  |
//|                                                                  |
//|  Trend (Supertrend/ATR) + Yo'nalish (EMA) + Impuls (RSI)         |
//|  + Yuqori taymfreym tasdiq (MTF) + Dashboard + Alertlar          |
//+------------------------------------------------------------------+
#property copyright   "Zidelka"
#property link        "https://github.com/Doniyorbek121/Zidelka"
#property version     "1.20"
#property description "Professional konfluensiyaga asoslangan signal indikatori."
#property description "Supertrend + EMA + RSI + MTF + likvidlik zonalari (SMC)."
#property description "Zona bahosi (0-10), fill/sweep statistikasi, dashboard va alertlar."
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

//--- Eslatma: quyidagi likvidlik parametrlari inputlar ro'yxati oxirida
//--- turadi, chunki EA ularni iCustom orqali shu tartibda uzatadi.
input group "=== Likvidlik zonalari (SMC) ==="
input bool               UseFVG          = true;         // Imbalance (FVG) zonalari
input bool               UsePools        = true;         // Stop-pool (swing) zonalari
input int                ZonePivotLeft   = 8;            // Pivot chap (bar)
input int                ZonePivotRight  = 3;            // Pivot o'ng (bar)
input double             ZoneMinATR      = 0.10;         // Min zona balandligi (ATR mult)
input double             ZonePoolATR     = 0.30;         // Stop-pool balandligi (ATR mult)
input int                ZoneLookback    = 500;          // Zona qidirish oralig'i (bar)
input int                MaxZones        = 24;           // Maksimal faol zonalar
input bool               UseLiquidityFilter = false;     // Signalni zonalar bilan filtrlash
input double             ZoneProxATR     = 2.0;          // Zona yaqinlik oralig'i (ATR)
input color              DemandColor     = clrSeaGreen;  // Talab (demand) zonasi
input color              SupplyColor     = clrFireBrick; // Taklif (supply) zonasi
input int                ZoneTransp      = 85;           // Zona shaffofligi (60-95)

//--- Scoring/statistika parametrlari (faqat tahliliy — signalga ta'sir qilmaydi)
input group "=== Zona bahosi (Scoring 0-10) ==="
input bool               ShowZoneScore   = true;         // Zona bahosini yorliqda ko'rsatish
input double             EliteThreshold  = 8.0;          // Elite (kuchli) zona chegarasi
input int                VolBaseLen      = 50;           // Hajm bazaviy chizig'i (bar)
input double             ScoreSizeNorm   = 1.20;         // To'liq o'lcham bahosi uchun balandlik (ATR)
input double             ScoreVolNorm    = 1.40;         // To'liq hajm bahosi uchun hajm (× baza)
input double             ScoreTestNorm   = 3.0;          // To'liq test bahosi uchun testlar
input double             ScoreProxNorm   = 6.0;          // Yaqinlik oralig'i (ATR)
input double             WeightVol       = 0.30;         // Og'irlik: hajm bosimi
input double             WeightSize      = 0.25;         // Og'irlik: zona o'lchami
input double             WeightTest      = 0.20;         // Og'irlik: testlar
input double             WeightProx      = 0.25;         // Og'irlik: yaqinlik

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
#define ZONE_PREFIX "ZPS_zone_"

//+------------------------------------------------------------------+
//| Likvidlik zonasi tuzilmasi                                       |
//| type: +1 = SUPPLY (narx ustida), -1 = DEMAND (narx ostida)       |
//| kind: 0 = FVG (imbalance), 1 = STOP-POOL (swing)                 |
//+------------------------------------------------------------------+
struct SZone
  {
   datetime t1;          // zona boshlangan bar vaqti
   double   top;         // yuqori chegara
   double   bot;         // pastki chegara
   int      type;        // +1 supply, -1 demand
   int      kind;        // 0 fvg, 1 pool
   bool     mitigated;   // narx tomonidan iste'mol qilinganmi
   int      bornBar;     // yaratilgan bar indeksi (umr hisobi uchun)
   double   vol;         // shakllanish hajmi (scoring uchun)
   int      tests;       // zona necha marta sinovdan o'tgan
   bool     inside;      // hozir narx zona ichidami (test hisoblash uchun)
   double   score;       // 0-10 baho
  };

SZone    g_zones[];               // faol zonalar
int      g_zoneScanIdx = -1;      // keyingi skanerlanadigan yopilgan bar indeksi
double   g_nearDemand  = 0.0;     // dashboard uchun: eng yaqin talab zonasi
double   g_nearSupply  = 0.0;     // dashboard uchun: eng yaqin taklif zonasi
double   g_volBase     = 0.0;     // hajm bazaviy chizig'i (scoring)
double   g_topScore    = 0.0;     // eng kuchli faol zona bahosi

//--- statistika hisoblagichlari
int      g_gapTot = 0,  g_gapFilled = 0;   long g_gapBars = 0;
int      g_poolTot = 0, g_poolSwept = 0;   long g_poolBars = 0;

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
   ObjectsDeleteAll(0, ZONE_PREFIX);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Likvidlik zonalari — funksiyalar                                 |
//+------------------------------------------------------------------+

//--- zona uchun noyob ob'ekt nomlari
string ZoneName(const SZone &z)
  {
   return(ZONE_PREFIX + IntegerToString(z.kind) + "_" +
          IntegerToString(z.type) + "_" + IntegerToString((long)z.t1));
  }
string ZoneLabelName(const SZone &z) { return(ZoneName(z) + "_s"); }

//--- zona ob'ektlarini (quti + yorliq) o'chirish
void ZoneDelete(const SZone &z)
  {
   ObjectDelete(0, ZoneName(z));
   ObjectDelete(0, ZoneLabelName(z));
  }

//--- yulduzlar bilan baho ko'rsatkichi
string ScoreStars(double sc)
  {
   return(sc >= 8.0 ? "★★★★" : sc >= 6.5 ? "★★★" : sc >= 5.0 ? "★★" : sc >= 3.0 ? "★" : "·");
  }

//--- zona allaqachon mavjudmi (dublikatlarni oldini olish)
bool ZoneExists(datetime t1, int type, int kind)
  {
   for(int i = 0; i < ArraySize(g_zones); i++)
      if(g_zones[i].t1 == t1 && g_zones[i].type == type && g_zones[i].kind == kind)
         return(true);
   return(false);
  }

//--- yangi zona qo'shish (MaxZones cheklovi bilan). Qo'shilsa true qaytaradi.
bool AddZone(datetime t1, double top, double bot, int type, int kind, int bornBar, double vol)
  {
   if(top <= bot) return(false);
   if(ZoneExists(t1, type, kind)) return(false);

   //--- cheklovga yetganda eng eski zonani olib tashlaymiz
   while(ArraySize(g_zones) >= MaxZones && ArraySize(g_zones) > 0)
     {
      ZoneDelete(g_zones[0]);
      ArrayRemove(g_zones, 0, 1);
     }

   int n = ArraySize(g_zones);
   ArrayResize(g_zones, n + 1);
   g_zones[n].t1        = t1;
   g_zones[n].top       = top;
   g_zones[n].bot       = bot;
   g_zones[n].type      = type;
   g_zones[n].kind      = kind;
   g_zones[n].mitigated = false;
   g_zones[n].bornBar   = bornBar;
   g_zones[n].vol       = vol;
   g_zones[n].tests     = 0;
   g_zones[n].inside    = false;
   g_zones[n].score     = 0.0;
   return(true);
  }

//--- barcha zona ob'ektlarini va massivni tozalash
void ClearZones()
  {
   for(int i = 0; i < ArraySize(g_zones); i++)
      ZoneDelete(g_zones[i]);
   ArrayResize(g_zones, 0);
  }

//+------------------------------------------------------------------+
//| Zonalarni skanerlash (faqat yopilgan barlar, bir marta)          |
//+------------------------------------------------------------------+
void ScanZones(int rates_total, const datetime &time[], const double &high[],
               const double &low[], const double &close[], const double &atr[],
               const long &tickvol[])
  {
   int minIdx = ZonePivotLeft + ZonePivotRight + 2;

   //--- to'liq qayta hisoblashda holat va statistikani tiklaymiz
   if(g_zoneScanIdx < 0)
     {
      ClearZones();
      g_zoneScanIdx = MathMax(minIdx, rates_total - ZoneLookback);
      g_gapTot = 0; g_gapFilled = 0; g_gapBars = 0;
      g_poolTot = 0; g_poolSwept = 0; g_poolBars = 0;
     }

   //--- oxirgi YOPILGAN bar rates_total-2 (rates_total-1 hali shakllanmoqda)
   int lastClosed = rates_total - 2;

   for(int b = g_zoneScanIdx; b <= lastClosed; b++)
     {
      if(b < minIdx) continue;

      //--- 1) LIFECYCLE avval: testlar va fill/sweep hisobi.
      //--- (Aniqlashdan oldin, aks holda yangi FVG o'z barida hal bo'ladi.)
      for(int z = ArraySize(g_zones) - 1; z >= 0; z--)
        {
         bool demand = (g_zones[z].type < 0);
         //--- yaqin tomondagi teginish (test)
         bool touch  = demand ? (low[b]  <= g_zones[z].top && high[b] >= g_zones[z].bot)
                              : (high[b] >= g_zones[z].bot && low[b]  <= g_zones[z].top);
         if(touch)
           {
            g_zones[z].mitigated = true;
            if(!g_zones[z].inside){ g_zones[z].tests++; g_zones[z].inside = true; }
           }
         else
            g_zones[z].inside = false;

         //--- uzoq tomonga yetish = to'liq fill (FVG) / sweep (pool)
         bool resolved = demand ? (low[b] <= g_zones[z].bot) : (high[b] >= g_zones[z].top);
         if(resolved)
           {
            int life = b - g_zones[z].bornBar;
            if(g_zones[z].kind == 0){ g_gapFilled++;  g_gapBars  += life; }
            else                    { g_poolSwept++;  g_poolBars += life; }
            ZoneDelete(g_zones[z]);
            ArrayRemove(g_zones, z, 1);
           }
        }

      //--- 2) FVG (imbalance) aniqlash
      double thr = atr[b] * ZoneMinATR;
      if(UseFVG)
        {
         //--- bullish gap -> DEMAND (narx ostidagi tayanch)
         if(low[b] > high[b-2] && (low[b] - high[b-2]) >= thr)
            if(AddZone(time[b-2], low[b], high[b-2], -1, 0, b, (double)tickvol[b])) g_gapTot++;
         //--- bearish gap -> SUPPLY (narx ustidagi qarshilik)
         if(high[b] < low[b-2] && (low[b-2] - high[b]) >= thr)
            if(AddZone(time[b-2], low[b-2], high[b], +1, 0, b, (double)tickvol[b])) g_gapTot++;
        }

      //--- 3) Stop-pool (swing pivot) aniqlash
      if(UsePools)
        {
         int p = b - ZonePivotRight;
         if(p - ZonePivotLeft >= 0)
           {
            bool isHigh = true, isLow = true;
            for(int k = 1; k <= ZonePivotLeft; k++)
              { if(high[p-k] >  high[p]) isHigh = false; if(low[p-k] <  low[p]) isLow = false; }
            for(int k = 1; k <= ZonePivotRight; k++)
              { if(high[p+k] >= high[p]) isHigh = false; if(low[p+k] <= low[p]) isLow = false; }

            double poolH = atr[p] * ZonePoolATR;
            if(isHigh)  //--- swing high ustida SUPPLY pool
               if(AddZone(time[p], high[p] + poolH, high[p], +1, 1, p, (double)tickvol[p])) g_poolTot++;
            if(isLow)   //--- swing low ostida DEMAND pool
               if(AddZone(time[p], low[p], low[p] - poolH, -1, 1, p, (double)tickvol[p])) g_poolTot++;
           }
        }
     }

   g_zoneScanIdx = rates_total - 1;   // keyingi yopiladigan bardan davom etamiz
  }

//+------------------------------------------------------------------+
//| Zona konfluensiya filtri (signal uchun)                          |
//| dir>0 BUY: narx ostida yaqin DEMAND zona bo'lsa o'tadi           |
//| dir<0 SELL: narx ustida yaqin SUPPLY zona bo'lsa o'tadi          |
//+------------------------------------------------------------------+
bool ZoneFilterPass(int dir, double price, double atrVal)
  {
   if(atrVal <= 0) return(true);
   double rng = ZoneProxATR * atrVal;

   for(int i = 0; i < ArraySize(g_zones); i++)
     {
      SZone z = g_zones[i];
      if(dir > 0 && z.type < 0)          //--- DEMAND (tayanch)
        {
         if(z.top <= price && (price - z.top) <= rng) return(true);
         if(price >= z.bot && price <= z.top)         return(true); // ichida
        }
      if(dir < 0 && z.type > 0)          //--- SUPPLY (qarshilik)
        {
         if(z.bot >= price && (z.bot - price) <= rng) return(true);
         if(price >= z.bot && price <= z.top)         return(true);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Zona bahosi (0-10): hajm + o'lcham + testlar + yaqinlik          |
//+------------------------------------------------------------------+
double ScoreZone(const SZone &z, double price, double atrVal)
  {
   if(atrVal <= 0) return(0.0);

   double h     = z.top - z.bot;
   double sizeF = MathMin(h / (atrVal * ScoreSizeNorm), 1.0);
   double volF  = (g_volBase > 0) ? MathMin(z.vol / (g_volBase * ScoreVolNorm), 1.0) : 0.0;
   double testF = MathMin(z.tests / MathMax(ScoreTestNorm, 1.0), 1.0);
   double dist  = MathAbs((z.top + z.bot) / 2.0 - price);
   double proxF = MathMax(1.0 - dist / (atrVal * ScoreProxNorm), 0.0);

   double wSum = WeightVol + WeightSize + WeightTest + WeightProx;
   if(wSum <= 0) return(0.0);

   double raw = (volF*WeightVol + sizeF*WeightSize + testF*WeightTest + proxF*WeightProx) / wSum;
   return(MathMin(MathMax(raw * 10.0, 0.0), 10.0));
  }

//+------------------------------------------------------------------+
//| Zonalarni chizish, baholash va eng yaqin zonalarni hisoblash     |
//+------------------------------------------------------------------+
void DrawZones(double price, double atrVal)
  {
   g_nearDemand = 0.0;
   g_nearSupply = 0.0;
   g_topScore   = 0.0;
   double bestDem = 0.0, bestSup = 0.0;

   for(int i = 0; i < ArraySize(g_zones); i++)
     {
      //--- bahoni yangilaymiz
      g_zones[i].score = ScoreZone(g_zones[i], price, atrVal);
      SZone z = g_zones[i];
      if(z.score > g_topScore) g_topScore = z.score;

      string nm = ZoneName(z);
      color  c  = (z.type < 0) ? DemandColor : SupplyColor;
      bool   elite = (z.score >= EliteThreshold);
      int    tr = z.mitigated ? MathMin(ZoneTransp + 8, 97) : ZoneTransp;
      //--- elite zonalar bir oz to'yingroq ko'rinadi
      if(elite && !z.mitigated) tr = MathMax(tr - 10, 55);

      //--- shaffoflik ARGB alfa kanali orqali (tr: 0=to'liq, 100=ko'rinmas)
      int  a     = (int)MathRound(255.0 * (100 - tr) / 100.0);
      uint fillC = ColorToARGB(c, a);   // OBJ_RECTANGLE fill = OBJPROP_COLOR

      if(ObjectFind(0, nm) < 0)
        {
         ObjectCreate(0, nm, OBJ_RECTANGLE, 0, z.t1, z.top, TimeCurrent(), z.bot);
         ObjectSetInteger(0, nm, OBJPROP_BACK, true);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_FILL, true);
         ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
        }
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, z.t1);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, z.top);
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, TimeCurrent());
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, z.bot);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, fillC);

      //--- baho yorlig'i (zona o'ng chetida)
      string ln = ZoneLabelName(z);
      if(ShowZoneScore)
        {
         string kd  = (z.kind == 0 ? "FVG" : "POOL");
         string arw = (z.type > 0 ? "▲" : "▼");
         string txt = arw + kd + " " + ScoreStars(z.score) + " " +
                      DoubleToString(z.score, 1) + (z.tests > 0 ? " ·" + IntegerToString(z.tests) + "T" : "");
         if(ObjectFind(0, ln) < 0)
           {
            ObjectCreate(0, ln, OBJ_TEXT, 0, TimeCurrent(), (z.top + z.bot) / 2.0);
            ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, ln, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, 8);
           }
         ObjectSetInteger(0, ln, OBJPROP_TIME, 0, TimeCurrent());
         ObjectSetDouble (0, ln, OBJPROP_PRICE, 0, (z.top + z.bot) / 2.0);
         ObjectSetString (0, ln, OBJPROP_TEXT, txt);
         ObjectSetInteger(0, ln, OBJPROP_COLOR, elite ? clrGold : c);
        }
      else
         ObjectDelete(0, ln);

      //--- eng yaqin zonalar (narxdan pastdagi demand va ustidagi supply)
      if(z.type < 0 && z.top <= price)      // demand narx ostida
        { if(bestDem == 0.0 || z.top > bestDem) bestDem = z.top; }
      if(z.type > 0 && z.bot >= price)      // supply narx ustida
        { if(bestSup == 0.0 || z.bot < bestSup) bestSup = z.bot; }
     }

   g_nearDemand = bestDem;
   g_nearSupply = bestSup;
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

   ArraySetAsSeries(time,        false);
   ArraySetAsSeries(open,        false);
   ArraySetAsSeries(high,        false);
   ArraySetAsSeries(low,         false);
   ArraySetAsSeries(close,       false);
   ArraySetAsSeries(tick_volume, false);

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
      g_zoneScanIdx = -1;   // to'liq qayta hisoblashda zonalar tiklanadi
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

   //--- likvidlik zonalarini yangilaymiz (signal filtridan OLDIN, chunki
   //--- filtr joriy zona holatiga tayanadi)
   if(UseFVG || UsePools)
      ScanZones(rates_total, time, high, low, close, atr, tick_volume);

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

      if(flipUp && PassesFilters(+1, i, close[i], atr[i], ema, rsi, mtfDir))
        {
         BuyArrowBuffer[i] = low[i] - arrowGap;
        }
      else if(flipDown && PassesFilters(-1, i, close[i], atr[i], ema, rsi, mtfDir))
        {
         SellArrowBuffer[i] = high[i] + arrowGap;
        }
     }

   //--- zonalarni chizamiz, baholaymiz va eng yaqin zonalarni yangilaymiz
   if(UseFVG || UsePools)
     {
      //--- hajm bazaviy chizig'i (scoring uchun)
      int vlen = MathMin(VolBaseLen, rates_total);
      long vsum = 0;
      for(int k = rates_total - vlen; k < rates_total; k++)
         vsum += tick_volume[k];
      g_volBase = (vlen > 0) ? (double)vsum / vlen : 0.0;

      DrawZones(close[rates_total-1], atr[rates_total-1]);
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
bool PassesFilters(int dir, int i, double price, double atrVal,
                   const double &ema[], const double &rsi[], int mtfDir)
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

   //--- likvidlik zonasi konfluensiyasi
   if(UseLiquidityFilter && !ZoneFilterPass(dir, price, atrVal))
      return(false);

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
   int x = 12, y = 22, w = 240, rowH = 20;
   bool showZones = (UseFVG || UsePools);
   int rows = showZones ? 11 : 5;
   string bg = DASH_PREFIX + "bg";

   //--- fon
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, x - 6);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, y - 6);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, rowH * rows + 12);
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

   if(showZones)
     {
      int liveZones = ArraySize(g_zones);
      string filtTxt = UseLiquidityFilter ? " [filtr ON]" : "";
      DashLabel("t5", x, y + rowH*5, "Zonalar: " + IntegerToString(liveZones) + filtTxt, clrGold, 9, false);

      string supTxt = (g_nearSupply > 0.0)
                      ? DoubleToString(g_nearSupply, _Digits) : "—";
      DashLabel("t6", x, y + rowH*6, "▲ Supply: " + supTxt, clrFireBrick, 9, false);

      string demTxt = (g_nearDemand > 0.0)
                      ? DoubleToString(g_nearDemand, _Digits) : "—";
      DashLabel("t7", x, y + rowH*7, "▼ Demand: " + demTxt, clrSeaGreen, 9, false);

      //--- eng kuchli zona bahosi
      color topCol = (g_topScore >= EliteThreshold) ? clrGold
                     : (g_topScore >= 5.0 ? clrSilver : clrGray);
      DashLabel("t8", x, y + rowH*8, "Top ball: " + ScoreStars(g_topScore) + " " +
                DoubleToString(g_topScore, 1) + "/10", topCol, 9, false);

      //--- statistika: fill/sweep rate
      double fillRate  = (g_gapTot  > 0) ? 100.0 * g_gapFilled / g_gapTot  : 0.0;
      double sweepRate = (g_poolTot > 0) ? 100.0 * g_poolSwept / g_poolTot : 0.0;
      double avgFill   = (g_gapFilled > 0) ? (double)g_gapBars  / g_gapFilled  : 0.0;
      double avgSweep  = (g_poolSwept > 0) ? (double)g_poolBars / g_poolSwept : 0.0;

      DashLabel("t9", x, y + rowH*9,
                StringFormat("FVG fill:  %.0f%% (%d/%d) ~%.0fb", fillRate, g_gapFilled, g_gapTot, avgFill),
                fillRate >= 50 ? clrMediumSeaGreen : clrGoldenrod, 9, false);
      DashLabel("t10", x, y + rowH*10,
                StringFormat("Pool sweep: %.0f%% (%d/%d) ~%.0fb", sweepRate, g_poolSwept, g_poolTot, avgSweep),
                sweepRate >= 50 ? clrOrchid : clrGoldenrod, 9, false);
     }
   else
     {
      //--- zonalar o'chirilgan bo'lsa qoldiq yozuvlarni tozalaymiz
      for(int r = 5; r <= 10; r++)
         ObjectDelete(0, DASH_PREFIX + "t" + IntegerToString(r));
     }

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
