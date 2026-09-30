"""Recorta las fuentes de emoji/símbolos a los caracteres que usa el proyecto.

Las fuentes completas (tools/fonts_source/) pesan ~12 MB y duplicaban el
tamaño del paquete web; recortadas quedan en ~1.4 MB. Si agregas un emoji o
símbolo nuevo a cualquier juego, vuelve a correr esto antes de exportar:

    py -m pip install fonttools
    py tools/subset_fonts.py

Toma todos los caracteres > U+2000 que aparecen en core/ y games/ (.gd y
.tscn) y además conserva bloques completos de símbolos útiles (flechas,
figuras, cartas, dominó, mahjong, ajedrez, dados) por si un juego los arma
en tiempo de ejecución.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools" / "fonts_source"
OUT = ROOT / "fonts"
FONTS = ["NotoColorEmoji", "NotoSansSymbols", "NotoSansSymbols2-Regular"]
EXTRA = ",".join([
    "U+2190-21FF", "U+2300-23FF", "U+25A0-25FF", "U+2600-26FF", "U+2700-27BF",
    "U+2B00-2BFF", "U+1F000-1F0FF", "U+2680-2685", "U+FE0F", "U+200D", "U+20E3",
    "U+0023", "U+002A", "U+0030-0039",
])


def used_chars() -> str:
    chars = set()
    for pattern in ("core/**/*.gd", "games/**/*.gd", "core/**/*.tscn", "games/**/*.tscn"):
        for path in ROOT.glob(pattern):
            chars.update(ch for ch in path.read_text(encoding="utf-8") if ord(ch) > 0x2000)
    return "".join(sorted(chars))


def main() -> None:
    text = used_chars()
    print(f"{len(text)} caracteres especiales en uso")
    for name in FONTS:
        subprocess.run([
            sys.executable, "-m", "fontTools.subset", str(SOURCE / f"{name}.ttf"),
            f"--text={text}", f"--unicodes={EXTRA}", "--layout-features=*",
            f"--output-file={OUT / f'{name}.ttf'}",
        ], check=True)
        print(f"  {name}: {(OUT / f'{name}.ttf').stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
