"""„Homestead”: spokojna, akustyczna muzyka tła do bazy. Bez elektroniki i bez perkusji.

G-dur, 66 BPM, pętla 32 takty (ok. 116 s), bez szwu (ogon pogłosu nałożony na początek).
Łagodne banjo (model fizyczny, ciemniejszy i dłuższy niż w „Hoedown Circuit”) gra
ósemki palcami z dużą ilością powietrza; cicha wiolonczela trzyma bas, smyczki dochodzą
jak mgła, w drugiej połowie skrzypce grają wolną melodię, harfa czasem dzwoni wysoko.
W grze leży pod dźwiękami natury (tło dnia i nocy), więc jest cicha i prosta.

  t. 1-8    banjo i wiolonczela          (G G C G Em C D D)
  t. 9-16   + miękkie smyczki            (C G Am Em C G D D)
  t. 17-24  + skrzypce z melodią          (jak t. 1-8)
  t. 25-32  skrzypce, smyczki, banjo     (jak t. 9-16), ostatnie D prowadzi z powrotem do G

Użycie: python tools/audio/homestead.py
"""
import os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
import fx_synth  # noqa: E402
import sc_song  # noqa: E402
import star_rodeo as sr  # noqa: E402

WORK = "D:/Audio/Sessions/Homestead/"
BANJO = WORK + "banjo_soft/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "homestead.ogg")
BPM = 66
LOOP_BARS = 32
END_BEAT = LOOP_BARS * 4 + 12  # ogon pogłosu, nakładany na początek pętli
midi = sr.midi
## Przesunięcie całości: granica pętli wypada w cichym miejscu, nie na uderzeniu banjo.
LOOP_OFFSET = 0.15

SAMPLED = {
    "banjo":  dict(glob=BANJO + "banjo_*.wav", mode="gate", attack=1, release=900, db=-2, pan=-0.15, send=-9, vel_sens=55,
                   inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 90, "high_mid_freq": 3000, "high_mid_gain": -3, "high_shelf_freq": 7000, "high_shelf_gain": -4})]),
    "cello":  dict(glob="Strings/Cello Section/susvib/*_v1_1.wav", mode="gate", attack=400, release=1500, db=10, pan=0.25, send=-7),
    "vln":    dict(glob="Strings/Violin Section/susVib/*_v1.wav", mode="gate", attack=700, release=1800, db=12, pan=-0.35, send=-5),
    "fiddle": dict(glob="Strings/Solo Violin/Arco Vib/*_p.wav", mode="gate", attack=120, release=900, db=11, pan=0.2, send=-6),
    "harp":   dict(glob="Strings/Harp/*_mf.wav", mode="one", attack=1, release=2500, db=12, pan=-0.5, send=-4),
}

TRIAD = {"G": [55, 59, 62], "C": [48, 52, 55], "Em": [52, 55, 59], "D": [50, 54, 57], "Am": [57, 60, 64]}
ROOT2 = {"G": 43, "C": 48, "Em": 40, "D": 50, "Am": 45}
P1 = ["G", "G", "C", "G", "Em", "C", "D", "D"]
P2 = ["C", "G", "Am", "Em", "C", "G", "D", "D"]
MEL1 = [[("B4", 0, 2), ("D5", 2, 2)], [("G5", 0, 4)], [("E5", 0, 2), ("G5", 2, 1), ("E5", 3, 1)], [("D5", 0, 4)],
        [("B4", 0, 2), ("E5", 2, 2)], [("E5", 0, 2), ("C5", 2, 2)], [("A4", 0, 2), ("D5", 2, 2)], [("F#5", 0, 4)]]
MEL2 = [[("E5", 0, 2), ("G5", 2, 2)], [("D5", 0, 4)], [("C5", 0, 2), ("E5", 2, 2)], [("B4", 0, 4)],
        [("C5", 0, 2), ("E5", 1.5, 0.5), ("G5", 2, 2)], [("B5", 0, 2), ("G5", 2, 2)], [("A5", 0, 2), ("F#5", 2, 2)], [("D5", 0, 4)]]

rng = random.Random(66)
notes = {}


def add(inst, pitch, start, dur, vel, human=0.02):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    start += LOOP_OFFSET + (rng.uniform(-human, human) if human else 0)
    vel += rng.randint(-6, 6) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def voicing(ch):
    """Cztery dźwięki do palcowania: bas (pryma), kwinta, tercja i pryma oktawę wyżej."""
    root = ROOT2[ch] if ROOT2[ch] >= 50 else ROOT2[ch] + 12
    t = TRIAD[ch]
    third = next(p for p in (t[1], t[1] + 12) if p > root)
    fifth = next(p for p in (t[2], t[2] + 12, t[0] + 7) if p > root)
    return sorted({root, fifth, third, root + 12})


def banjo_bar(bar, ch, sparse=False, vel=58):
    v = voicing(ch)
    pattern = [0, 2, 1, 3, 2, 1, 3, 2] if not sparse else [0, None, 2, None, 3, None, 1, None]
    for k, idx in enumerate(pattern):
        if idx is None:
            continue
        accent = 12 if k == 0 else (5 if k == 4 else 0)
        add("banjo", v[idx % len(v)], bar * 4 + k * 0.5, 1.2, vel + accent)


def compose():
    for i in range(LOOP_BARS):
        phrase = i // 8
        j = i % 8
        ch = (P1 if phrase in (0, 2) else P2)[j]
        sparse = phrase == 1 and j in (3, 7)
        banjo_bar(i, ch, sparse=sparse, vel=56 if phrase < 2 else 52)
        add("cello", ROOT2[ch] - 12 if ROOT2[ch] >= 48 else ROOT2[ch], i * 4, 3.9, 62 + (6 if phrase >= 2 else 0), 0)
        if phrase >= 1:
            for p in TRIAD[ch]:
                add("vln", p + 12, i * 4, 3.9, 50 if phrase == 1 else 56, 0)
        if phrase == 2:
            for name, s, d in MEL1[j]:
                add("fiddle", name, i * 4 + s, d * 0.97, 58)
        if phrase == 3:
            for name, s, d in MEL2[j]:
                add("fiddle", name, i * 4 + s, d * 0.97, 62)
        if j == 0:  # harfa dzwoni wysoko na początku każdej frazy
            for k, p in enumerate((TRIAD[ch][0] + 24, TRIAD[ch][2] + 24)):
                add("harp", p, i * 4 + k * 0.75, 2, 76)


def make_banjo():
    os.makedirs(BANJO, exist_ok=True)
    names = "C C# D D# E F F# G G# A A# B".split()
    for m in range(47, 87, 3):
        fx_synth.save(fx_synth.banjo_note(440 * 2 ** ((m - 69) / 12), length=3.0, seed=m + 100, pick_pos=0.3,
                                          brightness=0.9975, damping=0.55, drive=0.9),
                      BANJO + f"banjo_{names[m % 12]}{m // 12 - 1}.wav")


def main():
    if not os.path.exists(BANJO) or "--fx" in sys.argv:
        make_banjo()
    compose()
    sc_song.build("Homestead", WORK, BPM, END_BEAT, notes, OUT_OGG, sampled=SAMPLED,
                  reverb={"decay": 3.4, "pre_delay": 30, "size": 85, "damping": 6000, "low_cut": 150},
                  loudness=-19.0, loop_beats=LOOP_BARS * 4,
                  master=[("compressor", {"threshold": -20, "ratio": 1.5, "attack": 40, "release": 300, "makeup": 1}),
                          ("maximizer", {"threshold": -1, "ceiling": -1})])


if __name__ == "__main__":
    main()
