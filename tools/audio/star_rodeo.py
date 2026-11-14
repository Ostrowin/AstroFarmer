"""„Star Rodeo”: epicka orkiestra spotyka country. Utwór do Astro Farmera.

Kompozycja jest zapisana w tym pliku (nuty w beatach), a skrypt składa z niej
sesję SoundCraft: każdy instrument to kilka ścieżek-stref samplera (jedna
próbka VSCO 2 CE na zakres klawiszy), klipy MIDI z nutami, pogłos na szynie,
limiter na sumie. Na koniec SoundCraft zgrywa miks (bounce) do WAV, a ffmpeg
robi z niego OGG do gry.

G-dur, 108 BPM, 4/4, ok. 80 s:
  Intro  (t. 1-8)   G-Em-C-Am-D: wiolonczele, harfa, róg gra wołanie „przez prerię”, kotły narastają
  A      (t. 9-16)  skrzypce ludowe (fiddle) i „boom-chick” pizzicato, werbel, tamburyn
  B      (t. 17-24) tutti: smyczki śpiewają temat, róg w harmonii, trąbki, puzony, tuba, kotły
  A'     (t. 25-32) fiddle wraca na tle całej orkiestry
  Koda   (t. 33-35) wielki akord G, potem fiddle sam: „shave and a haircut... two bits!”

Użycie: python tools/audio/star_rodeo.py   (wymaga: SoundCraft CLI, ffmpeg, numpy,
biblioteki VSCO-2-CE w D:/Audio/VSCO-2-CE). Sesja SoundCraft z nutami zostaje w
D:/Audio/Sessions/StarRodeo/star_rodeo.scraft (można ją otworzyć i edytować w oknie).
"""
import glob, json, os, random, re, subprocess, sys
import numpy as np

VSCO = "D:/Audio/VSCO-2-CE/"
SC = "D:/Programy/Craft/SoundCraft/soundcraft-cli.exe"
WORK = "D:/Audio/Sessions/StarRodeo/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "star_rodeo.ogg")
BPM = 108
PPQ = 960
END_BEAT = 148  # z ogonem pogłosu

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name):
    m = re.fullmatch(r"([A-G][#b]?)(-?\d)", name)
    return NOTE[m.group(1)] + 12 * (int(m.group(2)) + 1)


