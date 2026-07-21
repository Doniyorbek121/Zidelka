# Strategy Tester'da sinash qo'llanmasi

`ZidelkaProEA` robotini MetaTrader 5 ning **Strategy Tester** (Strategiya
sinovchisi) da qanday sinash bo'yicha to'liq amaliy qo'llanma.

> Eslatma: EA ishga tushganda `ZidelkaProSignal` indikatorini `iCustom` orqali
> avtomatik yuklaydi — indikator faylini alohida qo'shish shart emas, faqat u
> `MQL5/Indicators/Zidelka/` papkasida **kompilyatsiya qilingan** bo'lsin.

---

## 1. Tayyorgarlik

1. Ikkala faylni kompilyatsiya qiling (MetaEditor, **F7**):
   - `MQL5/Indicators/Zidelka/ZidelkaProSignal.mq5`
   - `MQL5/Experts/Zidelka/ZidelkaProEA.mq5`
2. Xatosiz kompilyatsiya bo'lganini tekshiring (0 error).

---

## 2. Strategy Tester'ni ochish

- Menyu: **View → Strategy Tester**, yoki **Ctrl + R**.
- Pastda "Strategy Tester" paneli ochiladi.

---

## 3. Asosiy sozlamalar (Settings tab)

| Maydon | Tavsiya qilinadigan qiymat | Izoh |
|--------|----------------------------|------|
| **Expert** | `ZidelkaProEA` | Robotni tanlang |
| **Symbol** | EURUSD (yoki o'zingiznikini) | Sinaladigan instrument |
| **Period** | H1 yoki H4 | EA ishlaydigan taymfreym |
| **Modelling** | **Every tick based on real ticks** | Eng aniq rejim (mavjud bo'lsa) |
| **Date** | Custom, 1–2 yillik oraliq | Yetarli tarix |
| **Deposit** | 10 000 USD | Boshlang'ich balans |
| **Leverage** | 1:100 yoki 1:500 | Broker sharoitiga yaqin |
| **Optimization** | Disabled (birinchi sinov) | Oddiy backtest |

> **Modelling** muhim: "Open prices only" tez, lekin noaniq. Aniq natija uchun
> "Every tick" yoki "Every tick based on real ticks" ni tanlang.

---

## 4. EA parametrlari (Inputs tab)

**Inputs** tabiga o'ting va sozlang. Muhim guruhlar:

### Risk / Lot
- `InpLotMode` = `LOT_RISK_PERCENT` (risk asosida)
- `InpRiskPercent` = **1.0** (har savdoda balansning 1% i)
- yoki `LOT_FIXED` + `InpFixedLot` = 0.10

### Stop Loss / Take Profit
- `InpSLMode` = `SL_ATR` (boshlanish uchun)
- `InpSLatrMult` = 1.5
- `InpTPratio` = 2.0 (R:R = 1:2)

### Trailing
- `InpUseTrailing` = true (Supertrend bo'ylab)

### Indikator (buferlar mos bo'lishi uchun)
- `InpATRPeriod`, `InpEMAPeriod`, `InpRSIPeriod`, `InpHigherTF` — asosiy
  indikatordagi qiymatlar bilan **bir xil** qoldiring (standart mos keladi).

### Likvidlik filtri (ixtiyoriy)
- `InpUseLiqFilter` = false (avval filtri o'chirilgan holda sinang)
- keyin true qilib, natijalarni solishtiring

---

## 5. Vizual rejimda kuzatish

- Settings tabida **Visual mode** (Vizual rejim) katagini belgilang.
- **Start** bosing.
- Grafik ochiladi va siz **real vaqtda** ko'rasiz:
  - Supertrend chizig'i, BUY/SELL o'qlari, likvidlik zonalari, dashboard
  - Robot pozitsiya ochib-yopishini
- Tezlikni pastdagi slayder bilan boshqaring.

> Vizual rejim EA `iCustom` orqali yuklagan indikatorni ham ko'rsatadi —
> signal va savdo mantiqini o'z ko'zingiz bilan tekshirasiz.

---

## 6. Natijalarni o'qish

Sinov tugagach quyidagi tablar chiqadi:

### Backtest (Results / Report)
| Ko'rsatkich | Nimani bildiradi | Yaxshi qiymat |
|-------------|------------------|---------------|
| **Total Net Profit** | Umumiy sof foyda | Musbat |
| **Profit Factor** | Foyda / zarar nisbati | > 1.3 |
| **Expected Payoff** | Har savdodagi o'rtacha natija | Musbat |
| **Maximal Drawdown** | Eng katta pasayish | < 20–30% |
| **Recovery Factor** | Foyda / drawdown | > 1 |
| **Total Trades** | Savdolar soni | ≥ 30 (statistik ishonch) |
| **Win Rate** (Profit Trades %) | Yutuqli savdolar ulushi | Kontekstga bog'liq |

### Graph tab
- **Balance/Equity egri chizig'i** — silliq va yuqoriga qarab o'ssa yaxshi.
- Keskin cho'qqi-tushishlar ko'p bo'lsa — risk yuqori.

---

## 7. Optimizatsiya (parametrlarni yaxshilash)

Bir necha parametrni avtomatik sinab, eng yaxshisini topish:

1. Settings tabida **Optimization** = `Slow complete algorithm` yoki
   `Fast genetic based algorithm`.
2. Inputs tabida optimallashtiriladigan parametrni belgilang (katakcha),
   **Start / Step / Stop** qiymatlarini kiriting. Masalan:
   - `InpSLatrMult`: 1.0 → 0.5 → 3.0
   - `InpTPratio`: 1.0 → 0.5 → 4.0
   - `InpATRMult`: 2.0 → 0.5 → 4.0
3. **Start** bosing. Tugagach natijalarni **Profit Factor** yoki **Recovery
   Factor** bo'yicha saralang.

> ⚠️ **Over-fitting**dan ehtiyot bo'ling: faqat bitta oraliqda mukammal
> ishlaydigan parametrlar kelajakda ishlamasligi mumkin. Topilgan sozlamani
> **boshqa davr** yoki **boshqa instrument**da (out-of-sample) tekshiring.

---

## 8. Ishonchli sinov uchun maslahatlar

- **Spread va komissiya**: brokeringizga yaqin real spread'da sinang. Tester
  sozlamalarida spread'ni "Current" yoki aniq qiymatga qo'ying.
- **Bir nechta instrument**: strategiya faqat bitta juftlikda emas, bir
  nechtasida ishlashini tekshiring.
- **Turli bozor sharoitlari**: trend, fleet (yon harakat) va volatil davrlarni
  qamrab oling.
- **Forward test**: backtest'dan so'ng albatta **demo hisobda** real vaqtda
  sinang — bu eng ishonchli tekshiruv.

---

## 9. Off-chart histogram va boshqa indikatorlar

Strategy Tester EA ni sinaydi. Indikatorlarning o'zini (masalan,
`ZidelkaProPressure` histogrami) alohida ko'rish uchun ularni **real/demo
grafikka** qo'ying — tester EA ichidagi indikatorni chizadi, lekin subwindow
kompanionni alohida ko'rsatmaydi.

---

> ⚠️ **Ogohlantirish:** Backtest natijasi — o'tmish. U kelajakdagi foydani
> kafolatlamaydi. Har qanday strategiyani real pulda ishlatishdan oldin demo
> hisobda uzoq sinang va risk-menejmentga qat'iy amal qiling.
