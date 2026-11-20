#!/usr/bin/env python3
"""Generuje hudbu ostrovů a smyčky bytostí přes audio službu AiStack (SPARK).

    sparkctl exec doggiowars audio-music 60 20 "DoggioWars biome themes" \\
        -- python3 tools/gen_audio.py music
    sparkctl exec doggiowars audio-sfx 40 20 "DoggioWars creature loops" \\
        -- python3 tools/gen_audio.py sfx
    sparkctl exec doggiowars audio-sfx 30 20 "DoggioWars shots and impacts" \\
        -- python3 tools/gen_audio.py oneshot

    python3 tools/gen_audio.py music --only glacial volcanic   # jen některé
    python3 tools/gen_audio.py pick glacial 2                  # vzít variantu 2

Adresa služby je jen v LAN, proto se bere z prostředí nebo z .env v kořeni
repa (DOGGIO_AUDIO_URL=http://...:8093), nikdy ne z kódu.

Surové výstupy (všechny varianty, plná kvalita) padají do build/audio/
(gitignore). Do hry jde varianta 0, přeenkódovaná na Vorbis q3, ať balík
na ContentDB nenaroste; jinou variantu nasadí `pick`. Už stažené se
přeskakují, takže skript jde po přerušení pustit znovu.

Modely: ACE-Step 1.5 (MIT) pro hudbu, MOSS-SoundEffect v2.0 (Apache-2.0)
pro zvuky. Smyčky hudby skládá server (loop:true); zvuky smyčku nemají,
tak je stejnou technikou (prolnutí konce přes začátek) skládá loopify().
"""

import argparse
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "build" / "audio"
SOUNDS = ROOT / "mods" / "dw_core" / "sounds"

MUSIC_MODEL = "acestep-v15-turbo"
SFX_MODEL = "moss-soundeffect-v2"

MUSIC_LEN = 92      # s; loop:true ubere 2 s na prolnutí
MUSIC_VARIATIONS = 3
SFX_LEN = 30        # s; strop modelu
SFX_VARIATIONS = 2
SFX_XFADE = 2.0     # s prolnutí ve smyčce bytosti
SEED_BASE = 4200

# Společný konec promptu — bez úvodu a závěru, jinak smyčka zadrhne
MUSIC_SUFFIX = (", instrumental, seamless loop, steady tempo, no intro, "
                "no ending, no fade out")
SFX_SUFFIX = ", continuous, ambient loop, no silence, no music"

# Biomy drží podobné tempo, ať crossfade mezi ostrovy nedrhne
THEMES = {
    "sky": ("airy ambient, soft synth pads, distant flute, light wind, "
            "floating, peaceful, wide reverb", 80, "D major"),
    "verdant": ("pastoral orchestral, acoustic guitar, flute, light strings, "
                "birdsong-like woodwinds, warm, hopeful", 84, "G major"),
    "glacial": ("ambient orchestral, celesta, glass harmonica, soft strings, "
                "cold airy pads, slow, wide reverb", 72, "E minor"),
    "volcanic": ("dark cinematic, low brass, taiko, distorted cello ostinato, "
                 "rumbling, tense", 90, "D minor"),
    "atoll": ("tropical ambient, marimba, steel drum, soft pads, ocean "
              "shimmer, relaxed, sunny", 84, "A major"),
    "mycelial": ("mystical ambient, kalimba, music box, deep drones, "
                 "glowing bioluminescent mood, dreamy, mysterious", 76, "F# minor"),
    "barren": ("sparse ambient, solo duduk, low drones, stone percussion, "
               "desolate, ancient, vast", 72, "D minor"),
    "jungle": ("tribal ambient, hand drums, wooden flutes, marimba, dense "
               "humid atmosphere, lively, adventurous", 92, "A minor"),
    "desert": ("middle eastern ambient, oud, frame drum, low drone, "
               "shimmering heat, sparse, wandering", 84, "D phrygian"),
    "crystal": ("electronic ambient, glassy arpeggiated synths, chimes, "
                "electric shimmer, sparkling, energetic", 96, "B minor"),
    "ashen": ("post-apocalyptic ambient, bowed metal, low cello, crackling "
              "texture, melancholic, smoky, slow", 70, "C minor"),
    "savanna": ("african savanna ambient, kalimba, shaker, warm bass, soft "
                "hand percussion, golden hour, calm", 88, "F major"),
    "swamp": ("swamp ambient, murky bass clarinet, slide guitar, low drones, "
              "croaking textures, humid, eerie", 74, "E minor"),
}