# --- Instrumenty --------------------------------------------------------------
# glob: próbki; tryb: gate (trzyma, póki trwa nuta) / one (gra do końca próbki).
# pitched=False: perkusja (jedna próbka na jedną nutę MIDI, bez strojenia).
INSTRUMENTS = {
    "fiddle":    dict(glob="Strings/Solo Violin/Arco Vib/*_f.wav", mode="gate", attack=12, release=260, db=-3, pan=0.12, send=-11),
    "vln":       dict(glob="Strings/Violin Section/susVib/*_v2.wav", mode="gate", attack=90, release=700, db=3, pan=-0.45, send=-6),
    "vla":       dict(glob="Strings/Viola Section/susVib/*_v2*.wav", mode="gate", attack=90, release=700, db=-12, pan=-0.15, send=-7, optional=True),
    "cello":     dict(glob="Strings/Cello Section/susvib/*_v3_1.wav", mode="gate", attack=60, release=600, db=-11, pan=0.35, send=-8),
    "cello_pz":  dict(glob="Strings/Cello Section/pizzT/*_v2_RR1.wav", mode="one", attack=1, release=300, db=-2, pan=0.3, send=-13),
    "vln_pz":    dict(glob="Strings/Violin Section/Pizz/*_v2_rr1.wav", mode="one", attack=1, release=250, db=-8, pan=-0.3, send=-11),
    "bass_pz":   dict(glob="Strings/Solo Contrabass/Pizz/*.wav", mode="one", attack=1, release=300, db=-6, pan=0.15, send=-14, optional=True, pick=r"_f_|_mf_|RR1"),
    "harp":      dict(glob="Strings/Harp/*_mf.wav", mode="one", attack=1, release=900, db=2, pan=-0.6, send=-5),
    "horn":      dict(glob="Brass/F Horn/sus/*.wav", mode="gate", attack=50, release=500, db=4, pan=-0.1, send=-6, pick=r"_f|_mf|ff|v3|v2"),
    "trumpet":   dict(glob="Brass/Trumpet/sus/*.wav", mode="gate", attack=25, release=350, db=-1, pan=0.2, send=-8, optional=True, pick=r"_f|ff|v2|mf"),
    "trombone":  dict(glob="Brass/Tenor Trombone/sus/*.wav", mode="gate", attack=40, release=450, db=2, pan=0.4, send=-8, optional=True, pick=r"_f|ff|v2|mf"),
    "tuba":      dict(glob="Brass/Tuba/sus/*.wav", mode="gate", attack=40, release=450, db=3, pan=0.1, send=-10, optional=True, pick=r"_f|ff|v2|mf"),
    "timp":      dict(glob="Percussion/Timpani/Timpani*_Hit_v3_rr1*.wav", mode="one", attack=1, release=1500, db=1, pan=0.0, send=-7),
    "kick":      dict(glob="Percussion/BDrumNewhit*.wav", mode="one", pitched=False, note=36, attack=1, release=600, db=0, pan=0.0, send=-12),
    "snare":     dict(glob="Percussion/Snare2-HitSN*.wav", mode="one", pitched=False, note=38, attack=1, release=300, db=-4, pan=0.05, send=-10),
    "crash":     dict(glob="Percussion/cymbal-crash*.wav", mode="one", pitched=False, note=49, attack=1, release=2500, db=-9, pan=-0.2, send=-9),
    "tamb":      dict(glob="Percussion/Tamb1-Hit*.wav", mode="one", pitched=False, note=54, attack=1, release=300, db=-11, pan=0.35, send=-12),
}

# --- Harmonia -----------------------------------------------------------------
INTRO = ["G", "G", "Em", "Em", "C", "Am", "D", "D"]
A_CH = ["G", "G", "C", "G", "G", "Em", "D", "D/G"]
B_CH = ["Em", "C", "G", "D", "Em", "C", "D", "D"]
TRIAD = {"G": [55, 59, 62], "Em": [52, 55, 59], "C": [48, 52, 55], "D": [50, 54, 57], "Am": [57, 60, 64]}
BASS = {"G": (43, 38), "C": (48, 43), "Em": (40, 47), "D": (50, 45), "Am": (45, 52)}  # (pryma, kwinta) dla wiolonczel
ROOT_LOW = {"G": 31, "C": 36, "Em": 40, "D": 38}  # tuba

