"""Składa dźwięki gry z pobranych paczek CC0 (audio/_incoming) do audio/sfx/.

Każde zdarzenie (np. "roar") ma 2-3 kandydatów (a, b, c). Kandydat to kilka wersji
tego samego dźwięku (gra losuje jedną przy odtworzeniu). Wybór kandydata leży
w audio/sfx/picks.json, a odsłuchownia (tests/sound_board.tscn) pozwala go zmienić.

Obróbka: przycięcie ciszy, opcjonalnie najgłośniejsze okno / limit długości /
zmiana tempa (i wysokości), łagodne wyciszenie, normalizacja szczytu do -1 dBFS.
Tła (amb_*) zostają stereo, dostają przenikanie końca w początek (bezszwowa pętla)
i wyrównanie do wspólnej głośności RMS.

Użycie (z katalogu projektu): python tools/audio/build_sounds.py
Wymaga: ffmpeg w PATH, numpy.
"""
import glob, json, os, shutil, subprocess
import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INC = os.path.join(ROOT, "audio", "_incoming")
OUT = os.path.join(ROOT, "audio", "sfx")

K_IMP = "impact-sounds/Audio/"
K_INT = "interface-sounds/Audio/"
K_UI = "ui-audio/Audio/"
K_RPG = "rpg-audio/Audio/"
K_DIG = "digital-audio/Audio/"
K_SCI = "sci-fi-sounds/Audio/"
O = "oga/"


def c(note, *src, **opts):
    return {"note": note, "src": list(src), **opts}


