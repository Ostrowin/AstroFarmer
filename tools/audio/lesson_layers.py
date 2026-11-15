"""„Lekcja”: krótki utwór do nauki budowy muzyki. Nie trafia do gry.

G-dur, 100 BPM, 16 taktów + akord końcowy (ok. 42 s). Każda warstwa robi jedną,
łatwą do usłyszenia rzecz, a po złożeniu skrypt zgrywa każdą warstwę osobno
(solo w SoundCraft, suma bez obróbki), żeby dało się je włączać i wyłączać.

Warstwy:
  stopa    - puls na 1 i 3 (to, pod co tupie noga)
  werbel   - backbeat na 2 i 4, przejście (fill) na końcu frazy
  hihat    - podział na ósemki, talerz crash na początku fraz
  bas      - pryma akordu na 1, kwinta na 3, „spacer” do następnego akordu
  akordy   - smyczki trzymają harmonię, jeden akord na takt
  arpeggio - banjo rozkłada akord na pojedyncze dźwięki w ósemkach
  melodia  - skrzypce: motyw, powtórzenie, pytanie (koniec na D) i odpowiedź (koniec na G)

Forma:
  A (t. 1-8)   G D Em C | G D C D     kończy się „pytaniem” (akord D)
  B (t. 9-16)  C G D Em | C G D G     wyżej, kulminacja w t. 13, „odpowiedź” na G
  koniec (t. 17) wspólne uderzenie G

Użycie:
  python tools/audio/lesson_layers.py            dur (major)
  python tools/audio/lesson_layers.py --minor    ten sam utwór w g-moll
  python tools/audio/lesson_layers.py --bpm 70   ten sam utwór wolniej
"""
import json, os, random, subprocess, sys

sys.path.insert(0, os.path.dirname(__file__))
import sc_song  # noqa: E402
import star_rodeo as sr  # noqa: E402

SC = "D:/Programy/Craft/SoundCraft/soundcraft-cli.exe"
MINOR = "--minor" in sys.argv
BPM = int(sys.argv[sys.argv.index("--bpm") + 1]) if "--bpm" in sys.argv else 100
TAG = ("minor" if MINOR else "major") + ("" if BPM == 100 else f"_{BPM}")
WORK = f"D:/Audio/Sessions/Lekcja/{TAG}/"
BANJO = "D:/Audio/Sessions/HoedownCircuit/banjo/"  # próbki banjo z „Hoedown Circuit”
BARS = 17
END_BEAT = BARS * 4 + 4  # + ogon akordu końcowego
midi = sr.midi

LAYERS = {  # warstwa -> prefiksy nazw ścieżek w SoundCraft
    "stopa": ["kick"], "werbel": ["snare"], "hihat": ["hat"], "bas": ["upright"],
    "akordy": ["pad"], "arpeggio": ["banjo"], "melodia": ["fiddle"],
}

SAMPLED = {
    "fiddle":  dict(glob="Strings/Solo Violin/Arco Vib/*_f.wav", mode="gate", attack=12, release=260, db=5.5, even_zones=True, pan=0.1, send=-12,
                    inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 250, "high_mid_freq": 3500, "high_mid_gain": -2})]),
    "pad":     dict(glob="Strings/Violin Section/susVib/*_v2.wav", mode="gate", attack=250, release=700, db=1.5, even_zones=True, pan=-0.3, send=-8),
    "banjo":   dict(glob=BANJO + "banjo_*.wav", mode="gate", attack=1, release=300, db=-8, pan=0.35, send=-16, vel_sens=60,
                    inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 120, "high_mid_freq": 3200, "high_mid_gain": -3, "high_mid_q": 0.7})]),
    # Gate, nie One Shot: w One Shot pizzicato dźwięczy do końca próbki i stary dźwięk (np. D)
    # brzmi jeszcze pod następnym akordem (Em, C). Zmierzone: zgodność taktu C spadała do 0,07.
    "upright": dict(glob="Strings/Solo Contrabass/Pizz/*.wav", mode="gate", attack=1, release=120, db=12, even_zones=True, sampler={"level": 2}, pan=0.0, send=-26,
                    pick=r"_f_|_mf_|v2|RR1|rr1",
                    inserts=[("compressor", {"threshold": -26, "ratio": 4, "attack": 4, "release": 120, "makeup": 9}),
                             ("eq_7band", {"low_mid_freq": 700, "low_mid_gain": 4, "low_mid_q": 0.9})]),
}
DRUM = dict(kick_tune=-2, kick_decay=320, snare_tune=2, snare_snappy=70, snare_decay=180, hat_decay=45, cymbal_decay=2200, level=-6)
SYNTHS = {
    "kick":  dict(plugin="drum_synth", db=5.5, pan=0.0, send=-60, params=DRUM),
    "snare": dict(plugin="drum_synth", db=7, pan=0.0, send=-20, params={**DRUM, "snare_tune": 0}),  # ton werbla na G, nie A#
    "hat":   dict(plugin="drum_synth", db=2, pan=0.2, send=-28, params=DRUM,
                  inserts=[("eq_7band", dict(hpf_on=1, hpf_freq=300))]),
}
KICK, SNARE, HAT, CRASH = 36, 38, 42, 49