# Temat A (fiddle): takt -> [(nuta, start, długość)] w beatach.
A_MEL = [
    [("D5", 0, .5), ("B4", .5, .5), ("G4", 1, .5), ("B4", 1.5, .5), ("D5", 2, 1), ("B4", 3, .5), ("D5", 3.5, .5)],
    [("G5", 0, 1.5), ("F#5", 1.5, .5), ("E5", 2, .5), ("D5", 2.5, .5), ("B4", 3, 1)],
    [("C5", 0, .5), ("E5", .5, .5), ("G5", 1, 1), ("E5", 2, .5), ("C5", 2.5, .5), ("E5", 3, .5), ("G5", 3.5, .5)],
    [("D5", 0, 1.5), ("B4", 1.5, .5), ("G4", 2, 1), ("A4", 3, .5), ("B4", 3.5, .5)],
    [("D5", 0, .5), ("G5", .5, .5), ("D5", 1, .5), ("B4", 1.5, .5), ("D5", 2, .5), ("G5", 2.5, .5), ("B5", 3, 1)],
    [("G5", 0, .5), ("E5", .5, .5), ("B4", 1, 1), ("E5", 2, .5), ("F#5", 2.5, .5), ("G5", 3, 1)],
    [("F#5", 0, .5), ("E5", .5, .5), ("D5", 1, .5), ("A4", 1.5, .5), ("D5", 2, .5), ("F#5", 2.5, .5), ("A5", 3, 1)],
    [("G5", 0, .5), ("F#5", .5, .5), ("E5", 1, .5), ("F#5", 1.5, .5), ("G5", 2, 2)],
]
# Temat B (epicki, szeroki).
B_MEL = [
    [("B4", 0, 2), ("E5", 2, 1), ("G5", 3, 1)],
    [("G5", 0, 1.5), ("E5", 1.5, .5), ("C5", 2, 2)],
    [("D5", 0, 1), ("G5", 1, 1), ("B5", 2, 1.5), ("A5", 3.5, .5)],
    [("A5", 0, 3), ("F#5", 3, 1)],
    [("B5", 0, 2), ("G5", 2, 1), ("E5", 3, 1)],
    [("E5", 0, 1), ("G5", 1, 1), ("C6", 2, 2)],
    [("B5", 0, 1), ("A5", 1, 1), ("F#5", 2, 1), ("D5", 3, 1)],
    [("A5", 0, 4)],
]
B_HORN = [[("G4", 0, 2), ("B4", 2, 2)], [("G4", 0, 2), ("E4", 2, 2)], [("G4", 0, 2), ("D5", 2, 2)], [("F#4", 0, 4)],
          [("G4", 0, 2), ("B4", 2, 2)], [("E4", 0, 2), ("G4", 2, 2)], [("G4", 0, 2), ("F#4", 2, 2)], [("F#4", 0, 4)]]
HORN_CALL = {2: [("D4", 0, 1), ("G4", 1, 1.5), ("A4", 2.5, .5), ("B4", 3, 1)], 3: [("B4", 0, 3), ("A4", 3, 1)],
             4: [("G4", 0, 1), ("C5", 1, 2), ("B4", 3, 1)], 5: [("A4", 0, 4)],
             6: [("D4", 0, 1), ("G4", 1, 1), ("A4", 2, 1), ("D5", 3, 1)], 7: [("D5", 0, 3)]}
A2_HORN = ["B4", "G4", "E4", "D4", "B4", "B4", "A4", "A4"]

rng = random.Random(7)
notes = {name: [] for name in INSTRUMENTS}  # instrument -> [(pitch, start_beat, dur_beats, vel)]


def add(inst, pitch, start, dur, vel, human=True):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    if human:
        start += rng.uniform(-0.012, 0.012)
        vel += rng.randint(-5, 5)
    notes[inst].append((pitch, max(start, 0.0), dur, int(max(20, min(127, vel)))))


def fix_overlaps():
    """Ta sama wysokość na tym samym instrumencie nie może nachodzić na siebie:
    wyłączenie starszej nuty ucięłoby nową (sampler gasi głos po wysokości)."""
    for inst, lst in notes.items():
        lst.sort(key=lambda n: (n[0], n[1]))
        for i in range(len(lst) - 1):
            p, s, d, v = lst[i]
            if lst[i + 1][0] == p and s + d > lst[i + 1][1] - 0.03:
                lst[i] = (p, s, max(0.05, lst[i + 1][1] - s - 0.03), v)


def chord_of(name, half):
    if name == "D/G":
        return "D" if half == 0 else "G"
    return name


def harp_arp(bar, ch, vel=62, up=0):
    t = TRIAD[ch]
    pattern = [t[0] - 12, t[2] - 12, t[0], t[1], t[2], t[1], t[0], t[2] - 12]
    for i, p in enumerate(pattern):
        add("harp", p + up, bar * 4 + i * 0.5, 0.5, vel + (8 if i == 0 else 0))


