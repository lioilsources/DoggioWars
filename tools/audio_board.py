#!/usr/bin/env python3
"""Poslechová stránka všech vygenerovaných zvuků (artefakt / prohlížeč).

    python3 tools/audio_board.py        # → build/audio/board/index.html + soubory

Složí build/audio/board/: stránku z tools/audio_board.html a vedle ní
zvuky v herní kvalitě (Vorbis q3) — hudební varianty přeenkódované, varianty
bytostí složené do smyčky stejně jako ve hře, zásahy zkopírované ze hry.
Hotové soubory se nepřepočítávají, takže opakované spuštění je rychlé.
"""

import datetime
import json
import shutil
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))
import gen_audio as g  # noqa: E402

BOARD = g.RAW / "board"
TEMPLATE = g.ROOT / "tools" / "audio_board.html"

# Popisky a barva pruhu = barva země biomu (ladí s texturami ostrovů)
BIOMES = {
    "sky": ("Obloha", "#8fb8de"),
    "verdant": ("Verdant", "#5aa64a"),
    "glacial": ("Ledovec", "#bfe3f2"),
    "volcanic": ("Sopka", "#d9572b"),
    "atoll": ("Atol", "#3cc2c0"),
    "mycelial": ("Podhoubí", "#a477d6"),
    "barren": ("Pustina", "#8c8478"),
    "jungle": ("Džungle", "#2f7d3a"),
    "desert": ("Poušť", "#e0bf74"),
    "crystal": ("Krystal", "#f2dc4a"),
    "ashen": ("Popel", "#5d5a58"),
    "savanna": ("Savana", "#c9a04a"),
    "swamp": ("Bažina", "#6f6a3a"),
}
CREATURES = {
    "dragon_fire": ("Ohnivý drak", "#e0512e"),
    "dragon_ice": ("Ledový drak", "#bfe6ff"),
    "dragon_water": ("Vodní drak", "#35c8c0"),
    "dragon_mud": ("Bahenní drak", "#8a6a3a"),
    "dragon_electric": ("Elektrický drak", "#ffe94a"),
    "worm": ("Písečný červ", "#d8c07a"),
    "guardian": ("Kamenný strážce", "#5b5f66"),
    "jelly": ("Medúza", "#7fc4e8"),
    "jelly_glow": ("Svítící medúza", "#d8a8ff"),
    "whale": ("Nebeská velryba", "#8fa6ba"),
}
HITS = {
    "dw_shot": ("Výstřel", "#f0b24c", "každá rána z kanonu"),
    "dw_impact_stone": ("Kámen", "#8c8478", "zásah do skály, kamene, čediče"),
    "dw_impact_sand": ("Písek", "#e0bf74", "písek, štěrk, popel"),
    "dw_impact_dirt": ("Hlína", "#7a5634", "hlína, tráva, bahno, spóry"),
    "dw_impact_wood": ("Dřevo", "#9a6a3a", "kmeny stromů"),
    "dw_impact_leaves": ("Listí", "#5aa64a", "koruny stromů, keře"),
    "dw_impact_ice": ("Led", "#bfe3f2", "led, sníh, permafrost"),
    "dw_impact_crystal": ("Krystal", "#f2dc4a", "svítící krystaly, sklo"),
    "dw_impact_magma": ("Magma", "#d9572b", "magma, žhavé uhlíky"),
    "dw_impact_metal": ("Kov", "#9aa7b4", "zásah jiné stíhačky"),
    "dw_impact_crash": ("Havárie", "#c0392b", "zničená stíhačka"),
    "dw_impact_generic": ("Obecný", "#93a2b2", "kdyby nic jiného nesedělo"),
}


def fresh(dest, src):
    return dest.exists() and dest.stat().st_mtime >= src.stat().st_mtime


def build():
    BOARD.mkdir(parents=True, exist_ok=True)
    picks = g.load_picks()
    data = {"music": [], "creatures": [], "hits": [],
            "built": datetime.datetime.now().strftime("%d. %m. %Y %H:%M")}

    for name, (prompt, bpm, key) in g.THEMES.items():
        label, color = BIOMES[name]
        variants = []
        for src in sorted((g.RAW / "music").glob(f"{name}.v*.ogg")):
            rel = f"music/{src.name}"
            dest = BOARD / rel
            dest.parent.mkdir(exist_ok=True)
            if not fresh(dest, src):
                g.encode_music(src, dest)
            variants.append(rel)
        data["music"].append({"name": name, "label": label, "color": color,
                              "prompt": prompt, "bpm": bpm, "key": key,
                              "variants": variants, "pick": picks.get(name, 0)})

    for name, prompt in g.CREATURES.items():
        label, color = CREATURES[name]
        variants = []
        for src in sorted((g.RAW / "sfx").glob(f"{name}.v*.ogg")):
            rel = f"creatures/{src.name}"
            dest = BOARD / rel
            dest.parent.mkdir(exist_ok=True)
            if not fresh(dest, src):
                g.loopify(src, dest)
            variants.append(rel)
        data["creatures"].append({"name": name, "label": label, "color": color,
                                  "prompt": prompt, "variants": variants,
                                  "pick": picks.get(name, 0)})

    for name in g.ONESHOTS:
        label, color, when = HITS[name]
        variants = []
        for src in sorted(g.SOUNDS.glob(f"{name}.[0-9].ogg")):
            rel = f"hits/{src.name}"
            dest = BOARD / rel
            dest.parent.mkdir(exist_ok=True)
            if not fresh(dest, src):
                shutil.copy2(src, dest)
            variants.append(rel)
        data["hits"].append({"name": name, "label": label, "color": color,
                             "when": when, "variants": variants})

    page = TEMPLATE.read_text().replace(
        "/*DATA*/null", json.dumps(data, ensure_ascii=False))
    (BOARD / "index.html").write_text(page)
    files = sorted(str(p.relative_to(BOARD)) for p in BOARD.rglob("*.ogg"))
    (BOARD / "files.json").write_text(json.dumps(files))
    size = sum((BOARD / f).stat().st_size for f in files)
    print(f"{BOARD / 'index.html'}  ({len(files)} souborů, {size / 1e6:.1f} MB)")


if __name__ == "__main__":
    build()
