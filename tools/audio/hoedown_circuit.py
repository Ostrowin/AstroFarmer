"""„Hoedown Circuit”: wyraźny elektroniczny beat + czyste country z dużą ilością banjo.

E-dur, 144 BPM, ok. 90 s. Inspiracja: tempo i tonalność amerykańskiego country
(„Country Boy”, Alan Jackson; tylko tempo i ogólny charakter, bez melodii).

Wyraźny rytm: krótka, sprężysta stopa bez długiego ogona, ostre klaśnięcie z werblem
na 2 i 4, czyste hi-haty na offbeatach, tamburyn w szesnastkach; bas zostawia przerwy
(country „boom-chick” na 1 i 3: kontrabas pizzicato + krótki sub), w refrenie bas
elektroniczny na offbeatach. Mało pogłosu, żadnych długich padów.
Banjo: model fizyczny szarpanej struny (fx_synth.banjo_note), rolle w stylu Scruggsa
z melodią na mocnych częściach beatu.

  Intro    (t. 1-4)    samo banjo, potem klaskanie i HEY
  Zwrotka  (t. 5-12)   beat, boom-chick, banjo z melodią, fiddle odpowiada
  Refren   (t. 13-20)  bas na offbeatach, lead z banjo, fiddle w harmonii, chór
  Zwrotka  (t. 21-28)
  Break    (t. 29-36)  „train beat”, solo banjo, budowanie, YEE-HAW
  Refren   (t. 37-44)
  Refren+  (t. 45-52)  „truck driver”: o cały ton w górę (Fis-dur), jak w country
  Koniec   (t. 53-54)  zbieg banjo, akord, YEE-HAW

Użycie: python tools/audio/hoedown_circuit.py
"""
import os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
import fx_synth  # noqa: E402
import sc_song  # noqa: E402
import star_rodeo as sr  # noqa: E402

WORK = "D:/Audio/Sessions/HoedownCircuit/"
FX = WORK + "fx/"
BANJO = WORK + "banjo/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "hoedown_circuit.ogg")
BPM = 144
END_BEAT = 54 * 4 + 8
midi = sr.midi

SAMPLED = {
    "banjo":    dict(glob=BANJO + "banjo_*.wav", mode="gate", attack=1, release=160, db=-2, pan=-0.2, send=-20, vel_sens=60,
                     inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 120, "mid_freq": 1600, "mid_gain": -3, "mid_q": 0.8, "high_mid_freq": 3800, "high_mid_gain": 3})]),
    "fiddle":   dict(glob="Strings/Solo Violin/Arco Vib/*_f.wav", mode="gate", attack=10, release=200, db=-4, pan=0.3, send=-14,
                     inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 250, "high_mid_freq": 3500, "high_mid_gain": 2})]),
    "fid_spic": dict(glob="Strings/Solo Violin/spic/*_v2_rr1.wav", mode="one", attack=1, release=100, db=-3, pan=0.3, send=-14),
    "upright":  dict(glob="Strings/Solo Contrabass/Pizz/*.wav", mode="one", attack=1, release=150, db=2, pan=0.0, send=-30,
                     pick=r"_f_|_mf_|v2|RR1|rr1"),
    "snare_r":  dict(glob="Percussion/Snare2-HitSN_v7_rr1*.wav", mode="one", pitched=False, note=38, attack=1, release=250, db=0, pan=0.0, send=-22),
    "tamb":     dict(glob="Percussion/Tamb1-Hit_v2_rr1*.wav", mode="one", pitched=False, note=54, attack=1, release=150, db=-16, pan=0.35, send=-30),
}
FX_TRACKS = {
    "kick": dict(file="kick_punch.wav", db=-3, send=-60, release=30),
    "hey": dict(file="hey.wav", db=-7, send=-14, inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 200, "high_shelf_freq": 6000, "high_shelf_gain": 4})]),
    "ha": dict(file="ha.wav", db=-8, send=-14, inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 200, "high_shelf_freq": 6000, "high_shelf_gain": 4})]),
    "yeehaw": dict(file="yeehaw.wav", db=-8, send=-10, echo=True),
    "riser": dict(file="riser_2bar.wav", db=-16, send=-14),
}
SYNTHS = {
    "sub": dict(plugin="subtractive_synth", db=-9, pan=0.0, send=-60, params=dict(
        osc1_wave=2, osc2_wave=3, osc_mix=20, cutoff=400, resonance=0, filter_env_amount=0,
        amp_attack=1, amp_decay=150, amp_sustain=60, amp_release=40, velocity=30, level=-6)),
    "eb": dict(plugin="subtractive_synth", db=-1, pan=0.0, send=-50, params=dict(  # bas elektroniczny (refren)
        osc1_wave=0, osc2_wave=1, osc2_semitones=-12, osc_mix=40, cutoff=900, resonance=35, filter_env_amount=60,
        amp_attack=1, amp_decay=150, amp_sustain=30, amp_release=40, filter_decay=120, filter_sustain=10, velocity=40, level=-6),
        inserts=[("saturator", dict(drive=12, tone=6000, mix=60, output=-5))]),
    "lead": dict(plugin="subtractive_synth", db=-9, pan=0.1, send=-14, params=dict(
        osc1_wave=1, osc2_wave=0, osc2_semitones=12, osc2_detune=8, osc_mix=35, cutoff=5000, resonance=20, filter_env_amount=45,
        amp_attack=1, amp_decay=260, amp_sustain=45, amp_release=120, filter_decay=220, filter_sustain=30, glide=0, velocity=40, level=-6),
        inserts=[("mod_delay", dict(time="dotted8", feedback=25, mix=16, lpf=7000)), ("chorus", dict(mix=25, depth=35))]),
    "drums": dict(plugin="drum_synth", db=4, pan=0.0, send=-26, params=dict(
        snare_tune=2, snare_snappy=75, snare_decay=150, hat_decay=35, open_hat_decay=200, cymbal_decay=1800, level=-6),
        inserts=[("eq_7band", dict(hpf_on=1, hpf_freq=150, high_shelf_freq=8000, high_shelf_gain=3)),
                 ("compressor", dict(threshold=-14, ratio=3, attack=4, release=70, makeup=2))]),
}
SNARE, CLAP, HAT, OHAT, CRASH = 38, 39, 42, 46, 49

