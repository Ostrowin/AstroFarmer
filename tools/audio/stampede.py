"""„Stampede”: twarda elektronika z akcentami country, trzeci utwór na bossa (na później).

c-moll, 152 BPM, ok. 82 s. Zbudowany według analizy utworu-odniesienia (proporcje
brzmienia, bez melodii): potężny, czysty subbas (stopa strojona nisko, ogon przez cały
beat, przester tylko w górnej warstwie), bas z czystym subem i brudną warstwą na wierzchu
na każdej szesnastce, jasna góra (gęste hi-haty, jasny lead, chór), prawie stała energia.
Country tylko jako akcenty: fiddle i banjo odpowiadają leadowi w części B.

  Intro  (t. 1-2)     lead gra hak, hi-haty, HEY!
  A      (t. 3-18)    pełny beat: stopa, rolling bas, hak, chór
  B      (t. 19-26)   „stomp”: bas na offbeatach, lead i fiddle z banjo na zmianę
  Zryw   (t. 27-30)   sama stopa i chór, riser, YEE-HAW
  A'     (t. 31-46)   jak A, lead oktawę wyżej w drugiej połowie
  Finał  (t. 47-52)   ostatnie cztery takty na pełnym gazie, uderzenie, YEE-HAW

Użycie: python tools/audio/stampede.py
"""
import os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
import fx_synth  # noqa: E402
import sc_song  # noqa: E402
import star_rodeo as sr  # noqa: E402

WORK = "D:/Audio/Sessions/Stampede/"
FX = WORK + "fx/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "stampede.ogg")
BPM = 152
END_BEAT = 52 * 4 + 10
midi = sr.midi

BRIGHT = ("eq_7band", {"hpf_on": 1, "hpf_freq": 300, "high_mid_freq": 4000, "high_mid_gain": 4, "high_shelf_freq": 9000, "high_shelf_gain": 3})
SAMPLED = {
    "fiddle":   dict(glob="Strings/Solo Violin/Arco Vib/*_f.wav", mode="gate", attack=6, release=140, db=0, pan=0.25, send=-14, inserts=[BRIGHT]),
    "fid_spic": dict(glob="Strings/Solo Violin/spic/*_v2_rr1.wav", mode="one", attack=1, release=90, db=1, pan=0.25, send=-14, inserts=[BRIGHT]),
    "banjo":    dict(glob="Strings/Harp/*_mf.wav", mode="gate", attack=1, release=70, db=2, pan=-0.4, send=-16,
                     inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 350, "high_mid_freq": 3500, "high_mid_gain": 8}), ("saturator", {"drive": 10, "mix": 40})]),
}
FX_TRACKS = {
    "kick": dict(file="kick_sub.wav", root=31, pitched=True, db=-6, send=-50, release=40,
                 inserts=[("compressor", {"threshold": -8, "ratio": 3, "attack": 5, "release": 50, "makeup": 1})]),
    "hey": dict(file="hey.wav", db=-4, send=-11, inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 200, "high_shelf_freq": 6000, "high_shelf_gain": 5})]),
    "ha": dict(file="ha.wav", db=-5, send=-11, inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 200, "high_shelf_freq": 6000, "high_shelf_gain": 5})]),
    "yeehaw": dict(file="yeehaw.wav", db=-9, send=-9, echo=True),
    "riser": dict(file="riser_4bar.wav", db=-15, send=-12),
    "impact": dict(file="impact.wav", db=-9, send=-12),
    "revcym": dict(file="rev_cymbal.wav", db=-11, send=-8),
}
SYNTHS = {
    "sub": dict(plugin="subtractive_synth", db=-11, pan=0.0, send=-60, params=dict(
        osc1_wave=2, osc2_wave=2, osc2_semitones=0, osc2_detune=0, osc_mix=0, cutoff=300, resonance=0, filter_env_amount=0,
        amp_attack=1, amp_decay=120, amp_sustain=70, amp_release=30, velocity=30, level=-6),
        inserts=[("eq_7band", {"lpf_on": 1, "lpf_freq": 1000, "lpf_slope": 3})]),
    "grit": dict(plugin="subtractive_synth", db=-2, pan=0.0, send=-40, params=dict(
        osc1_wave=0, osc2_wave=1, osc2_semitones=12, osc2_detune=10, osc_mix=40, cutoff=1800, resonance=30,
        filter_env_amount=55, amp_attack=1, amp_decay=110, amp_sustain=45, amp_release=30, filter_attack=1,
        filter_decay=100, filter_sustain=20, filter_release=50, velocity=40, level=-6),
        inserts=[("saturator", dict(drive=24, tone=7000, mix=90, output=-10)), ("eq_7band", dict(hpf_on=1, hpf_freq=90, hpf_slope=3, high_mid_gain=2))]),
    "lead": dict(plugin="subtractive_synth", db=2, pan=0.0, send=-13, params=dict(
        osc1_wave=0, osc2_wave=0, osc2_semitones=12, osc2_detune=14, osc_mix=45, cutoff=11000, resonance=18,
        filter_env_amount=40, amp_attack=1, amp_decay=180, amp_sustain=65, amp_release=90, filter_attack=1,
        filter_decay=160, filter_sustain=50, filter_release=120, glide=15, velocity=40, level=-6),
        inserts=[("saturator", dict(drive=8, tone=14000, mix=40)), ("chorus", dict(mix=35, depth=45, spread=100)),
                 ("mod_delay", dict(time="dotted8", feedback=25, mix=15, lpf=9000)), ("eq_7band", dict(hpf_on=1, hpf_freq=250, high_shelf_gain=3))]),
    "stab": dict(plugin="subtractive_synth", db=3, pan=0.0, send=-10, params=dict(
        osc1_wave=0, osc2_wave=0, osc2_detune=18, osc_mix=50, cutoff=8000, resonance=15, filter_env_amount=30,
        amp_attack=1, amp_decay=220, amp_sustain=0, amp_release=120, filter_decay=180, filter_sustain=10, velocity=40, level=-6),
        inserts=[("chorus", dict(mix=50, depth=60)), ("eq_7band", dict(hpf_on=1, hpf_freq=400))]),
    "drums": dict(plugin="drum_synth", db=11, pan=0.0, send=-20, params=dict(
        snare_tune=3, snare_snappy=85, snare_decay=150, hat_decay=40, open_hat_decay=240, tom_decay=300, cymbal_decay=2000, level=-6),
        inserts=[("eq_7band", dict(hpf_on=1, hpf_freq=180, high_shelf_freq=8000, high_shelf_gain=4)),
                 ("compressor", dict(threshold=-16, ratio=3, attack=6, release=80, makeup=3))]),
}
SNARE, CLAP, HAT, OHAT, CRASH, RIDE = 38, 39, 42, 46, 49, 51

