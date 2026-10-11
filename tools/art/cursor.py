"""Курсор-банка энергетика (пиксель-арт, как на референсе): чёрная банка, фиолетовые «когти»,
белая надпись, серебряная крышка, светлая обводка — чтобы курсор читался на тёмном интерфейсе.
Пишется SVG (текст, чётко на любом масштабе). Запуск: python3 tools/art/cursor.py → godot/art/ui/cursor_can.svg"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "art", "ui", "cursor_can.svg")
PAL = {
    "o": "#f6d6ec",  # обводка
    "k": "#0b090d", "K": "#1d1a22", "e": "#2c2834",  # тело, блик, край
    "s": "#6e6878", "S": "#b4aec0", "w": "#ecebf2",  # крышка
    "p": "#8a1f86", "P": "#c43cbc", "q": "#e070dc",  # когти
    "t": "#f4f2f6", "u": "#b04ab0",  # надпись
}
ART = [
    "...oooooooooo...",
    "..osSSSSSSSSso..",
    ".oSwwSSSSSSSSSo.",
    ".osSSSSSSSSSSso.",
    "..oeseeeeeeseo..",
    ".oekKkkkkkkkkeo.",
    ".oekKkkkkkkkkeo.",
    ".oekKkkkkkkkkeo.",
    ".oekKqkkqkkqkeo.",
    ".oekPPkPPkPPkeo.",
    ".oekPPkPPkPPkeo.",
    ".oekPPkPPkPPkeo.",
    ".oekPpkPPkpPkeo.",
    ".oekPpkPpkpPkeo.",
    ".oekPpkPpkpPkeo.",
    ".oekPkkPpkkPkeo.",
    ".oekPkkPpkkPkeo.",
    ".oekpkkPpkkpkeo.",
    ".oekpkkPkkkpkeo.",
    ".oekKkkPkkkkkeo.",
    ".oekKkkpkkkkkeo.",
    ".oekKkkpkkkkkeo.",
    ".oekKkkkkkkkkeo.",
    ".oektktkttkttko.",
    ".oekttkkktktkeo.",
    ".oektktkttkkteo.",
    ".oekKkkkkkkkkeo.",
    ".oekuuuuuuuuueo.",
    ".oekKkkkkkkkkeo.",
    ".oektkttktkkteo.",
    ".oekKkkkkkkkkeo.",
    "..oeseeeeeeseo..",
    "..osSSSSSSSSso..",
    "...oooooooooo...",
]
PX = 1.5


def main():
    w, h = len(ART[0]), len(ART)
    rects = []
    for y, row in enumerate(ART):
        for x, ch in enumerate(row):
            if ch != ".":
                rects.append('<rect x="%g" y="%g" width="%g" height="%g" fill="%s"/>' % (x * PX, y * PX, PX, PX, PAL[ch]))
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %g %g" shape-rendering="crispEdges">\n%s\n</svg>\n'
           % (round(w * PX), round(h * PX), w * PX, h * PX, "\n".join(rects)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write(svg)
    print("ok", w, h)


if __name__ == "__main__":
    main()