TRIAD = {"E": [52, 56, 59], "A": [57, 61, 64], "B": [59, 63, 66], "D": [50, 54, 57]}
BASS = {"E": (40, 35), "A": (45, 40), "B": (47, 42), "D": (38, 45)}  # (pryma, kwinta)
VERSE = ["E", "E", "A", "E", "E", "E", "B", "B"]
CHORUS = ["A", "E", "B", "E", "A", "E", "B", "E"]
BREAK = ["E", "D", "A", "E"]
V_MEL = [["G#4", "B4", "E5", "B4"], ["C#5", "B4", "G#4", "E4"], ["A4", "C#5", "E5", "C#5"], ["B4", "G#4", "E4", "F#4"],
         ["G#4", "B4", "E5", "F#5"], ["E5", "C#5", "B4", "G#4"], ["F#4", "B4", "D#5", "F#5"], ["D#5", "C#5", "B4", "A4"]]
C_MEL = [["E5", "E5", "C#5", "E5"], ["B4", "G#4", "B4", "E5"], ["F#5", "D#5", "B4", "D#5"], ["E5", "B4", "G#4", "E4"],
         ["A4", "C#5", "E5", "F#5"], ["G#5", "E5", "B4", "G#4"], ["F#4", "A4", "B4", "D#5"], ["E5", "E5", "E5", "E5"]]
B_SOLO = ["E5 D5 B4 G#4 B4 D5 E5 G#5 E5 D5 B4 A4 G#4 E4 F#4 G#4",
          "F#5 E5 D5 A4 D5 F#5 A5 F#5 E5 D5 C#5 A4 D5 E5 F#5 D5",
          "E5 C#5 A4 E4 A4 C#5 E5 A5 G#5 E5 C#5 A4 B4 C#5 E5 C#5",
          "B4 G#4 E4 G#4 B4 E5 G#5 B5 G#5 E5 B4 G#4 F#4 E4 D#4 E4"]
SCALE = [64, 66, 68, 69, 71, 73, 75]  # E-dur

rng = random.Random(41)
notes = {}
TRANSPOSE = 0