A_CH = ["Cm", "Ab", "Bb", "G"]
B_CH = ["Cm", "Fm", "Ab", "G"]
TRIAD = {"Cm": [60, 63, 67], "Ab": [56, 60, 63], "Bb": [58, 62, 65], "G": [55, 59, 62], "Fm": [53, 56, 60]}
LOW = {"Cm": 36, "Ab": 32, "Bb": 34, "G": 31, "Fm": 29}  # sub, bas, strojenie stopy (ok. 44-65 Hz)
HOOK = {
    "Cm": "C5 . C5 Eb5 G5 . C5 . Bb4 . C5 Eb5 G5 . F5 Eb5",
    "Ab": "C5 . C5 Eb5 Ab5 . C5 . G5 . F5 Eb5 C5 . Bb4 C5",
    "Bb": "D5 . D5 F5 Bb5 . D5 . C5 . Bb4 D5 F5 . Eb5 D5",
    "G":  "D5 . D5 G5 B5 . D5 . C6 . B5 G5 D5 . B4 D5",
}
HOEDOWN = {
    "Fm": "C5 F5 Ab5 F5 C5 F5 Ab5 C6 Bb5 Ab5 G5 F5 Eb5 F5 G5 Ab5",
    "G":  "B4 D5 G5 D5 B4 D5 G5 B5 Ab5 G5 F5 D5 B4 C5 D5 F5",
}

rng = random.Random(31)
notes = {}


