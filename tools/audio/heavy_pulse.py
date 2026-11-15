"""„Heavy Pulse”: prawie sam rytm. 60 BPM, mocny elektroniczny beat, głęboki bas 808.

f-moll, 60 BPM (beat = 1 s), ok. 100 s. Melodii prawie nie ma: ciemny akord-tło
raz na kilka taktów. Rytm niosą: krótka stopa + bas 808 (F1 ok. 44 Hz, z saturacją),
klaśnięcie z werblem na 2 i 4, trapowe hi-haty w szesnastkach z przebiegami 32-kami
i triolami (gęsty rytm mimo wolnego tempa) oraz akustyczna perkusja VSCO 2 CE:
wielki bęben orkiestrowy, kongi, tumba, klawesy, kowadło.

  Wejście   (t. 1-4)    „bicie serca”: podwójna stopa i 808, rzadkie hi-haty
  Groove A  (t. 5-12)   pełny rytm: stopa+808 synkopowane, hi-haty z przebiegami, kongi
  Przerwa   (t. 13-16)  bez hi-hatów: 808, wielki bęben, klaśnięcia, napięcie
  Groove B  (t. 17-24)  jak A + kłody, kowadło, triole, 808 z oktawami
  Koniec    (t. 25)     uderzenie i ogon 808

Użycie: python tools/audio/heavy_pulse.py
"""
import os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
import fx_synth  # noqa: E402
import sc_song  # noqa: E402
import star_rodeo as sr  # noqa: E402

WORK = "D:/Audio/Sessions/HeavyPulse/"
FX = WORK + "fx/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "heavy_pulse.ogg")
BPM = 60
END_BEAT = 25 * 4 + 4
midi = sr.midi


def perc(glob, note, db, pan, send=-18, release=400, level=0):
    """Perkusja VSCO: próbki są ciche, więc poza suwakiem (max +12 dB) podnosimy poziom w samplerze
    i zmniejszamy czułość na siłę uderzenia."""
    return dict(glob=glob, mode="one", pitched=False, note=note, attack=1, release=release, db=db, pan=pan, send=send,
                vel_sens=35, sampler={"level": level})


SAMPLED = {
    "bdrum": perc("Percussion/BDrumNewhit_v6_rr1*.wav", 35, 3, 0.0, -10, 2000),
    "conga": perc("Percussion/Conga-HitN_v2_rr1*.wav", 63, 12, 0.35, level=4),
    "tumba": perc("Percussion/Tumba-HitN_v2_rr1*.wav", 64, 12, -0.3, level=4),
    "quinto": perc("Percussion/Quinto-HitN_v2_rr1*.wav", 62, 12, 0.5, level=2),
    "claves": perc("Percussion/Claves1_Hit_v2_rr1*.wav", 75, 12, -0.45, level=7),
    "anvil": perc("Percussion/Anvil_Hit1_v2*.wav", 81, 12, 0.2, -12, 900),
    "logdrum": perc("Percussion/LogDrumLo_MedM_v2_rr1*.wav", 66, 12, -0.15, level=3),
}
FX_TRACKS = {
    "kick": dict(file="kick.wav", db=-4, send=-60, release=40),
    "b808": dict(file="bass_808.wav", root=29, pitched=True, db=-3, send=-60, release=90, mode="gate",
                 inserts=[("compressor", {"threshold": -14, "ratio": 3, "attack": 10, "release": 200, "makeup": 2})]),
    "impact": dict(file="impact.wav", db=-8, send=-12),
    "riser": dict(file="riser.wav", db=-15, send=-12),
}
SYNTHS = {
    "pad": dict(plugin="subtractive_synth", db=-4, pan=0.0, send=-6, params=dict(
        osc1_wave=0, osc2_wave=0, osc2_detune=12, osc_mix=50, cutoff=700, resonance=15, filter_env_amount=25,
        amp_attack=1500, amp_decay=2000, amp_sustain=70, amp_release=2500, filter_attack=2000, filter_decay=3000,
        filter_sustain=40, filter_release=2500, velocity=30, level=-6),
        inserts=[("chorus", dict(mix=40, depth=50, rate=0.2))]),
    "drums": dict(plugin="drum_synth", db=8, pan=0.0, send=-24, params=dict(
        snare_tune=0, snare_snappy=80, snare_decay=200, hat_decay=48, open_hat_decay=220, tom_tune=-4, tom_decay=450,
        cymbal_decay=2500, level=-6),
        inserts=[("eq_7band", dict(hpf_on=1, hpf_freq=120, high_shelf_freq=8000, high_shelf_gain=3)),
                 ("compressor", dict(threshold=-14, ratio=3, attack=4, release=80, makeup=2))]),
}
SNARE, CLAP, HAT, OHAT, CRASH = 38, 39, 42, 46, 49
TOMS = [50, 48, 47, 45, 43, 41]