# Zdarzenie -> kandydaci (pierwszy = mój faworyt, trafia do picks.json).
EVENTS = {
    # --- Farma ---
    "plant": [c("soft thud", K_IMP + "impactSoft_medium_00*"), c("wet soil", O + "mud/mud_0[568].ogg", O + "mud/mud_1[0-2].ogg", max=0.45),
              c("grass rustle", K_IMP + "footstep_grass_00*")],
    "harvest": [c("plop", O + "sfx100/plop_0*", O + "water/bubble_0*", max=0.5), c("pluck", K_INT + "pluck_00*"),
                c("wood item", O + "rpg/item_wood_0*")],
    "water": [c("pour", O + "water/loop_water_0[12].ogg", win=0.9, fade=0.25), c("splash small", O + "sfx100/splash_0*"),
              c("splash", O + "water/splash_0[2356].ogg")],
    "fill": [c("bubbles", O + "water/loop_bubbles_02.ogg", O + "water/loop_bubbles_1.ogg", win=0.8, fade=0.2),
             c("bubble", O + "water/bubble_0*"), c("stream", O + "sfx100b/sfx100v2_loop_water_0*", win=0.8, fade=0.2)],
    "craft": [c("tools", O + "sfx100/tools_0*"), c("metal clank", O + "rpg/metal_0*"), c("metal hit", K_IMP + "impactMetal_medium_00*")],
    "chime": [c("confirm", K_INT + "confirmation_00*"), c("bell", O + "sfx100/bell_0*", max=1.4, fade=0.5),
              c("three tone", K_DIG + "threeTone*", K_DIG + "twoTone*")],
    "land": [c("metal impact", K_SCI + "impactMetal_00*"), c("low boom", K_SCI + "lowFrequency_explosion_00*", max=1.6, fade=0.6),
             c("engine down", K_SCI + "spaceEngineLow_00*", win=1.4, fade=0.5)],
    # --- Gracz ---
    "step_grass": [c("grass", K_IMP + "footstep_grass_00*"), c("dirt steps", K_RPG + "footstep0*"),
                   c("soft steps", O + "sfx100b/sfx100v2_footstep_0*")],
    "step_soil": [c("dirt steps", K_RPG + "footstep0*"), c("carpet (soft)", K_IMP + "footstep_carpet_00*"),
                  c("wet", O + "sfx100b/sfx100v2_footstep_wet_0*")],
    "step_run": [c("grass loud", K_IMP + "footstep_grass_00*", speed=1.08), c("dirt fast", K_RPG + "footstep0*", speed=1.1),
                 c("snow crunch", K_IMP + "footstep_snow_00*")],
    "dash": [c("air whoosh", O + "sfx100b/sfx100v2_air_0[23].ogg", max=0.5, fade=0.2), c("phase jump", K_DIG + "phaseJump*"),
             c("blade swish", O + "rpg/blade_0*")],
    "hurt": [c("grunt", O + "creature2/human_0[1357].ogg"), c("punch", K_IMP + "impactPunch_heavy_00*"),
             c("creature hurt", O + "creature1/hurt_0[345].ogg")],
    "eat": [c("munch", O + "creature1/eat_0*"), c("slime", O + "water/slime_0[1-4].ogg", max=0.5), c("cloth", K_RPG + "cloth*")],
    "pickup": [c("gem", O + "rpg/item_gem_0[123].ogg"), c("leather", K_RPG + "handleSmallLeather*", K_RPG + "beltHandle*"),
               c("ui select", K_INT + "select_00[1-4].ogg")],
    "throw": [c("swish", O + "rpg/blade_0*"), c("air", O + "sfx100b/sfx100v2_air_0[23].ogg", max=0.5, fade=0.2),
              c("cloth", K_RPG + "cloth*")],
    "shot": [c("laser small", K_SCI + "laserSmall_00*"), c("laser retro", K_SCI + "laserRetro_00*"), c("zap laser", K_DIG + "laser[1-5].ogg")],
    "scan": [c("computer", K_SCI + "computerNoise_00*", win=0.8, fade=0.3), c("force field", K_SCI + "forceField_00*", max=1.0, fade=0.4),
             c("phaser up", K_DIG + "phaserUp*")],
    "flashlight": [c("switch", K_INT + "switch_00*"), c("toggle", K_INT + "toggle_00*"), c("metal click", K_RPG + "metalClick.ogg", K_RPG + "metalLatch.ogg")],
    # --- Interfejs ---
    "ui_click": [c("click", K_UI + "click[1-5].ogg"), c("interface click", K_INT + "click_00*"), c("select", K_INT + "select_00[1-4].ogg")],
    "ui_hover": [c("rollover", K_UI + "rollover*"), c("tick", K_INT + "tick_00*"), c("scroll", K_INT + "scroll_00*")],
    "deny": [c("error", K_INT + "error_00[1-4].ogg"), c("back", K_INT + "back_00*"), c("glitch", K_INT + "glitch_00*")],
    # --- Stworzenia ---
    "roar": [c("roar", O + "creature2/roar_0*", O + "creature1/roar_02.ogg"), c("deep roar", O + "roar/monster_roar.wav", win=1.6, fade=0.5),
             c("snarl", O + "snarls/monster-snarls_0.ogg", O + "snarls/monster-snarls-2_0.ogg", win=1.4, fade=0.4)],
    "bite": [c("attack", O + "creature2/attack_0[135].ogg"), c("snarl attack", O + "snarls/monster-snarl-attack.ogg", win=0.6, fade=0.2),
             c("wood snap", K_IMP + "impactWood_heavy_00*")],
    "stun": [c("force field", K_SCI + "forceField_00*", max=0.9, fade=0.4), c("phaser down", K_DIG + "phaserDown*"),
             c("weird", O + "creature1/weird_0[1-3].ogg", max=0.9, fade=0.3)],
    "death": [c("die", O + "creature2/die_0*"), c("rpg die", O + "rpg/creature_die_01.ogg", O + "rpg/creature_hurt_0*"),
              c("hurt", O + "creature1/hurt_0[12].ogg")],
    "snap": [c("jaws", O + "creature2/attack_0[15].ogg", K_IMP + "impactWood_light_00[0-2].ogg"), c("wood", K_IMP + "impactWood_medium_00*"),
             c("plank", K_IMP + "impactPlank_medium_00*")],
    # --- Wyprawa i baza ---
    "boom": [c("explosion", K_SCI + "explosionCrunch_00*"), c("low explosion", K_SCI + "lowFrequency_explosion_00*", max=1.8, fade=0.6),
             c("big", O + "sfx100/explosion.ogg", max=2.0, fade=0.6)],
    "alarm": [c("alarm 1", O + "loops/alarm_01.ogg", max=1.6, fade=0.3), c("alarm 3", O + "loops/alarm_03.ogg"),
              c("alarm 2", O + "loops/alarm_02.ogg")],
    "evac": [c("thruster", K_SCI + "thrusterFire_00[0-2].ogg", win=1.6, fade=0.6), c("power up", K_DIG + "powerUp*"),
             c("engine", K_SCI + "spaceEngineLarge_00*", win=1.6, fade=0.6)],
    # --- Tła (pętle, stereo) ---
    "amb_valley_day": [c("forest birds", O + "ambience/Forest_Ambience.mp3", loop=True),
                       c("birds and wind", O + "ambience/Birds_and_Wind_Ambient.ogg", loop=True),
                       c("alien birds", O + "ambience/Forest_Ambience.mp3", loop=True, speed=1.18)],
    "amb_valley_night": [c("crickets", O + "crickets/crickets_1.mp3", loop=True),
                         c("deep crickets", O + "crickets/crickets_1.mp3", loop=True, speed=0.8)],
    "amb_meadow_day": [c("alien birds", O + "ambience/Forest_Ambience.mp3", loop=True, speed=1.18),
                       c("forest birds", O + "ambience/Forest_Ambience.mp3", loop=True),
                       c("birds and wind", O + "ambience/Birds_and_Wind_Ambient.ogg", loop=True)],
    "amb_meadow_night": [c("deep crickets", O + "crickets/crickets_1.mp3", loop=True, speed=0.8),
                         c("crickets", O + "crickets/crickets_1.mp3", loop=True),
                         c("slow alien", O + "crickets/crickets_1.mp3", loop=True, speed=0.62)],
}