def add(inst, pitch, start, dur, vel, human=0.005):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    start += rng.uniform(-human, human) if human else 0
    vel += rng.randint(-4, 4) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def line(inst_short, inst_long, text, bar, vel, octave=0):
    tokens = text.split()
    for i, tok in enumerate(tokens):
        if tok in (".", "-"):
            continue
        length = 1
        while i + length < len(tokens) and tokens[i + length] == ".":
            length += 1
        s, d = i * 0.25, length * 0.25
        accent = 14 if s % 1 == 0 else (5 if s % 0.5 == 0 else 0)
        inst = inst_short if d <= 0.25 else inst_long
        add(inst, midi(tok) + octave, bar * 4 + s, d * 0.9, vel + accent)


def kick(bar, ch, beats=(0, 1, 2, 3), vel=124):
    for k in beats:
        add("kick", LOW[ch], bar * 4 + k, 0.5, vel, 0)


def bass(bar, ch, rolling=True):
    root = LOW[ch]
    for k in range(4):
        steps = (0.25, 0.5, 0.75) if rolling else (0.5,)
        for s in steps:
            d = 0.2 if rolling else 0.42
            add("sub", root, bar * 4 + k + s, d, 110, 0)
            add("grit", root + 12, bar * 4 + k + s, d, 110 if s == 0.5 else 96)


def drums(bar, crash=False, fill=False, open_hats=True):
    b = bar * 4
    for k in (1, 3):
        add("drums", CLAP, b + k, 0.5, 116)
        add("drums", SNARE, b + k, 0.5, 100)
    for k in range(16):
        if open_hats and k % 4 == 2:
            add("drums", OHAT, b + k * 0.25, 0.3, 100)
        else:
            add("drums", HAT, b + k * 0.25, 0.2, [100, 72, 0, 84][k % 4] or 90)
    if crash:
        add("drums", CRASH, b, 2, 120, 0)
    if fill:
        for k in range(8):
            add("drums", SNARE, b + 2 + k * 0.25, 0.2, 80 + k * 5)


def stab(bar, ch, vel=96):
    for s in (0.5, 1.5, 2.5, 3.5):
        for p in TRIAD[ch]:
            add("stab", p + 12, bar * 4 + s, 0.3, vel)


def banjo_roll(bar, ch):
    tones = sorted({p + o for p in TRIAD[ch] for o in (0, 12) if 62 <= p + o <= 82})
    drone = min(tones, key=lambda q: abs(q - 72))
    i_, m_ = tones[-2], tones[-1]
    for k, p in enumerate([drone, i_, m_, drone, i_, m_, drone, m_] * 2):
        add("banjo", p, bar * 4 + k * 0.25, 0.2, 94 if k % 4 == 0 else 76)


def fx(name, beat, vel=112):
    add(name, 60, beat, 4, vel, 0)


def full_bar(bar, ch, i, octave=0, crash_every=8):
    kick(bar, ch)
    bass(bar, ch, rolling=True)
    drums(bar, crash=(i % crash_every == 0), fill=(i % 8 == 7))
    line("lead", "lead", HOOK[ch], bar, 104, octave)
    stab(bar, ch)
    if i % 2 == 1:
        fx("hey", bar * 4 + 3)
    elif i % 4 == 2:
        fx("ha", bar * 4 + 3)
        fx("ha", bar * 4 + 3.5)


