# Instrumentga parametrlarni moslash qo'llanmasi

`ZidelkaProSignal` / `ZidelkaProEA` parametrlarini har xil instrument turlariga
qanday moslash bo'yicha amaliy tavsiyalar. Bu qiymatlar — **boshlang'ich nuqta**;
har birini o'z brokeringizda `Strategy Tester` da tekshiring.

---

## Asosiy tamoyillar (universal qoidalar)

| Instrument xususiyati | Parametrga ta'siri |
|-----------------------|--------------------|
| **Yuqori volatillik** (gold, crypto, GBP krosslar) | `ATR_Multiplier` ↑ (yolg'on flip kam), SL kengroq, risk % ↓ |
| **Past volatillik** (EURUSD, EURGBP) | `ATR_Multiplier` standart, ko'proq signal |
| **Kuchli trend moyilligi** | EMA filtri (200) muhim, trailing yoqilgan |
| **Gap/bo'shliqqa moyil** (indekslar, crypto) | **FVG zonalari** juda foydali |
| **Keng spred** | Yuqoriroq taymfreym, `InpMaxSpread` cheklovi |
| **Sessiyaga bog'liq** (indekslar) | Savdo soatlari filtri (`InpUseHours`) |

> Oltin qoida: **volatillik oshgani sari** — `ATR_Multiplier` va SL ni oshiring,
> risk foizini kamaytiring.

---

## Instrument bo'yicha tavsiyalar

### 1. Forex major juftliklar — EURUSD, USDJPY, USDCHF, AUDUSD

Muvozanatli, tor spred, texnik darajalarni yaxshi hurmat qiladi. **Standart
sozlamalar** aynan shu juftliklar uchun tuzilgan.

| Parametr | Qiymat |
|----------|--------|
| `ATR_Period` / `ATR_Multiplier` | 10 / **3.0** |
| `EMA_Period` | 200 |
| `RSI_Period` | 14 (50/50) |
| `HigherTF` | H4 (asosiy TF H1 bo'lsa) |
| `ZoneMinATR` | 0.10 |
| SL: `InpSLMode` / `InpSLatrMult` | ATR / 1.5 |
| `InpTPratio` | 2.0 |
| `InpRiskPercent` | 1.0 |

**Eng yaxshi TF:** H1–H4.

---

### 2. Volatil forex krosslar — GBPJPY, GBPNZD, GBPAUD, EURNZD

Katta harakat, keng "shovqin". Supertrend'ni sekinroq qiling, stoplarni kengaytiring.

| Parametr | Qiymat |
|----------|--------|
| `ATR_Multiplier` | **3.5–4.0** |
| `ZoneMinATR` | 0.15 (kattaroq zona) |
| SL `InpSLatrMult` | 2.0 |
| `InpTPratio` | 1.8–2.0 |
| `InpRiskPercent` | **0.5–0.75** (kamroq) |

**Eng yaxshi TF:** H1–H4. M15'da shovqin ko'p.

---

### 3. Oltin — XAUUSD (Gold)

Kuchli trend, yuqori volatillik, likvidlikni juda yaxshi hurmat qiladi —
**zonalar va net-pull bu yerda ayniqsa foydali**.

| Parametr | Qiymat |
|----------|--------|
| `ATR_Multiplier` | **2.5–3.0** |
| `EMA_Period` | 200 |
| `HigherTF` | H4 yoki D1 |
| `ZonePoolATR` | 0.30 |
| `UseLiquidityFilter` | true (sinab ko'ring) |
| SL `InpSLatrMult` | 1.8–2.0 |
| `InpTPratio` | 2.0–2.5 |
| `InpRiskPercent` | **0.5** (volatillik yuqori) |

**Eng yaxshi TF:** M30–H4. `InpMaxSpread` ni broker spred'iga moslang.

---

### 4. Indekslar — US30 (Dow), NAS100, SP500, GER40

Kuchli trend, sessiya ochilishida **real gaplar** (FVG uchun ideal). Sessiya
filtri muhim.

| Parametr | Qiymat |
|----------|--------|
| `ATR_Multiplier` | **2.5–3.0** |
| `UseFVG` | true (gaplar ko'p — juda mos) |
| `ZoneMinATR` | 0.10 |
| `InpUseHours` | true (savdo sessiyasi bilan cheklang) |
| SL `InpSLatrMult` | 1.5–2.0 |
| `InpTPratio` | 2.0 |
| `InpRiskPercent` | 0.75 |

**Eng yaxshi TF:** M15–H1 (sessiya ichida savdo).

---

### 5. Kriptovalyuta — BTCUSD, ETHUSD

24/7, ekstremal volatillik, uzoq kuchli trendlar. Sekin sozlamalar, past risk.

| Parametr | Qiymat |
|----------|--------|
| `ATR_Multiplier` | **3.5–4.0** |
| `EMA_Period` | 200 |
| `HigherTF` | H4 yoki D1 |
| `ZoneMinATR` | 0.20 |
| SL `InpSLatrMult` | 2.5 |
| `InpTPratio` | 2.5–3.0 (trend uzoq) |
| `InpRiskPercent` | **0.5** yoki kamroq |

**Eng yaxshi TF:** H1–H4. Trailing (Supertrend) katta trendlarda foyda beradi.

---

## Savdo uslubiga qarab TF va tezlik

| Uslub | Asosiy TF | `HigherTF` | `ATR_Multiplier` |
|-------|-----------|-----------|------------------|
| **Skalping** | M5–M15 | H1 | 2.0–2.5 (tezroq signal) |
| **Intraday** | M30–H1 | H4 | 2.5–3.0 |
| **Swing** | H4–D1 | D1–W1 | 3.0–4.0 (sekinroq, ishonchli) |

---

## Moslash algoritmi (qanday tanlash)

1. **Instrument turini** aniqlang (major / volatil / gold / indeks / crypto).
2. Yuqoridagi jadvaldan **boshlang'ich qiymatlarni** oling.
3. `Strategy Tester` (Visual mode) da 1–2 yillik davrda sinang.
4. Signallar juda **ko'p va yolg'on** bo'lsa → `ATR_Multiplier` ni oshiring.
5. Signallar juda **kam** bo'lsa → `ATR_Multiplier` ni kamaytiring yoki
   `UseMTFFilter` / `UseLiquidityFilter` ni o'chiring.
6. Drawdown yuqori bo'lsa → `InpRiskPercent` va SL ni qayta ko'rib chiqing.
7. Topilgan sozlamani **boshqa davr/instrumentda** (out-of-sample) tekshiring.

> ⚠️ Bir instrument uchun mukammal sozlama boshqasida ishlamasligi mumkin.
> Har bir instrument uchun alohida profil saqlang (Tester'da "Save" / preset).
> Backtest kelajakni kafolatlamaydi — demo forward-test majburiy.