def boom_chick(bar, chname, vel=1.0):
    for half in (0, 1):
        ch = chord_of(chname, half)
        root, fifth = BASS[ch]
        add("cello_pz", root if half == 0 else fifth, bar * 4 + half * 2, 1, 96 * vel)
        if half == 0:
            add("bass_pz", root - 12, bar * 4, 1, 90 * vel)
        for p in TRIAD[ch]:
            add("vln_pz", p + 12, bar * 4 + half * 2 + 1, 0.5, 72 * vel)


def drums(bar, fill=False, tamb=True):
    b = bar * 4
    add("kick", 36, b, 1, 92)
    add("kick", 36, b + 2, 1, 84)
    add("snare", 38, b + 1, 1, 78)
    add("snare", 38, b + 3, 1, 82)
    if tamb:
        for k in range(4):
            add("tamb", 54, b + k + 0.5, 0.5, 58)
    if fill:
        for k in range(8):
            add("snare", 38, b + 2 + k * 0.25, 0.25, 55 + k * 8)


def melody(inst, bar, line, vel, transpose=0):
    for name, s, d in line:
        accent = 10 if s in (0, 2) else 0
        add(inst, midi(name) + transpose, bar * 4 + s, d * 0.95, vel + accent)


def compose():
    # Intro: wiolonczele, smyczki, harfa, róg; kotły narastają w t. 8.
    for bar, ch in enumerate(INTRO):
        add("cello", BASS[ch][0], bar * 4, 4, 70)
        for p in TRIAD[ch]:
            add("vln", p + 12, bar * 4, 4, 40)
        harp_arp(bar, ch, 56 + bar * 2)
    for bar, line in HORN_CALL.items():
        melody("horn", bar, line, 98)
    for k in range(8):
        add("timp", 50, 7 * 4 + 2 + k * 0.25, 0.25, 40 + k * 10, human=False)

    # A: fiddle i rytm country.
    for i, ch in enumerate(A_CH):
        bar = 8 + i
        melody("fiddle", bar, A_MEL[i], 96)
        boom_chick(bar, ch)
        drums(bar, fill=(i == 7))
        if i < 7:
            add("cello", BASS[chord_of(ch, 0)][0], bar * 4, 4, 52)
    add("crash", 49, 8 * 4, 4, 100)
    add("timp", 43, 8 * 4, 1, 110)
    for k in range(8):  # glissando harfy w drugiej połowie t. 16
        add("harp", [55, 57, 59, 62, 64, 66, 67, 71][k], 15 * 4 + 2 + k * 0.25, 0.25, 60 + k * 5)

    # B: tutti.
    for i, ch in enumerate(B_CH):
        bar = 16 + i
        melody("vln", bar, B_MEL[i], 100)
        melody("vla", bar, B_MEL[i], 88, -12)
        melody("horn", bar, B_HORN[i], 96)
        if i >= 4:
            melody("fiddle", bar, B_MEL[i], 74)
            melody("trumpet", bar, B_MEL[i], 92, -12)
        else:
            top = {"Em": "B4", "C": "C5", "G": "D5", "D": "D5"}[ch]
            for s, d in ((0, 1), (2.5, .5), (3, 1)):
                add("trumpet", top, bar * 4 + s, d * 0.9, 96 if s == 0 else 84)
        root = BASS[ch][0]
        for s in (0, 2):
            add("trombone", root + 12 if root < 45 else root, bar * 4 + s, 2, 86)
            add("trombone", (root + 12 if root < 45 else root) + 7, bar * 4 + s, 2, 80)
        add("tuba", ROOT_LOW[ch], bar * 4, 4, 92)
        add("cello", root, bar * 4, 4, 88)
        add("timp", 43 if ch in ("G", "Em") else 50 if ch == "D" else 48, bar * 4, 1, 112)
        boom_chick(bar, ch, 0.8)
        drums(bar, fill=(i == 7))
    add("crash", 49, 16 * 4, 4, 112)
    add("crash", 49, 20 * 4, 4, 104)
    for k in range(16):  # werbel i kotły narastają przed A'
        add("timp", 50, 23 * 4 + k * 0.25, 0.25, 50 + k * 4, human=False)

    # A': fiddle na tle orkiestry.
    for i, ch in enumerate(A_CH):
        bar = 24 + i
        melody("fiddle", bar, A_MEL[i], 104)
        boom_chick(bar, ch)
        drums(bar, fill=(i == 7))
        harp_arp(bar, chord_of(ch, 0), 60, 12)
        for half in (0, 1):
            c = chord_of(ch, half)
            for p in TRIAD[c]:
                add("vln", p + 12, bar * 4 + half * 2, 2, 34)
        add("horn", A2_HORN[i], bar * 4, 4 if i < 7 else 2, 80)
        if i == 7:
            add("horn", "B4", bar * 4 + 2, 2, 84)
        add("cello", BASS[chord_of(ch, 0)][0], bar * 4, 4, 72)
        add("tuba", ROOT_LOW[chord_of(ch, 0)], bar * 4, 4, 70)
    add("crash", 49, 24 * 4, 4, 108)
    add("timp", 43, 24 * 4, 1, 112)

    # Koda: wielki akord G (t. 33), potem fiddle sam i „two bits!” z orkiestrą.
    b = 32 * 4
    for inst, ps, vel in (("vln", [74, 79, 83], 104), ("vla", [62, 67, 71], 96), ("horn", [67, 71, 74], 104),
                          ("trumpet", [67, 74], 96), ("trombone", [55, 62], 96), ("tuba", [31], 100), ("cello", [43, 50], 100),
                          ("fiddle", [79], 100)):
        for p in ps:
            add(inst, p, b, 3.6, vel, human=False)
    add("crash", 49, b, 4, 118)
    add("kick", 36, b, 1, 110)
    for k in range(12):
        add("timp", 43, b + k * 0.25, 0.25, 70 + k * 3, human=False)
    add("timp", 43, b + 3, 1, 115)
    shave = [("G5", 0, 1), ("D5", 1, .5), ("D5", 1.5, .5), ("E5", 2, 1), ("D5", 3, 1), ("F#5", 5, 1)]
    for name, s, d in shave:
        add("fiddle", name, 33 * 4 + s, d * 0.9, 100)
    hit = 33 * 4 + 6  # „bits!”
    add("fiddle", "G5", hit, 0.9, 112, human=False)
    for inst, ps, vel in (("vln", [67, 71, 74, 79], 112), ("horn", [67, 71, 74], 110), ("trumpet", [71, 79], 104),
                          ("trombone", [43, 50, 55], 106), ("tuba", [31], 110), ("cello", [43], 110)):
        for p in ps:
            add(inst, p, hit, 0.6, vel, human=False)
    for inst, p in (("cello_pz", 43), ("bass_pz", 31), ("vln_pz", 79), ("harp", 43), ("harp", 55), ("harp", 67)):
        add(inst, p, hit, 1, 112, human=False)
    add("timp", 43, hit, 1, 124, human=False)
    add("kick", 36, hit, 1, 120, human=False)
    add("crash", 49, hit, 4, 122, human=False)