def decode(path, channels, speed=1.0):
    af = f"asetrate={int(SR * speed)},aresample={SR}" if speed != 1.0 else f"aresample={SR}"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-af", af, "-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).copy()


def encode(x, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", path], input=x.astype(np.float32).tobytes(), check=True)


def trim_silence(x, rel_db=-45.0):
    env = np.max(np.abs(x), axis=1)
    thr = env.max() * 10 ** (rel_db / 20)
    idx = np.nonzero(env > thr)[0]
    if len(idx) == 0:
        return x
    return x[max(idx[0] - int(0.003 * SR), 0): idx[-1] + int(0.02 * SR)]


def loudest_window(x, seconds):
    n = int(seconds * SR)
    if len(x) <= n:
        return x
    energy = np.cumsum(np.concatenate([[0.0], np.mean(x ** 2, axis=1)]))
    sums = energy[n:] - energy[:-n]
    start = int(np.argmax(sums))
    # Zacznij od lokalnej ciszy tuż przed oknem, żeby nie uciąć ataku.
    return x[start: start + n]


def fades(x, fade_in=0.004, fade_out=0.03):
    x = x.copy()
    fi, fo = min(int(fade_in * SR), len(x) // 2), min(int(fade_out * SR), len(x) // 2)
    if fi:
        x[:fi] *= np.linspace(0, 1, fi)[:, None]
    if fo:
        x[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 2
    return x


def loop_crossfade(x, seconds=1.0):
    n = min(int(seconds * SR), len(x) // 4)
    y = x[:-n].copy()
    t = np.linspace(0, 1, n)[:, None]
    y[:n] = x[:n] * np.sqrt(t) + x[-n:] * np.sqrt(1 - t)
    return y


def process(path, opt):
    loop = opt.get("loop", False)
    x = decode(path, 2 if loop else 1, opt.get("speed", 1.0))
    if loop:
        x = loop_crossfade(x)
        rms = np.sqrt(np.mean(x ** 2))
        x = x * (10 ** (-24 / 20) / max(rms, 1e-9))
        peak = np.max(np.abs(x))
        if peak > 0.89:
            x = x * (0.89 / peak)
        return x
    x = trim_silence(x)
    if "win" in opt:
        x = loudest_window(x, opt["win"])
    if "max" in opt and len(x) > opt["max"] * SR:
        x = x[: int(opt["max"] * SR)]
    x = fades(x, fade_out=opt.get("fade", 0.03))
    peak = np.max(np.abs(x))
    return x * (10 ** (-1 / 20) / max(peak, 1e-9))


def main():
    manifest = {}
    if os.path.isdir(OUT):
        for name in os.listdir(OUT):
            if os.path.isdir(os.path.join(OUT, name)):
                shutil.rmtree(os.path.join(OUT, name))
    for event, cands in EVENTS.items():
        manifest[event] = {}
        for letter, cand in zip("abc", cands):
            files = []
            for pattern in cand["src"]:
                files += sorted(glob.glob(os.path.join(INC, pattern)))
            files = list(dict.fromkeys(files))[:6]
            if not files:
                raise SystemExit(f"brak plików: {event}/{letter} {cand['src']}")
            for i, f in enumerate(files):
                encode(process(f, cand), os.path.join(OUT, event, letter, f"{i + 1:02d}.ogg"))
            manifest[event][letter] = {"note": cand["note"], "sources": [os.path.relpath(f, INC).replace("\\", "/") for f in files]}
            print(f"{event}/{letter}: {len(files)} plik(ów) [{cand['note']}]")
    with open(os.path.join(OUT, "candidates.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
    picks_path = os.path.join(OUT, "picks.json")
    picks = {}
    if os.path.exists(picks_path):
        picks = json.load(open(picks_path, encoding="utf-8"))
    picks = {e: picks.get(e, "a") if picks.get(e, "a") in manifest[e] else "a" for e in EVENTS}
    with open(picks_path, "w", encoding="utf-8") as fh:
        json.dump(picks, fh, indent=1)


if __name__ == "__main__":
    main()
