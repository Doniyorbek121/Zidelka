//+------------------------------------------------------------------+
//|                                         ZidelkaProPressure.mq5   |
//|         Net Pull (bosim) off-chart histogrami — kompanion         |
//|                                                                  |
//|  ZidelkaProSignal indikatorining net-pull qiymatini (bufer 6)    |
//|  iCustom orqali o'qib, alohida oynada histogram sifatida chizadi.|
//+------------------------------------------------------------------+
#property copyright   "Zidelka"
#property link        "https://github.com/Doniyorbek121/Zidelka"
#property version     "1.00"
#property description "Zidelka Pro net-pull bosimini alohida oynada ko'rsatuvchi histogram."

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_minimum -100
#property indicator_maximum 100
#property indicator_level1  0
#property indicator_levelstyle STYLE_DOT
#property indicator_levelcolor clrGray

#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrFireBrick, clrSeaGreen
#property indicator_width1  3
#property indicator_label1  "Net Pull"

//+------------------------------------------------------------------+
//| Kirish parametrlari                                              |
//| Eslatma: bular grafikdagi ZidelkaProSignal sozlamalari bilan MOS |
//| bo'lishi kerak (standart qiymatlar allaqachon mos). Faqat zona   |
//| va scoring parametrlari histogramga ta'sir qiladi.               |
//+------------------------------------------------------------------+
input group "=== Bosimga ta'sir qiluvchi (indikator bilan mos) ==="
input int                InpATRPeriod    = 10;    // ATR davri
input bool               InpUseFVG       = true;  // Imbalance (FVG) zonalari
input bool               InpUsePools     = true;  // Stop-pool (swing) zonalari
input int                InpZonePivotL   = 8;     // Pivot chap
input int                InpZonePivotR   = 3;     // Pivot o'ng
input double             InpZoneMinATR   = 0.10;  // Min zona balandligi (ATR)
input double             InpZonePoolATR  = 0.30;  // Stop-pool balandligi (ATR)
input int                InpZoneLookback = 500;   // Zona qidirish oralig'i (bar)
input int                InpMaxZones     = 24;    // Maksimal faol zonalar
input int                InpVolBaseLen   = 50;    // Hajm bazaviy chizig'i (bar)
input double             InpScoreSizeNorm= 1.20;  // O'lcham normasi (ATR)
input double             InpScoreVolNorm = 1.40;  // Hajm normasi (× baza)
input double             InpScoreTestNorm= 3.0;   // Test normasi
input double             InpScoreProxNorm= 6.0;   // Yaqinlik normasi (ATR)
input double             InpWeightVol    = 0.30;  // Og'irlik: hajm
input double             InpWeightSize   = 0.25;  // Og'irlik: o'lcham
input double             InpWeightTest   = 0.20;  // Og'irlik: testlar
input double             InpWeightProx   = 0.25;  // Og'irlik: yaqinlik

input group "=== Ko'rinish ==="
input color              InpUpColor      = clrFireBrick; // Yuqoriga tortish (+)
input color              InpDnColor      = clrSeaGreen;  // Pastga tortish (−)
input int                InpWidth        = 3;            // Histogram qalinligi

//+------------------------------------------------------------------+
//| Buferlar                                                         |
//+------------------------------------------------------------------+
double PullVal[];   // net pull qiymati (-100..+100)
double ColIdx[];    // rang indeksi: 0 = yuqoriga, 1 = pastga

int    g_handle = INVALID_HANDLE;

//--- asosiy indikatorning pull buferi indeksi
#define MAIN_PULL_BUFFER 6

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, PullVal, INDICATOR_DATA);
   SetIndexBuffer(1, ColIdx,  INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpUpColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpDnColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpWidth);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   IndicatorSetString(INDICATOR_SHORTNAME, "Zidelka Pro Net Pull");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   //--- asosiy indikatorni yuklaymiz (chizmasdan — barcha vizuallar o'chirilgan).
   //--- Parametrlar tartibi ZidelkaProSignal inputlari bilan bir xil.
   g_handle = iCustom(_Symbol, _Period, "Zidelka\\ZidelkaProSignal",
                      InpATRPeriod, 3.0,            // ATR_Period, ATR_Multiplier
                      true, 200,                    // UseEMA, EMA_Period
                      true, 14, 50.0, 50.0,         // UseRSI, RSI_Period, RSI_Buy, RSI_Sell
                      true, PERIOD_H4,              // UseMTF, HigherTF
                      15,                           // ArrowGapPips
                      clrLime, clrRed,              // Buy/Sell rang
                      false,                        // ShowDashboard OFF
                      false, false, false, false, "", // alertlar OFF
                      InpUseFVG, InpUsePools,       // UseFVG, UsePools
                      InpZonePivotL, InpZonePivotR, // pivotlar
                      InpZoneMinATR, InpZonePoolATR,
                      InpZoneLookback, InpMaxZones,
                      false, 2.0,                   // UseLiquidityFilter OFF, ZoneProxATR
                      clrSeaGreen, clrFireBrick, 85,// zona rang/shaffoflik (chizilmaydi)
                      false, 8.0,                   // ShowZoneScore OFF, EliteThreshold
                      InpVolBaseLen,
                      InpScoreSizeNorm, InpScoreVolNorm, InpScoreTestNorm, InpScoreProxNorm,
                      InpWeightVol, InpWeightSize, InpWeightTest, InpWeightProx,
                      false);                       // ShowPressure OFF

   if(g_handle == INVALID_HANDLE)
     {
      Print("Xato: ZidelkaProSignal indikatorini yuklab bo'lmadi. ",
            "MQL5/Indicators/Zidelka/ papkasida ekanligini tekshiring.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_handle != INVALID_HANDLE)
      IndicatorRelease(g_handle);
  }

//+------------------------------------------------------------------+
//| Hisoblash                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   //--- asosiy indikatordan net-pull buferini nusxalaymiz (seriya tartibida)
   ArraySetAsSeries(PullVal, true);
   ArraySetAsSeries(ColIdx,  true);

   int copied = CopyBuffer(g_handle, MAIN_PULL_BUFFER, 0, rates_total, PullVal);
   if(copied <= 0)
      return(prev_calculated);   // ma'lumot hali tayyor emas — keyingi tikda

   //--- rang indeksini belgilaymiz (0 = yuqoriga tortish, 1 = pastga)
   for(int i = 0; i < copied; i++)
      ColIdx[i] = (PullVal[i] >= 0.0) ? 0.0 : 1.0;

   return(rates_total);
  }
//+------------------------------------------------------------------+
