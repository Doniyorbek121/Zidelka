#!/usr/bin/env python3
"""
Zidelka MQL5 struktura validatori.

MetaEditor (Windows) kompilyatorisiz bajarish mumkin bo'lgan ishonchli
tekshiruvlar. To'liq kompilyatsiya o'rnini bosmaydi, lekin ko'p uchraydigan
xatolarni ushlaydi:
  - fayl bo'sh emasligi va UTF-8 ekanligi
  - qavslar balansi ()  {}  []  (izoh va satrlar hisobga olinmaydi)
  - majburiy #property version
  - kamida bitta hodisa funksiyasi (OnInit/OnCalculate/OnTick/OnStart)
  - tasodifan qolib ketgan Pine Script sintaksisi (MQL5'da yo'q)
"""
import re
import sys
from pathlib import Path

# MQL5'da hech qachon uchramaydigan, Pine Script'dan qolib ketishi mumkin
# bo'lgan belgilar (izoh/satrlar tozalangandan keyin qidiriladi):
PINE_MARKERS = [
    r"@version\s*=",
    r"\bcolor\.new\s*\(",
    r"\binput\.(bool|int|float|string|color|bool)\s*\(",
    r"\bta\.",
    r"\bstrategy\s*\(",
    r"\bplotshape\s*\(",
    r"\bplotchar\s*\(",
    r"\bvarip\b",
]

EVENT_FUNCS = ("OnInit", "OnCalculate", "OnTick", "OnStart", "OnDeinit")


def strip_comments_and_literals(src: str) -> str:
    """Izoh, satr va belgi literallarini bo'shliqqa almashtiradi
    (yangi qatorlar saqlanadi). Holat mashinasi orqali ishonchli."""
    out = []
    i, n = 0, len(src)
    NORMAL, LINE, BLOCK, DQ, SQ = range(5)
    state = NORMAL
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if state == NORMAL:
            if c == "/" and nxt == "/":
                state = LINE; out.append("  "); i += 2; continue
            if c == "/" and nxt == "*":
                state = BLOCK; out.append("  "); i += 2; continue
            if c == '"':
                state = DQ; out.append(" "); i += 1; continue
            if c == "'":
                state = SQ; out.append(" "); i += 1; continue
            out.append(c); i += 1; continue
        if state == LINE:
            if c == "\n":
                state = NORMAL; out.append("\n")
            else:
                out.append(" ")
            i += 1; continue
        if state == BLOCK:
            if c == "*" and nxt == "/":
                state = NORMAL; out.append("  "); i += 2; continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if state == DQ:
            if c == "\\":
                out.append("  "); i += 2; continue
            if c == '"':
                state = NORMAL
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if state == SQ:
            if c == "\\":
                out.append("  "); i += 2; continue
            if c == "'":
                state = NORMAL
            out.append("\n" if c == "\n" else " "); i += 1; continue
    return "".join(out)


def check_brackets(code: str):
    """Qavslar balansini tekshiradi. Xatolar ro'yxatini qaytaradi."""
    pairs = {")": "(", "]": "[", "}": "{"}
    openers = set(pairs.values())
    stack = []
    line = 1
    errors = []
    for ch in code:
        if ch == "\n":
            line += 1
        elif ch in openers:
            stack.append((ch, line))
        elif ch in pairs:
            if not stack or stack[-1][0] != pairs[ch]:
                errors.append(f"{line}-qatorda mos kelmagan '{ch}'")
                if len(errors) > 5:
                    break
            else:
                stack.pop()
    for opener, ln in stack[:5]:
        errors.append(f"{ln}-qatorda yopilmagan '{opener}'")
    return errors


def validate(path: Path):
    errors = []
    try:
        raw = path.read_bytes()
    except Exception as e:
        return [f"o'qib bo'lmadi: {e}"]

    if not raw.strip():
        return ["fayl bo'sh"]

    try:
        src = raw.decode("utf-8-sig")
    except UnicodeDecodeError as e:
        return [f"UTF-8 emas: {e}"]

    code = strip_comments_and_literals(src)

    errors += check_brackets(code)

    if not re.search(r"#property\s+version", src):
        errors.append("#property version yo'q")

    if not any(f in code for f in EVENT_FUNCS):
        errors.append("hech qanday hodisa funksiyasi yo'q (OnInit/OnCalculate/OnTick/OnStart)")

    for marker in PINE_MARKERS:
        m = re.search(marker, code)
        if m:
            ln = code[: m.start()].count("\n") + 1
            errors.append(f"{ln}-qatorda Pine Script sintaksisi: '{m.group(0).strip()}'")

    return errors


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    files = sorted(root.rglob("*.mq5")) + sorted(root.rglob("*.mqh"))
    if not files:
        print("::warning::.mq5/.mqh fayllar topilmadi")
        return 0

    total_errors = 0
    for f in files:
        errs = validate(f)
        rel = f.relative_to(root) if root in f.parents or root == Path(".") else f
        if errs:
            total_errors += len(errs)
            print(f"::group::❌ {rel}")
            for e in errs:
                print(f"::error file={rel}::{e}")
                print(f"   - {e}")
            print("::endgroup::")
        else:
            print(f"✅ {rel}")

    print()
    if total_errors:
        print(f"Validatsiya muvaffaqiyatsiz: {total_errors} ta muammo topildi.")
        return 1
    print(f"Barcha {len(files)} ta fayl validatsiyadan o'tdi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