CREATURES = {
    "dragon_fire": "large fire dragon breathing slowly, deep crackling flames, low growl",
    "dragon_ice": "ice dragon breathing frost, crystalline crackling ice, cold wind, low hum",
    "dragon_water": "water dragon gliding, flowing water, bubbling, deep watery hum",
    "dragon_mud": "mud dragon, thick bubbling mud, wet slithering, low rumbling growl",
    "dragon_electric": "electric dragon, crackling electricity, buzzing arcs, humming energy",
    "worm": "giant sand worm burrowing, shifting sand, deep earth rumble",
    "guardian": "ancient stone golem humming, low resonant stone drone, grinding rock",
    "jelly": "floating jellyfish, soft airy bubbling, gentle wet pulses, calm",
    "jelly_glow": "glowing magical jellyfish, soft shimmering chimes, airy hum",
    "whale": "giant sky whale, deep slow whale song, low rumbling, vast and calm",
}


# Krátké zvuky: (prompt, délka s). Luanti vybírá náhodně z variant
# jméno.1.ogg … jméno.N.ogg, takže každá rána zní trochu jinak.
ONESHOT_VARIATIONS = 3
ONESHOTS = {
    "dw_shot": ("single short laser cannon shot from a fighter plane, punchy "
                "zap with a quick tail", 1),
    "dw_impact_stone": ("explosion blasting into solid rock, cracking stone, "
                        "rubble and pebbles falling", 3),
    "dw_impact_sand": ("explosion into loose sand, whooshing sand burst, "
                       "grains raining down", 3),
    "dw_impact_dirt": ("explosion into soft earth, thick dirt thud, clods of "
                       "soil falling", 3),
    "dw_impact_wood": ("explosion splintering wood, tree trunk cracking and "
                       "snapping, splinters", 3),
    "dw_impact_leaves": ("blast tearing through foliage, leaves rustling and "
                         "branches whipping, soft burst", 2),
    "dw_impact_ice": ("explosion shattering ice, sharp crystalline cracking, "
                      "ice shards tinkling", 3),
    "dw_impact_crystal": ("magic crystal shattering, glassy ringing burst, "
                          "sparkling shards", 3),
    "dw_impact_magma": ("explosion into molten lava, fiery whoosh, hissing "
                        "bubbling magma, sizzle", 3),
    "dw_impact_metal": ("bullet hitting a metal aircraft hull, sharp metallic "
                        "clang, small explosion", 2),
    "dw_impact_crash": ("fighter plane crashing and exploding, big fiery "
                        "explosion, metal debris, deep boom", 4),
    "dw_impact_generic": ("short explosion, deep punchy boom with debris", 2),
}
ONESHOT_SUFFIX = ", single sound effect, no music"


def audio_url():
    url = os.environ.get("DOGGIO_AUDIO_URL")
    env = ROOT / ".env"
    if not url and env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("DOGGIO_AUDIO_URL="):
                url = line.split("=", 1)[1].strip().strip('"')
    if not url:
        sys.exit("DOGGIO_AUDIO_URL chybí (prostředí nebo .env v kořeni repa)")
    return url.rstrip("/")


def http(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def wait_ready(base, model, timeout=600):
    """Model naběhne až po startu lease; chvíli počkat, než se načte."""
    t0 = time.time()
    while True:
        models = http("GET", f"{base}/v1/audio/models")
        m = next((m for m in models if m["name"] == model), None)
        if m and m.get("available"):
            return
        if time.time() - t0 > timeout:
            sys.exit(f"{model} nedostupný: {m and m.get('detail')} "
                     "(spouštěj přes sparkctl exec, viz hlavička)")
        time.sleep(10)


def run_job(base, endpoint, body):
    job = http("POST", f"{base}/v1/audio/{endpoint}", body)
    jid = job["job_id"]
    while job.get("status") not in ("done", "error"):
        time.sleep(5)
        job = http("GET", f"{base}/v1/audio/jobs/{jid}")
    if job["status"] == "error" or not job.get("outputs"):
        raise RuntimeError(job.get("error") or "no outputs")
    return job["outputs"]


def download(base, url, dest):
    full = url if url.startswith("http") else base + url
    dest.write_bytes(urllib.request.urlopen(full, timeout=180).read())


def duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(path)],
        capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-y", "-v", "error", *args], check=True)


def to_vorbis(ffmpeg_args, dest, mono=False):
    """ffmpeg upraví zvuk do WAV, oggenc z něj udělá Vorbis q3.

    Homebrew ffmpeg nemá libvorbis a jeho vestavěný enkodér je pokusný
    a zní hůř — proto oggenc (brew install vorbis-tools).
    """
    tmp = dest.with_suffix(".tmp.wav")
    ffmpeg(*ffmpeg_args, *(["-ac", "1"] if mono else []),
           "-fflags", "+bitexact", "-c:a", "pcm_s16le", str(tmp))
    subprocess.run(["oggenc", "-Q", "-q", "3", "-o", str(dest), str(tmp)],
                   check=True)
    tmp.unlink()


