# Zidelka Pro Signal — MetaTrader 5 professional indikatori

Konfluensiyaga (bir nechta mustaqil signalning bir vaqtda mos kelishiga)
asoslangan professional savdo indikatori. Bitta ko'rsatkichga tayanmasdan,
**to'rt bosqichli filtr** orqali yuqori sifatli kirish nuqtalarini beradi.

## Strategiya mantig'i

Signal faqat quyidagi shartlarning **hammasi** mos kelganda paydo bo'ladi:

| Bosqich | Ko'rsatkich | Vazifasi |
|--------|-------------|----------|
| 1. Trend | **Supertrend (ATR)** | Asosiy trend yo'nalishini va uning o'zgargan (flip) nuqtasini aniqlaydi. Signal shu yerda tug'iladi. |
| 2. Yo'nalish | **EMA 200** | Narx EMA'dan yuqorida bo'lsagina BUY, pastda bo'lsagina SELL. Global trendga qarshi savdoni to'sadi. |
| 3. Impuls | **RSI 14** | BUY uchun RSI ≥ 50, SELL uchun RSI ≤ 50 — impuls signal yo'nalishini tasdiqlaydi. |
| 4. MTF tasdiq | **Yuqori taymfreym Supertrend** | Yuqori taymfreym (masalan H4) yo'nalishi joriy signalga qarama-qarshi bo'lsa, signal o'chiriladi. |

Natijada faqat **trend + yo'nalish + impuls + yuqori taymfreym** birlashgan
paytda BUY (▲) yoki SELL (▼) o'qi chiziladi.

### Likvidlik zonalari (SMC) — konfluensiya qatlami

Indikator qo'shimcha ravishda **institutsional likvidlik zonalarini** aniqlaydi
va grafikda chizadi (Smart Money Concepts uslubida):

| Zona | Aniqlash | Ma'no |
|------|----------|-------|
| **Imbalance (FVG)** | 3-barli bo'shliq (fair value gap) | Bozor tez o'tib ketgan, qaytib to'ldirishga moyil narx sohasi |
| **Stop-pool** | Swing pivot (yuqori/quyi ekstremum) | Stop-loss'lar to'plangan likvidlik javoni |

- 🟩 **Demand** (narx ostida) — tayanch sifatida ishlaydi
- 🟥 **Supply** (narx ustida) — qarshilik sifatida ishlaydi
- Zonalar narx tomonidan **iste'mol qilinganda** so'nadi, **sindirilganda** yo'qoladi