def add(inst, pitch, start, dur, vel, human=0.006):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    if inst not in ("kick", "hey", "ha", "yeehaw", "riser", "snare_r", "tamb", "drums"):
        pitch += TRANSPOSE
    start += rng.uniform(-human, human) if human else 0
    vel += rng.randint(-4, 4) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def third_below(pitch):
    pcs = [p % 12 for p in SCALE]
    pc = pitch % 12
    if pc not in pcs:
        return pitch - 3
    return pitch - (pc - pcs[(pcs.index(pc) - 2) % 7]) % 12


def banjo_roll(bar, ch, melody, vel=100):
    """Rolla Scruggsa: na każdym beacie nuta melodii (akcent), potem dźwięki akordu
    i „piąta struna” (wysokie B), szesnastkami."""
    tones = sorted({p + o for p in TRIAD[ch] for o in (12, 24) if 62 <= p + o <= 81})
    drone = 71
    for k in range(4):
        m = midi(melody[k])
        hi = [t for t in tones if t != m][-1]
        mid = [t for t in tones if t < m] or tones[:1]
        for j, p in enumerate((m, hi, drone, mid[-1])):
            add("banjo", p, bar * 4 + k + j * 0.25, 0.24, vel + (14 if j == 0 else 0))


def beat(bar, crash=False, open_hats=False, fill=False):
    b = bar * 4
    for k in range(4):
        add("kick", 60, b + k, 0.4, 122, 0)
    for k in (1, 3):
        add("drums", CLAP, b + k, 0.4, 118)
        add("snare_r", 38, b + k, 0.4, 104)
    for k in range(4):
        add("drums", OHAT if open_hats else HAT, b + k + 0.5, 0.25, 96)
    for k in range(16):
        add("tamb", 54, b + k * 0.25, 0.2, 70 if k % 2 else 52)
    if crash:
        add("drums", CRASH, b, 2, 116, 0)
    if fill:
        for k in range(8):
            add("snare_r", 38, b + 2 + k * 0.25, 0.2, 70 + k * 6)


def boom_chick(bar, ch):
    root, fifth = BASS[ch]
    for half, p in ((0, root), (2, fifth)):
        add("upright", p, bar * 4 + half, 0.9, 112)
        add("sub", p, bar * 4 + half, 0.5, 104, 0)


def offbeat_bass(bar, ch):
    root = BASS[ch][0]
    for k in range(4):
        add("eb", root, bar * 4 + k + 0.5, 0.4, 112)
    add("upright", root, bar * 4, 0.9, 110)


def fx(name, b, vel=112):
    add(name, 60, b, 4, vel, 0)


def verse(start, chants=False):
    for i, ch in enumerate(VERSE):
        bar = start + i
        beat(bar, crash=(i == 0), fill=(i == 7))
        boom_chick(bar, ch)
        banjo_roll(bar, ch, V_MEL[i])
        if i in (3, 7):
            for s, name in ((2, V_MEL[i][2]), (2.5, V_MEL[i][3]), (3, V_MEL[i][1])):
                add("fid_spic", midi(name) + 12, bar * 4 + s, 0.5, 98)
        if chants and i % 2 == 1:
            fx("hey", bar * 4 + 3)


def chorus(start, crash_every=4):
    for i, ch in enumerate(CHORUS):
        bar = start + i
        beat(bar, crash=(i % crash_every == 0), open_hats=True, fill=(i == 7))
        offbeat_bass(bar, ch)
        banjo_roll(bar, ch, C_MEL[i], vel=104)
        for k, name in enumerate(C_MEL[i]):
            p = midi(name)
            add("lead", p + 12, bar * 4 + k, 0.9, 100)
            add("fiddle", third_below(p) + 12, bar * 4 + k, 0.95, 92)
        if i % 2 == 0:
            fx("hey", bar * 4 + 3)
        else:
            fx("ha", bar * 4 + 3.5)