def compose():
    # Intro (2 takty): hak, hi-haty, HEY
    for bar in range(2):
        ch = A_CH[bar]
        line("lead", "lead", HOOK[ch], bar, 96)
        for k in range(16):
            add("drums", HAT, bar * 4 + k * 0.25, 0.2, 60 + k)
        add("drums", CLAP, bar * 4 + 1, 0.5, 100)
        add("drums", CLAP, bar * 4 + 3, 0.5, 100)
    fx("hey", 3)
    fx("revcym", 0)
    for k in range(8):
        add("drums", SNARE, 1 * 4 + 2 + k * 0.25, 0.2, 70 + k * 6)

    # A (16 taktów)
    for i in range(16):
        full_bar(2 + i, A_CH[i % 4], i)
    fx("impact", 2 * 4)

    # B: stomp, lead i country na zmianę
    for i in range(8):
        bar = 18 + i
        ch = B_CH[i % 4]
        kick(bar, ch)
        bass(bar, ch, rolling=False)
        drums(bar, crash=(i == 0), fill=(i == 7))
        if ch in HOEDOWN:
            line("fid_spic", "fiddle", HOEDOWN[ch], bar, 104)
            banjo_roll(bar, ch)
            fx("ha", bar * 4 + 3.5)
        else:
            line("lead", "lead", HOOK[ch], bar, 100)
            banjo_roll(bar, ch)
        if i % 2 == 0:
            fx("hey", bar * 4 + 3)

    # Zryw: stopa i chór, riser, YEE-HAW
    for i in range(4):
        bar = 26 + i
        ch = A_CH[i]
        kick(bar, ch, vel=118)
        for k in range(8):
            add("drums", HAT, bar * 4 + k * 0.5, 0.2, 70 + i * 6)
        for k in range(4):
            if i < 3 or k < 2:
                fx("hey", bar * 4 + k, 92 + i * 8)
        if i == 3:
            for k in range(8):
                add("drums", SNARE, bar * 4 + k * 0.25, 0.2, 70 + k * 7)
            for k in range(8):
                add("drums", SNARE, bar * 4 + 2 + k * 0.25, 0.2, 90 + k * 4)
    fx("riser", 26 * 4)
    fx("revcym", 28 * 4)
    fx("yeehaw", 29 * 4 + 1.0)

    # A' (16 taktów), w drugiej połowie lead oktawę wyżej
    for i in range(16):
        full_bar(30 + i, A_CH[i % 4], i, octave=12 if i >= 8 else 0, crash_every=4)
        if i >= 8 and i % 2 == 1:
            line("fid_spic", "fiddle", HOOK[A_CH[i % 4]], 30 + i, 92)
    fx("impact", 30 * 4)

    # Finał: 4 takty pełnego gazu + uderzenie i YEE-HAW
    for i in range(4):
        full_bar(46 + i, A_CH[i], i + 1, octave=12, crash_every=2)
        line("fid_spic", "fiddle", HOOK[A_CH[i]], 46 + i, 96)
    b = 50 * 4
    kick(50, "Cm", beats=(0,), vel=127)
    fx("impact", b)
    add("drums", CRASH, b, 4, 126, 0)
    add("sub", 36, b, 1.5, 120, 0)
    add("grit", 48, b, 1.5, 120, 0)
    for p in TRIAD["Cm"]:
        add("stab", p + 12, b, 1.2, 120, 0)
    add("lead", 84, b, 1.2, 116, 0)
    fx("yeehaw", b + 2.0, 120)


def make_fx():
    os.makedirs(FX, exist_ok=True)
    bar = 4 * 60 / BPM
    fx_synth.save(fx_synth.sub_kick(length=0.395, hold=0.93), FX + "kick_sub.wav")
    chord = [1.0, 0.794, 1.335, 1.004, 0.79, 1.33]  # G3, Eb3, C4: chór w c-moll
    fx_synth.save(fx_synth.shout("e", 196.0, 0.28, 6, 14, chord), FX + "hey.wav")
    fx_synth.save(fx_synth.shout("a", 196.0, 0.24, 6, 15, chord), FX + "ha.wav")
    fx_synth.save(fx_synth.yeehaw(1.0, 0.95, 21), FX + "yeehaw.wav")
    fx_synth.save(fx_synth.riser(4 * bar), FX + "riser_4bar.wav")
    fx_synth.save(fx_synth.impact(), FX + "impact.wav")
    fx_synth.save(fx_synth.reverse_cymbal("D:/Audio/VSCO-2-CE/Percussion/cymbal-crash1_ff_rr1.wav", 2 * bar), FX + "rev_cymbal.wav")


def main():
    if not os.path.exists(FX + "hey.wav") or "--fx" in sys.argv:
        make_fx()
    compose()
    sc_song.build("Stampede", WORK, BPM, END_BEAT, notes, OUT_OGG, sampled=SAMPLED, fx_tracks=FX_TRACKS, fx_dir=FX,
                  synths=SYNTHS, reverb={"decay": 1.3, "size": 45, "low_cut": 400}, loudness=-10.0, fade=1.0,
                  master=[("eq_7band", {"high_mid_freq": 3500, "high_mid_gain": 5, "high_shelf_freq": 7000, "high_shelf_gain": 6}),
                          ("compressor", {"threshold": -12, "ratio": 3, "attack": 10, "release": 100, "makeup": 3}),
                          ("maximizer", {"threshold": -10, "ceiling": -1})])


if __name__ == "__main__":
    main()