# 808 i stopa: kroki szesnastkowe w takcie (16 kroków = 4 s) i nuty 808
KICK_A = [0, 6, 10, 11]
KICK_B = [0, 3, 6, 10, 13]
BASS_NOTES = [["F1", "F1", "Ab1", "Ab1"], ["Eb1", "Eb1", "F1", "C2"], ["F1", "F1", "Ab1", "Bb1"], ["Db1", "Db1", "Eb1", "F1"]]
PAD = {0: [53, 56, 60], 1: [51, 55, 58], 2: [53, 56, 60], 3: [49, 53, 56]}  # Fm, Eb, Fm, Db

rng = random.Random(60)
notes = {}


def add(inst, pitch, start, dur, vel, human=0.004):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    start += rng.uniform(-human, human) if human else 0
    vel += rng.randint(-4, 4) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def step(bar, s):
    return bar * 4 + s * 0.25


def kick_808(bar, steps, var, octave=False):
    names = BASS_NOTES[var % 4]
    for i, s in enumerate(steps):
        nxt = steps[i + 1] if i + 1 < len(steps) else 16
        p = midi(names[min(i, 3)]) + (12 if octave and i == len(steps) - 1 else 0)
        add("kick", 60, step(bar, s), 0.3, 124 if s == 0 else 110, 0)
        # 808 trzyma najwyżej 3 szesnastki: niski bas pulsuje z rytmem zamiast buczeć ciągle
        add("b808", p, step(bar, s), min(nxt - s, 3) * 0.25 * 0.9, 118, 0)


def hats(bar, roll=True, triplets=False, sparse=False):
    if sparse:
        for s in (2, 6, 10, 14):
            add("drums", HAT, step(bar, s), 0.2, 70)
        return
    for s in range(16):
        if roll and s in (14, 15) and bar % 2 == 1:
            continue
        add("drums", OHAT if s == 10 and bar % 2 == 0 else HAT, step(bar, s), 0.2, [118, 88, 106, 92][s % 4])
    if roll and bar % 2 == 1:
        if triplets:  # triole szesnastkowe przez ostatni beat
            for k in range(6):
                add("drums", HAT, bar * 4 + 3 + k / 6, 0.1, 60 + k * 8)
        else:  # 32-ki przez ostatnie pół beatu
            for k in range(4):
                add("drums", HAT, bar * 4 + 3.5 + k * 0.125, 0.1, 64 + k * 10)


def backbeat(bar):
    for s in (4, 12):
        add("drums", CLAP, step(bar, s), 0.4, 124, 0)
        add("drums", SNARE, step(bar, s), 0.4, 104, 0)


def congas(bar, busy=False):
    pattern = [("conga", 3), ("tumba", 7), ("conga", 9), ("quinto", 13)] + ([("quinto", 5), ("tumba", 15)] if busy else [])
    for inst, s in pattern:
        add(inst, SAMPLED[inst]["note"], step(bar, s), 0.3, 92 if s % 4 == 3 else 80)
    for s in (7, 15):
        add("claves", 75, step(bar, s), 0.2, 78)


def fx(name, b, vel=112, pitch=60):
    add(name, pitch, b, 4, vel, 0)