def loopify(src, dest, xfade=SFX_XFADE):
    """Smyčka bez cvaknutí: konec se prolne přes začátek, za něj zbytek.

    [hlava 0..x s fade-in + konec D-x..D s fade-out] + tělo x..D-x.
    Konec těla navazuje na konec, ze kterého prolnutí začíná, a prolnutí
    končí čistou hlavou, která navazuje na tělo — šev nikde není.
    """
    d = duration(src)
    x = xfade
    graph = (
        f"[0]atrim=0:{x},asetpts=PTS-STARTPTS,afade=t=in:d={x}[h];"
        f"[0]atrim={d - x}:{d},asetpts=PTS-STARTPTS,afade=t=out:d={x}[t];"
        f"[h][t]amix=inputs=2:normalize=0[m];"
        f"[0]atrim={x}:{d - x},asetpts=PTS-STARTPTS[b];"
        f"[m][b]concat=n=2:v=0:a=1[o]"
    )
    to_vorbis(["-i", str(src), "-filter_complex", graph, "-map", "[o]"],
              dest, mono=True)


def trim_oneshot(src, dest):
    """Ořízne ticho na začátku i konci, krátký fade na konec, mono."""
    af = ("silenceremove=start_periods=1:start_threshold=-50dB,"
          "areverse,silenceremove=start_periods=1:start_threshold=-50dB,"
          "afade=t=in:d=0.12,areverse")
    to_vorbis(["-i", str(src), "-af", af], dest, mono=True)


def encode_music(src, dest):
    # stejná délka = bod smyčky zůstává, jen menší soubor
    to_vorbis(["-i", str(src)], dest)


def raw_path(kind, name, var):
    return RAW / kind / f"{name}.v{var}.ogg"


PICKS = RAW / "picks.json"


def load_picks():
    try:
        return json.loads(PICKS.read_text())
    except (OSError, ValueError):
        return {}


def install(kind, name, var):
    src = raw_path(kind, name, var)
    if not src.exists():
        sys.exit(f"chybí {src}")
    picks = load_picks()
    picks[name] = var
    PICKS.write_text(json.dumps(picks, indent=1, sort_keys=True))
    SOUNDS.mkdir(parents=True, exist_ok=True)
    if kind == "music":
        encode_music(src, SOUNDS / f"dw_music_{name}.ogg")
    else:
        loopify(src, SOUNDS / f"dw_creature_{name}.ogg")


def gen_music(base, only):
    wait_ready(base, MUSIC_MODEL)
    (RAW / "music").mkdir(parents=True, exist_ok=True)
    for k, (name, (prompt, bpm, key)) in enumerate(THEMES.items()):
        if only and name not in only:
            continue
        if raw_path("music", name, 0).exists():
            print(f"{name}: už je, přeskakuji")
            continue
        t = time.time()
        outs = run_job(base, "music", {
            "prompt": prompt + MUSIC_SUFFIX, "duration_s": MUSIC_LEN,
            "seed": SEED_BASE + k, "instrumental": True, "bpm": bpm,
            "key": key, "loop": True, "format": "ogg",
            "variations": MUSIC_VARIATIONS,
        })
        for i, o in enumerate(outs):
            download(base, o["url"], raw_path("music", name, i))
        install("music", name, 0)
        print(f"{name}: {len(outs)} variant, {time.time() - t:.0f} s")


def gen_oneshots(base, only):
    wait_ready(base, SFX_MODEL)
    (RAW / "oneshot").mkdir(parents=True, exist_ok=True)
    SOUNDS.mkdir(parents=True, exist_ok=True)
    for k, (name, (prompt, dur)) in enumerate(ONESHOTS.items()):
        if only and name not in only:
            continue
        if raw_path("oneshot", name, 0).exists():
            print(f"{name}: už je, přeskakuji")
            continue
        t = time.time()
        outs = run_job(base, "sfx", {
            "prompt": prompt + ONESHOT_SUFFIX, "duration_s": dur,
            "seed": SEED_BASE + 200 + k, "variations": ONESHOT_VARIATIONS,
            "mono": True, "format": "ogg",
        })
        for i, o in enumerate(outs):
            raw = raw_path("oneshot", name, i)
            download(base, o["url"], raw)
            trim_oneshot(raw, SOUNDS / f"{name}.{i + 1}.ogg")
        print(f"{name}: {len(outs)} variant, {time.time() - t:.0f} s")