def compose():
    global TRANSPOSE
    # Intro: samo banjo, potem klaskanie i HEY
    for i in range(4):
        banjo_roll(i, VERSE[i], V_MEL[i], vel=96)
        if i >= 2:
            for k in (1, 3):
                add("drums", CLAP, i * 4 + k, 0.4, 110)
    fx("hey", 3 * 4 + 3)
    for k in range(4):
        add("snare_r", 38, 3 * 4 + 2 + k * 0.5, 0.3, 80 + k * 10)

    verse(4)
    chorus(12)
    verse(20, chants=True)

    # Break: train beat i solo banjo
    for i in range(8):
        bar = 28 + i
        ch = BREAK[i % 4]
        line = B_SOLO[i % 4].split()
        for j, name in enumerate(line):
            add("banjo", name, bar * 4 + j * 0.25, 0.24, 104 if j % 4 == 0 else 86)
        for k in range(16):
            accent = k in (4, 12)
            add("snare_r", 38, bar * 4 + k * 0.25, 0.2, 100 if accent else 44 + (8 if k % 2 == 0 else 0))
        root, fifth = BASS[ch]
        add("upright", root, bar * 4, 0.9, 108)
        add("upright", fifth, bar * 4 + 2, 0.9, 100)
        if i >= 4:
            for k in range(4):
                add("kick", 60, bar * 4 + k, 0.4, 112 + i, 0)
            for k in (1, 3):
                add("drums", CLAP, bar * 4 + k, 0.4, 116)
        if i == 7:
            for k in range(4):
                fx("hey", bar * 4 + k, 100 + k * 6)
    fx("riser", 34 * 4)
    fx("yeehaw", 35 * 4 + 2.0)

    chorus(36)
    # Refren+: o cały ton w górę
    TRANSPOSE = 2
    chorus(44, crash_every=2)
    TRANSPOSE = 2
    # Koniec: zbieg banjo, akord, YEE-HAW
    b = 52 * 4
    for j, name in enumerate("E5 D#5 C#5 B4 G#4 F#4 E4 D#4 E4 G#4 B4 E5".split()):
        add("banjo", name, b + j * 0.25, 0.24, 104)
    for k in range(2):
        add("kick", 60, b + k * 2, 0.4, 120, 0)
    add("upright", 40, b, 0.9, 110)
    e = b + 4
    for p in (52, 56, 59, 64, 68, 71, 76):
        add("banjo", p, e + (p - 52) * 0.006, 1.6, 112, 0)
    add("fiddle", "E5", e, 1.5, 108, 0)
    add("lead", "E6", e, 1.2, 104, 0)
    add("upright", 40, e, 0.9, 118, 0)
    add("sub", 40, e, 1.2, 114, 0)
    add("kick", 60, e, 0.4, 127, 0)
    add("drums", CRASH, e, 4, 124, 0)
    fx("yeehaw", e + 1.0, 118)
    TRANSPOSE = 0


def make_fx():
    os.makedirs(FX, exist_ok=True)
    os.makedirs(BANJO, exist_ok=True)
    names = "C C# D D# E F F# G G# A A# B".split()
    for m in range(50, 90, 3):  # banjo: D3 .. D#6 co 3 półtony
        fx_synth.save(fx_synth.banjo_note(440 * 2 ** ((m - 69) / 12), seed=m), BANJO + f"banjo_{names[m % 12]}{m // 12 - 1}.wav")
    fx_synth.save(fx_synth.sub_kick(tail_hz=55, length=0.26, hold=0.35, grit=0.3), FX + "kick_punch.wav")
    chord = [1.0, 0.794, 1.189, 1.004, 0.79, 1.19]  # B3, G3(#), D#4... chór w E-dur: E, G#, B
    fx_synth.save(fx_synth.shout("e", 207.65, 0.26, 6, 24, [1.0, 0.794, 1.189, 1.003, 0.8, 1.185]), FX + "hey.wav")
    fx_synth.save(fx_synth.shout("a", 207.65, 0.22, 6, 25, chord), FX + "ha.wav")
    fx_synth.save(fx_synth.yeehaw(1.0, 1.0, 31), FX + "yeehaw.wav")
    fx_synth.save(fx_synth.riser(2 * 4 * 60 / BPM), FX + "riser_2bar.wav")


def main():
    if not os.path.exists(FX + "kick_punch.wav") or "--fx" in sys.argv:
        make_fx()
    compose()
    sc_song.build("Hoedown Circuit", WORK, BPM, END_BEAT, notes, OUT_OGG, sampled=SAMPLED, fx_tracks=FX_TRACKS, fx_dir=FX,
                  synths=SYNTHS, reverb={"decay": 1.1, "size": 40, "low_cut": 350}, loudness=-11.0, fade=1.0,
                  master=[("compressor", {"threshold": -14, "ratio": 2.5, "attack": 15, "release": 120, "makeup": 2}),
                          ("maximizer", {"threshold": -6, "ceiling": -1})])


if __name__ == "__main__":
    main()