def compose():
    # Wejście: bicie serca
    for bar in range(4):
        for b in range(4):
            add("kick", 60, bar * 4 + b, 0.3, 100 + bar * 6, 0)
            add("kick", 60, bar * 4 + b + 0.25, 0.3, 80 + bar * 6, 0)
        add("b808", 29, bar * 4, 3.8, 96 + bar * 6, 0)
        hats(bar, sparse=True)
        if bar == 3:
            for k in range(8):
                add("drums", TOMS[min(k // 2 + 1, 5)], bar * 4 + 2 + k * 0.25, 0.25, 90 + k * 4)
    fx("riser", 2 * 4)
    for p in PAD[0]:
        add("pad", p, 0, 15.5, 70, 0)

    # Groove A
    for i in range(8):
        bar = 4 + i
        kick_808(bar, KICK_A, i)
        backbeat(bar)
        hats(bar)
        congas(bar)
        if i % 4 == 0:
            for p in PAD[(i // 4) % 4]:
                add("pad", p, bar * 4, 15.5, 72, 0)
            add("bdrum", 35, bar * 4, 2, 120, 0)
            add("drums", CRASH, bar * 4, 2, 88, 0)
    fx("impact", 4 * 4)

    # Przerwa: 808, wielki bęben, klaśnięcia
    for i in range(4):
        bar = 12 + i
        add("b808", midi(BASS_NOTES[i][0]), bar * 4, 3.8, 120, 0)
        add("bdrum", 35, bar * 4, 2, 118, 0)
        add("bdrum", 35, bar * 4 + 2.5, 2, 100, 0)
        backbeat(bar)
        for s in (2, 6, 10, 14):
            add("claves", 75, step(bar, s), 0.2, 70)
        if i == 3:
            for k in range(16):
                add("drums", SNARE, bar * 4 + k * 0.25, 0.2, 60 + k * 4)
    for p in PAD[3]:
        add("pad", p, 12 * 4, 15.5, 76, 0)
    fx("riser", 14 * 4)

    # Groove B
    for i in range(8):
        bar = 16 + i
        kick_808(bar, KICK_B, i, octave=(i % 2 == 1))
        backbeat(bar)
        hats(bar, triplets=(i % 4 == 3))
        congas(bar, busy=True)
        for s in (1, 9):
            add("logdrum", 66, step(bar, s), 0.3, 90)
        if i % 2 == 0:
            add("anvil", 81, step(bar, 14), 0.5, 96)
        if i % 4 == 0:
            for p in PAD[(i // 4 + 2) % 4]:
                add("pad", p, bar * 4, 15.5, 74, 0)
            add("bdrum", 35, bar * 4, 2, 124, 0)
            add("drums", CRASH, bar * 4, 2, 92, 0)
        if i == 7:
            for k in range(8):
                add("drums", TOMS[min(k // 2 + 1, 5)], bar * 4 + 2 + k * 0.25, 0.25, 96 + k * 4)
    fx("impact", 16 * 4)

    # Koniec
    b = 24 * 4
    fx("impact", b)
    add("kick", 60, b, 0.3, 127, 0)
    add("b808", 29, b, 3.5, 124, 0)
    add("bdrum", 35, b, 2, 127, 0)
    add("drums", CRASH, b, 4, 124, 0)
    add("drums", CLAP, b, 0.4, 127, 0)


def make_fx():
    os.makedirs(FX, exist_ok=True)
    fx_synth.save(fx_synth.bass_808(), FX + "bass_808.wav")
    fx_synth.save(fx_synth.sub_kick(tail_hz=52, length=0.3, hold=0.4, grit=0.45), FX + "kick.wav")
    fx_synth.save(fx_synth.impact(), FX + "impact.wav")
    fx_synth.save(fx_synth.riser(8.0), FX + "riser.wav")


def main():
    if not os.path.exists(FX + "riser.wav") or "--fx" in sys.argv:
        make_fx()
    compose()
    sc_song.build("Heavy Pulse", WORK, BPM, END_BEAT, notes, OUT_OGG, sampled=SAMPLED, fx_tracks=FX_TRACKS, fx_dir=FX,
                  synths=SYNTHS, reverb={"decay": 1.6, "size": 55, "low_cut": 300}, loudness=-11.0, fade=1.5,
                  master=[("compressor", {"threshold": -10, "ratio": 2, "attack": 25, "release": 200, "makeup": 1}),
                          ("maximizer", {"threshold": -3, "ceiling": -1})])


if __name__ == "__main__":
    main()