Ixtiyoriy **`UseLiquidityFilter`** parametri yoqilsa, signal faqat mos zona
yaqinida (masalan, BUY uchun pastda demand zonasi bor bo'lsa) tasdiqlanadi —
bu signal sifatini yanada oshiradi.

## Xususiyatlari

- 🎯 Supertrend asosidagi rangli trend chizig'i (ko'k = ko'tarilish, qizil = tushish)
- 🟢🔴 Grafikda BUY/SELL o'qlari (native buferlar, Data Window'da ko'rinadi)
- 🟩🟥 **Likvidlik zonalari**: FVG imbalance + stop-pool (SMC) — konfluensiya va ixtiyoriy filtr
- 📊 Grafik ustidagi jonli **dashboard**: trend, RSI, MTF, zonalar, eng yaqin demand/supply
- 🔔 To'liq alertlar: ekran, mobil push, email, ovoz
- ⚙️ Har bir filtrni alohida yoqish/o'chirish imkoniyati
- 📱 5/3 xonali kotirovkalar uchun avtomatik pips hisoblash
- ✅ **Qayta chizmaydigan (non-repainting) alertlar** — signal faqat bar
  yopilgandan keyin tasdiqlanadi

## O'rnatish

1. `MQL5/Indicators/Zidelka/ZidelkaProSignal.mq5` faylini MetaTrader 5
   ma'lumotlar papkasidagi `MQL5/Indicators/` ichiga nusxalang
   (MetaEditor'da: `Fayl → Ma'lumotlar papkasini ochish`).
2. **MetaEditor**'da faylni oching va **F7** (Compile) bosing.
3. MetaTrader 5'da `Navigator → Indicators` ro'yxatidan grafikka tashlang.

## Asosiy parametrlar

| Parametr | Standart | Izoh |
|----------|----------|------|
| `ATR_Period` | 10 | Supertrend ATR davri |
| `ATR_Multiplier` | 3.0 | Supertrend sezgirligi (kichik = ko'p signal) |
| `UseEMAFilter` / `EMA_Period` | true / 200 | Trend yo'nalish filtri |
| `UseRSIFilter` / `RSI_Period` | true / 14 | Impuls filtri |
| `UseMTFFilter` / `HigherTF` | true / H4 | Yuqori taymfreym tasdig'i |
| `ArrowGapPips` | 15 | O'q va narx orasidagi masofa |
| `AlertPopup/Push/Email/Sound` | — | Ogohlantirish kanallari |
| `UseFVG` / `UsePools` | true / true | Imbalance va stop-pool zonalarini ko'rsatish |
| `UseLiquidityFilter` | false | Signalni likvidlik zonalari bilan filtrlash |
| `ZoneProxATR` | 2.0 | Zona yaqinlik oralig'i (ATR) |
| `MaxZones` | 24 | Bir vaqtda ko'rsatiladigan maks. zonalar |

## Expert Advisor (avtomatik savdo roboti)

`MQL5/Experts/Zidelka/ZidelkaProEA.mq5` — yuqoridagi indikator signallariga
asoslangan avtomatik savdo roboti. Robot indikatorni `iCustom` orqali o'qiydi,
shuning uchun grafikdagi indikator bilan **to'liq sinxron** ishlaydi.

**Xususiyatlari:**

- 📉 Signal faqat **bar yopilgach** tasdiqlanadi (qayta chizmaydi)
- 💰 **Risk asosida lot** hisoblash (balansdan % risk) yoki fiksatsiyalangan lot
- 🛡️ **SL rejimlari:** ATR × koeffitsient / Supertrend chizig'i / fiksatsiyalangan points
- 🎯 **TP** — SL'ga nisbatan R:R koeffitsienti bilan
- 🔄 **Supertrend bo'ylab trailing stop** (foyda ochilgach)
- ↔️ Qarama-qarshi signalda pozitsiyani **teskarilash**
- ⏰ Savdo soatlari filtri, spread filtri, slippage nazorati, Magic number

**O'rnatish (indikator o'rnatilgan bo'lishi shart):**

1. `ZidelkaProSignal.mq5` ni `MQL5/Indicators/Zidelka/` ga qo'ying va kompilyatsiya qiling.
2. `ZidelkaProEA.mq5` ni `MQL5/Experts/Zidelka/` ga qo'ying va **F7** bilan kompilyatsiya qiling.
3. Grafikka tashlang, `AutoTrading` tugmasini yoqing.

> ⚠️ EA parametrlari (ATR davri, EMA, RSI, MTF) grafikdagi indikator
> sozlamalari bilan **bir xil** bo'lishi shart — aks holda buferlar mos kelmaydi.
> Har doim avval **Strategy Tester** va **demo hisob**da sinab ko'ring.

## Tavsiyalar

- **Skalping (M5–M15):** `ATR_Multiplier` 2.0, `HigherTF` = H1.
- **Kunlik savdo (H1–H4):** standart sozlamalar, `HigherTF` = H4 yoki D1.
- Signalni doim risk-menejment (Stop Loss / Take Profit) bilan qo'llang.
  Supertrend chizig'i tabiiy trailing-stop sifatida ishlatilishi mumkin.

> ⚠️ **Ogohlantirish:** Bu indikator tahlil vositasidir, moliyaviy maslahat
> emas. Har qanday strategiyani real hisobda ishlatishdan oldin demo hisobda
> va Strategy Tester'da sinab ko'ring.