# --- Próbki i strefy ------------------------------------------------------------

def load_mono(path, sr=22050, seconds=None):
    args = ["ffmpeg", "-v", "error", "-i", path]
    if seconds:
        args += ["-t", str(seconds)]
    raw = subprocess.run(args + ["-ac", "1", "-ar", str(sr), "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def detect_pitch(path):
    """Ton podstawowy próbki (MIDI, ułamkowo) metodą iloczynu harmonicznych widma."""
    sr = 22050
    x = load_mono(path, sr, 2.5)
    if len(x) < sr // 4:
        return None
    env = np.abs(x)
    start = int(np.argmax(env > env.max() * 0.3)) + int(0.12 * sr)
    seg = x[start: start + int(0.8 * sr)]
    if len(seg) < 2048:
        seg = x
    n = 1 << 16
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), n))
    freqs = np.fft.rfftfreq(n, 1 / sr)
    hps = spec.copy()
    for h in (2, 3, 4):
        dec = spec[::h]
        hps[: len(dec)] *= dec
    lo, hi = np.searchsorted(freqs, 25), np.searchsorted(freqs, 2500)
    f0 = freqs[lo + int(np.argmax(hps[lo:hi]))]
    return 69 + 12 * np.log2(f0 / 440.0)


def name_note(path):
    m = re.search(r"(?<![A-Za-z])([A-G][#b]?)(-?\d)(?=[_.\- ]|$)", os.path.basename(path))
    return midi(m.group(1) + m.group(2)) if m else None