PROG = ["G", "D", "Em", "C", "G", "D", "C", "D",
        "C", "G", "D", "Em", "C", "G", "D", "G", "G"]
PAD = {"G": [55, 59, 62], "D": [54, 57, 62], "Em": [55, 59, 64], "C": [55, 60, 64]}   # bliskie położenia: dźwięki prawie stoją
ARP = {"G": [55, 59, 62, 67], "D": [50, 54, 57, 62], "Em": [52, 55, 59, 64], "C": [48, 52, 55, 60]}
BASS = {"G": (43, 38), "D": (38, 45), "Em": (40, 47), "C": (36, 43)}  # (pryma, kwinta)
WALK = {3: [36, 38, 40, 42], 7: [38, 42, 45, 47], 11: [40, 43, 47, 43], 14: [38, 40, 42, 42]}  # „spacer” basu do następnego akordu
# melodia: (nuta, start w beatach w takcie, długość)
MEL = [
    [("D5", 0, 1), ("B4", 1, .5), ("D5", 1.5, .5), ("G5", 2, 2)],                 # motyw
    [("F#5", 0, 1), ("E5", 1, .5), ("D5", 1.5, .5), ("A4", 2, 2)],                # motyw o krok niżej
    [("B4", 0, 1), ("E5", 1, .5), ("G5", 1.5, .5), ("B5", 2, 1), ("A5", 3, 1)],
    [("G5", 0, 3), ("E5", 3, 1)],
    [("D5", 0, 1), ("B4", 1, .5), ("D5", 1.5, .5), ("G5", 2, 2)],                 # powtórzenie motywu
    [("A5", 0, 1), ("F#5", 1, .5), ("E5", 1.5, .5), ("D5", 2, 2)],
    [("E5", 0, 1.5), ("D5", 1.5, .5), ("C5", 2, 1), ("E5", 3, 1)],
    [("D5", 0, 4)],                                                              # pytanie: zatrzymanie na D
    [("G5", 0, 1), ("E5", 1, .5), ("G5", 1.5, .5), ("C6", 2, 2)],                 # B: motyw wyżej
    [("B5", 0, 1), ("A5", 1, .5), ("G5", 1.5, .5), ("D5", 2, 2)],
    [("A5", 0, 1.5), ("G5", 1.5, .5), ("F#5", 2, 1), ("A5", 3, 1)],
    [("G5", 0, 2), ("E5", 2, 2)],
    [("E5", 0, 1), ("G5", 1, 1), ("C6", 2, 1.5), ("B5", 3.5, .5)],                # kulminacja
    [("B5", 0, 1), ("A5", 1, 1), ("G5", 2, 2)],
    [("F#5", 0, 1), ("E5", 1, 1), ("D5", 2, 1), ("F#5", 3, 1)],
    [("G5", 0, 3.5)],                                                            # odpowiedź: powrót do G
]

rng = random.Random(7)
notes = {}
MINOR_MAP = {11: 10, 4: 3, 6: 5}  # G-dur -> g-moll: B->Bb, E->Eb, F#->F