def gen_sfx(base, only):
    wait_ready(base, SFX_MODEL)
    (RAW / "sfx").mkdir(parents=True, exist_ok=True)
    for k, (name, prompt) in enumerate(CREATURES.items()):
        if only and name not in only:
            continue
        if raw_path("sfx", name, 0).exists():
            print(f"{name}: už je, přeskakuji")
            continue
        t = time.time()
        outs = run_job(base, "sfx", {
            "prompt": prompt + SFX_SUFFIX, "duration_s": SFX_LEN,
            "seed": SEED_BASE + 100 + k, "variations": SFX_VARIATIONS,
            "mono": True, "format": "ogg",
        })
        for i, o in enumerate(outs):
            download(base, o["url"], raw_path("sfx", name, i))
        install("sfx", name, 0)
        print(f"{name}: {len(outs)} variant, {time.time() - t:.0f} s")


def listen():
    """Poslechová stránka build/audio/listen.html — všechny varianty
    vedle sebe, smyčky na loop, a co je teď nasazené ve hře."""
    import html
    rows = []
    sections = [
        ("Témata ostrovů", "music", list(THEMES), True,
         lambda n: SOUNDS / f"dw_music_{n}.ogg"),
        ("Bytosti (smyčky)", "sfx", list(CREATURES), True,
         lambda n: SOUNDS / f"dw_creature_{n}.ogg"),
        ("Výstřel a zásahy", "oneshot", list(ONESHOTS), False, None),
    ]
    for title, kind, names, loop, ingame in sections:
        rows.append(f"<h2>{title}</h2>")
        for n in names:
            vars_ = sorted((RAW / kind).glob(f"{n}.v*.ogg"))
            if not vars_:
                rows.append(f"<div class=row><b>{n}</b><span class=wait>"
                            "ještě se generuje</span></div>")
                continue
            cells = []
            if ingame and ingame(n).exists():
                cells.append(f"<div class=cell><i>ve hře</i><audio controls "
                             f"loop preload=none src='{ingame(n).as_uri()}'>"
                             "</audio></div>")
            if not ingame:
                for f in sorted(SOUNDS.glob(f"{n}.[0-9].ogg")):
                    cells.append(f"<div class=cell><i>ve hře {f.stem[-1]}</i>"
                                 f"<audio controls preload=none "
                                 f"src='{f.as_uri()}'></audio></div>")
            else:
                for f in vars_:
                    v = f.stem.rsplit(".v", 1)[1]
                    cells.append(
                        f"<div class=cell><i>varianta {v}</i><audio controls "
                        f"{'loop ' if loop else ''}preload=none "
                        f"src='{f.as_uri()}'></audio>"
                        f"<code>python3 tools/gen_audio.py pick {n} {v}</code>"
                        "</div>")
            rows.append(f"<div class=row><b>{html.escape(n)}</b>"
                        f"{''.join(cells)}</div>")
    page = f"""<!doctype html><meta charset=utf-8>
<title>DoggioWars zvuky</title>
<style>
body{{font:14px system-ui;margin:24px;background:#14161a;color:#e8e8e8}}
h2{{margin-top:32px;border-bottom:1px solid #333;padding-bottom:4px}}
.row{{display:flex;flex-wrap:wrap;gap:12px;align-items:center;
  padding:8px 0;border-bottom:1px solid #222}}
.row b{{width:140px}}
.cell{{display:flex;flex-direction:column;gap:2px}}
.cell i{{color:#9ab;font-size:12px}}
code{{font-size:11px;color:#8a8;user-select:all}}
.wait{{color:#776}}
</style>
<h1>DoggioWars — poslech</h1>
<p>Smyčky hrají dokola: poslouchej šev na konci. Příkaz pod variantou ji
nasadí do hry (klikni = označí celý). Stránka se obnoví příkazem
<code>python3 tools/gen_audio.py listen</code>.</p>
{''.join(rows)}"""
    out = RAW / "listen.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    subprocess.run(["open", "-a", "Google Chrome", str(out)])
    print(out)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    for c in ("music", "sfx", "oneshot"):
        p = sub.add_parser(c)
        p.add_argument("--only", nargs="*")
    sub.add_parser("listen", help="poslechová stránka v Chromu")
    p = sub.add_parser("pick", help="nasadit jinou variantu do hry")
    p.add_argument("name")
    p.add_argument("variant", type=int)
    args = ap.parse_args()

    for tool, pkg in (("ffmpeg", "ffmpeg"), ("ffprobe", "ffmpeg"),
                      ("oggenc", "vorbis-tools")):
        if shutil.which(tool) is None:
            sys.exit(f"chybí {tool} (brew install {pkg})")
    if args.cmd == "listen":
        listen()
        return
    if args.cmd == "pick":
        kind = "music" if args.name in THEMES else "sfx"
        install(kind, args.name, args.variant)
        print(f"{args.name}: nasazena varianta {args.variant}")
        return
    base = audio_url()
    if args.cmd == "music":
        gen_music(base, args.only)
    elif args.cmd == "oneshot":
        gen_oneshots(base, args.only)
    else:
        gen_sfx(base, args.only)


if __name__ == "__main__":
    main()