def zones_for(name, cfg):
    pattern = cfg["glob"] if os.path.isabs(cfg["glob"]) else VSCO + cfg["glob"]  # własne próbki: pełna ścieżka
    files = sorted(glob.glob(pattern))
    if "pick" in cfg and files:
        picked = [f for f in files if re.search(cfg["pick"], os.path.basename(f))]
        files = picked or files
    if not files:
        if cfg.get("optional"):
            print(f"  (pomijam {name}: brak próbek)")
            return []
        raise SystemExit(f"brak próbek: {name} {cfg['glob']}")
    if cfg.get("pitched", True) is False:
        f = files[len(files) // 2]
        return [{"path": f, "root": cfg["note"], "low": cfg["note"], "high": cfg["note"], "track": 0}]
    roots = {}
    offsets = []
    for f in files:
        guess = name_note(f)
        det = detect_pitch(f)
        if guess is not None and det is not None:
            offsets.append(round((det - guess) / 12) * 12)
        roots[f] = (guess, det)
    offset = max(set(offsets), key=offsets.count) if offsets else 0
    by_root = {}
    for f, (guess, det) in roots.items():
        root = guess + offset if guess is not None else (int(round(det)) if det is not None else None)
        if root is not None and root not in by_root:
            by_root[root] = f
    ordered = sorted(by_root)
    zones = []
    for i, r in enumerate(ordered):
        low = 0 if i == 0 else (ordered[i - 1] + r) // 2 + 1
        high = 127 if i == len(ordered) - 1 else (r + ordered[i + 1]) // 2
        zones.append({"path": by_root[r], "root": r, "low": low, "high": high})
    print(f"  {name}: {len(zones)} stref, przesunięcie nazw {offset:+d}, korzenie {ordered}")
    return zones


# --- SoundCraft ---------------------------------------------------------------

def sc(script, *args):
    res = subprocess.run([SC, "script", script, *args], capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout[-3000:], res.stderr[-3000:])
        raise SystemExit("SoundCraft: błąd")
    return res.stdout


def main():
    os.makedirs(WORK, exist_ok=True)
    compose()
    fix_overlaps()
    print("Strefy samplera:")
    plan = []  # (instrument, zone, notes)
    for name, cfg in INSTRUMENTS.items():
        if not notes[name]:
            continue
        zones = zones_for(name, cfg)
        for z in zones:
            zn = [n for n in notes[name] if z["low"] <= n[0] <= z["high"]]
            if zn:
                plan.append((name, z, zn))
        lost = [n for n in notes[name] if not any(z["low"] <= n[0] <= z["high"] for z in zones)]
        if zones and lost:
            print(f"  ! {name}: {len(lost)} nut poza strefami")
    total = sum(len(p[2]) for p in plan)
    print(f"Ścieżek: {len(plan)}, nut: {total}")

    end_bar = END_BEAT // 4 + 1
    lines = [
        'session.new {"name":"Star Rodeo","sample_rate":48000}',
        f'event.tempo {{"bpm":{BPM}}}',
        'mix.new_bus {"name":"Verb"}',
        'track.new {"kind":"aux","name":"Hall","format":"stereo"}',
        'track.input {"tracks":["Hall"],"input":"Verb"}',
        'mix.insert {"track":"Hall","slot":0,"plugin":"plate_reverb","params":{"mix":100,"decay":3.2,"pre_delay":28,"size":80,"damping":7000,"low_cut":180}}',
        'mix.insert {"track":"Hall","slot":1,"plugin":"eq_7band","params":{"high_shelf_gain":-3}}',
    ]
    for idx, (name, z, zn) in enumerate(plan):
        cfg = INSTRUMENTS[name]
        track = f"{name}_{idx:02d}"
        params = {"root_note": z["root"], "key_low": z["low"], "key_high": z["high"], "attack": cfg["attack"],
                  "release": cfg["release"], "play_mode": 1 if cfg["mode"] == "one" else 0, "velocity": 80,
                  "key_track": 1 if cfg.get("pitched", True) else 0}
        lines += [
            f'track.new {{"kind":"instrument","name":"{track}","format":"stereo"}}',
            "mix.sampler_load " + json.dumps({"track": track, "path": z["path"], "params": params}),
            "mix.volume " + json.dumps({"tracks": [track], "db": cfg["db"]}),
            "mix.pan " + json.dumps({"tracks": [track], "pan": cfg["pan"]}),
            "mix.send " + json.dumps({"track": track, "slot": 0, "bus": "Verb", "level_db": cfg["send"]}),
            "midi.new_clip " + json.dumps({"track": track, "start": 0, "end": f"{end_bar}|1|000"}),
        ]
    lines += ['track.new {"kind":"master","name":"Master","format":"stereo"}']
    s1 = os.path.join(WORK, "phase1.txt")
    open(s1, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    session = os.path.join(WORK, "star_rodeo.scraft")
    print("SoundCraft: ścieżki i klipy...")
    sc(s1, "--save", session)

    data = json.load(open(session, encoding="utf-8"))
    clip_of, master = {}, None
    for t in data["tracks"]:
        if t["kind"] == "Master":
            master = t["id"]
        for pl in t.get("playlists", []):
            for c in pl.get("clips", []):
                clip_of[t["name"]] = c["id"]
    lines = [f'mix.insert {{"track":{master},"slot":0,"plugin":"compressor","params":{{"threshold":-18,"ratio":2,"attack":30,"release":250,"makeup":3}}}}',
             f'mix.insert {{"track":{master},"slot":1,"plugin":"maximizer","params":{{"threshold":-3,"ceiling":-1}}}}']
    for idx, (name, z, zn) in enumerate(plan):
        clip = clip_of[f"{name}_{idx:02d}"]
        for pitch, start, dur, vel in zn:
            lines.append("midi.note_add " + json.dumps({"clip": clip, "pitch": pitch, "start_ticks": int(round(start * PPQ)),
                                                        "length_ticks": max(30, int(dur * PPQ)), "velocity": vel}))
    s2 = os.path.join(WORK, "phase2.txt")
    open(s2, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    wav = os.path.join(WORK, "star_rodeo.wav")
    print("SoundCraft: nuty i zgranie miksu...")
    out = sc(s2, "--in", session, "--save", session, "--in-place", "--bounce", wav, "--end", str(END_BEAT * 60 / BPM))
    print(out.strip().splitlines()[-1][:400])
    os.makedirs(os.path.dirname(OUT_OGG), exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", "afade=t=out:st=%f:d=2.5,loudnorm=I=-15:TP=-2:LRA=11" % (END_BEAT * 60 / BPM - 2.5), "-ar", "48000",
                    "-c:a", "libvorbis", "-q:a", "6", OUT_OGG], check=True)
    print("Gotowe:", OUT_OGG)


if __name__ == "__main__":
    main()