def add(inst, pitch, start, dur, vel, human=0.008):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    if MINOR and inst not in SYNTHS:
        pitch = pitch - (pitch % 12) + MINOR_MAP.get(pitch % 12, pitch % 12)
    start += rng.uniform(-human, human) if human else 0
    vel += rng.randint(-4, 4) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def compose():
    for bar, ch in enumerate(PROG[:16]):
        b = bar * 4
        # rytm
        for k in (0, 2):
            add("kick", KICK, b + k, 0.4, 120, 0)
        for k in (1, 3):
            add("snare", SNARE, b + k, 0.4, 112, 0)
        for k in range(8):
            add("hat", HAT, b + k * 0.5, 0.25, 92 if k % 2 == 0 else 66)
        if bar in (0, 8):
            add("hat", CRASH, b, 2, 110, 0)
        if bar in (7, 15):  # przejście: werbel szesnastkami narasta do następnej frazy
            for k in range(8):
                add("snare", SNARE, b + 2 + k * 0.25, 0.2, 64 + k * 7, 0)
        # bas
        if bar in WALK:
            for k, p in enumerate(WALK[bar]):
                add("upright", p, b + k, 0.85, 108 if k == 0 else 96)
        else:
            root, fifth = BASS[ch]
            add("upright", root, b, 1.7, 112)
            add("upright", fifth, b + 2, 1.7, 100)
        # akordy
        for p in PAD[ch]:
            add("pad", p, b, 3.95, 78, 0)
        # arpeggio
        v = ARP[ch]
        for k, idx in enumerate((0, 2, 1, 3, 2, 1, 3, 2)):
            add("banjo", v[idx] + 12, b + k * 0.5, 0.45, 96 if k == 0 else (84 if k == 4 else 72))
        # melodia
        for name, s, d in MEL[bar]:
            add("fiddle", name, b + s, d * 0.96, 100 if s == 0 else 90)
    # koniec: wspólne uderzenie G
    e = 16 * 4
    add("kick", KICK, e, 0.4, 124, 0)
    add("hat", CRASH, e, 4, 118, 0)
    add("upright", 43, e, 2.5, 118, 0)
    for p in PAD["G"]:
        add("pad", p, e, 3.5, 84, 0)
    for k, p in enumerate((67, 71, 74, 79)):
        add("banjo", p, e + k * 0.04, 2.5, 100, 0)
    add("fiddle", "G5", e, 3.0, 104, 0)


def bounce_layers(session):
    """Każda warstwa osobno, obróbka sumy wyłączona. Wyciszamy pozostałe ścieżki zamiast
    solo, bo solo w SoundCraft wycina też powrót pogłosu (warstwa wychodziłaby sucha)."""
    data = json.load(open(session, encoding="utf-8"))
    names = [t["name"] for t in data["tracks"] if t["kind"] == "Instrument"]
    master = [t["id"] for t in data["tracks"] if t["kind"] == "Master"][0]
    bypass = []
    for slot in (0, 1):
        bypass += ["--cmd", "mix.insert_bypass=" + json.dumps({"track": master, "slot": slot, "value": True})]
    length = END_BEAT * 60 / BPM
    out = {}
    for layer, prefixes in list(LAYERS.items()) + [("_all", sum(LAYERS.values(), []))]:
        tracks = [n for n in names if any(n.startswith(p) for p in prefixes)]
        others = [n for n in names if n not in tracks]
        wav = os.path.join(WORK, f"layer_{layer}.wav")
        res = subprocess.run([SC, "run", "--in", session, *bypass, *(["--cmd", "mix.mute=" + json.dumps({"tracks": others, "value": True})] if others else []),
                              "--bounce", wav, "--start", "0", "--end", str(length)], capture_output=True, text=True)
        lufs = None
        for line in res.stdout.splitlines():
            if '"lufs"' in line:
                lufs = json.loads(line[line.index("{"):]).get("lufs")
        out[layer] = (wav, lufs)
        print(f"  {layer:9s} {lufs if lufs is None else round(lufs, 1)} LUFS  ({len(tracks)} ścieżek)", flush=True)
    return out


def export(layers):
    """Wspólne wzmocnienie dla wszystkich warstw (proporcje zostają), OGG + nuty w JSON."""
    gain = -16.0 - layers["_all"][1]
    for layer, (wav, _) in layers.items():
        if layer == "_all":
            continue
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", f"volume={gain:.2f}dB", "-ar", "48000",
                        "-c:a", "libvorbis", "-q:a", "5", os.path.join(WORK, f"{layer}.ogg")], check=True)
    inst_layer = {p: layer for layer, prefixes in LAYERS.items() for p in prefixes}
    json.dump({"bpm": BPM, "bars": BARS, "end_beat": END_BEAT, "minor": MINOR, "prog": PROG,
               "notes": {inst_layer[i]: [[p, round(s, 3), d, v] for p, s, d, v in n] for i, n in notes.items()}},
              open(os.path.join(WORK, "notes.json"), "w", encoding="utf-8"))
    print(f"Warstwy: wzmocnienie {gain:+.1f} dB, pliki w {WORK}")


def main():
    compose()
    session = sc_song.build("Lekcja", WORK, BPM, END_BEAT, notes, os.path.join(WORK, "full.ogg"), sampled=SAMPLED,
                            synths=SYNTHS, reverb={"decay": 1.6, "size": 55, "low_cut": 300}, loudness=-14.0, fade=0.5,
                            master=[("compressor", {"threshold": -12, "ratio": 1.6, "attack": 30, "release": 200, "makeup": 1}),
                                    ("maximizer", {"threshold": -2, "ceiling": -1})])
    print("Warstwy osobno (LUFS solo, suma bez obróbki):")
    export(bounce_layers(session))


if __name__ == "__main__":
    main()
