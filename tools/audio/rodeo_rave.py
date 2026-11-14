"""„Rodeo Rave”: agresywny hard rave + country, drugi utwór na bossa (na później).

f-moll, 150 BPM, ok. 82 s. Własny utwór w klimacie rosyjskiego hard rave'u
(nie kopia żadnego utworu): przesterowana stopa hardstyle strojona pod akordy,
przesterowany bas rave na offbeatach (w drugim dropie „rolling” szesnastki),
piszczący lead, fiddle i banjo (harfa) grają hoedown, chór okrzyków HEY!/HA!/HOO!
i „YEE-HAW!” robo-kowboja przed dropami. Nagły koniec.

  Intro   (t. 1-8)    banjo i klaskanie, okrzyki; potem stopa, fiddle gra hak, riser, YEE-HAW
  Drop 1  (t. 9-24)   stopa, bas na offbeatach, screech + fiddle, chór
  Break   (t. 25-32)  hoedown: fiddle i banjo, klaskanie; budowanie z chórem HEY HEY HEY
  Drop 2  (t. 33-48)  rolling bas, róg staccato, lead oktawę wyżej, fiddle w harmonii
  Koniec  (t. 49-50)  jedno uderzenie i ostatnie YEE-HAW

Użycie: python tools/audio/rodeo_rave.py
"""
import os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
import fx_synth  # noqa: E402
import sc_song  # noqa: E402
import star_rodeo as sr  # noqa: E402

WORK = "D:/Audio/Sessions/RodeoRave/"
FX = WORK + "fx/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "rodeo_rave.ogg")
BPM = 150
END_BEAT = 48 * 4 + 12
midi = sr.midi

SAMPLED = {
    "fiddle":   dict(glob="Strings/Solo Violin/Arco Vib/*_f.wav", mode="gate", attack=6, release=150, db=3, pan=0.2, send=-14),
    "fid_spic": dict(glob="Strings/Solo Violin/spic/*_v2_rr1.wav", mode="one", attack=1, release=100, db=4, pan=0.2, send=-14),
    "banjo":    dict(glob="Strings/Harp/*_mf.wav", mode="gate", attack=1, release=80, db=4, pan=-0.35, send=-16,
                     inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 200, "high_mid_freq": 3500, "high_mid_gain": 7}),
                              ("saturator", {"drive": 10, "mix": 40})]),
    "horn_st":  dict(glob="Brass/F Horn/stac/*_v3_rr1.wav", mode="one", attack=1, release=180, db=-17, pan=-0.1, send=-10,
                     inserts=[("saturator", {"drive": 6, "mix": 35})]),
}
FX_TRACKS = {
    "kick": dict(file="kick_hs.wav", root=41, pitched=True, db=-9, send=-40, release=60,
                 inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 28, "low_shelf_freq": 70, "low_shelf_gain": 2}),
                          ("compressor", {"threshold": -10, "ratio": 4, "attack": 3, "release": 60, "makeup": 2})]),
    "hey": dict(file="hey.wav", db=-6, send=-10, echo=False, pan=0.0),
    "ha": dict(file="ha.wav", db=-7, send=-10, pan=0.0),
    "hoo": dict(file="hoo.wav", db=-7, send=-8, echo=True),
    "yeehaw": dict(file="yeehaw.wav", db=-8, send=-9, echo=True),
    "yeehaw_low": dict(file="yeehaw_low.wav", db=-9, send=-9, echo=True),
    "riser": dict(file="riser_4bar.wav", db=-17, send=-12),
    "impact": dict(file="impact.wav", db=-9, send=-10),
    "revcym": dict(file="rev_cymbal.wav", db=-12, send=-8),
}
SYNTHS = {
    "bass": dict(plugin="subtractive_synth", db=1, pan=0.0, send=-40, params=dict(
        osc1_wave=0, osc2_wave=0, osc2_semitones=12, osc2_detune=12, osc_mix=35, cutoff=1100, resonance=35,
        filter_env_amount=60, amp_attack=1, amp_decay=140, amp_sustain=40, amp_release=40, filter_attack=1,
        filter_decay=120, filter_sustain=15, filter_release=60, velocity=50, level=-6),
        inserts=[("saturator", dict(drive=22, tone=4500, mix=85, output=-9)), ("eq_7band", dict(hpf_on=1, hpf_freq=45, mid_freq=900, mid_gain=3)),
                 ("compressor", dict(threshold=-16, ratio=6, attack=2, release=60, makeup=4))]),
    "screech": dict(plugin="subtractive_synth", db=1, pan=-0.12, send=-14, params=dict(
        osc1_wave=0, osc2_wave=1, osc2_semitones=12, osc2_detune=9, osc_mix=40, cutoff=2400, resonance=72,
        filter_env_amount=65, amp_attack=1, amp_decay=160, amp_sustain=55, amp_release=90, filter_attack=1,
        filter_decay=130, filter_sustain=35, filter_release=110, glide=25, velocity=45, level=-6),
        inserts=[("saturator", dict(drive=14, tone=9000, mix=60, output=-6)), ("mod_delay", dict(time="dotted8", feedback=22, mix=14, lpf=7000)),
                 ("chorus", dict(mix=25, depth=35))]),
    "pad": dict(plugin="subtractive_synth", db=-9, pan=0.0, send=-8, params=dict(
        osc1_wave=0, osc2_wave=0, osc2_detune=16, osc_mix=50, cutoff=1500, resonance=12, filter_env_amount=15,
        amp_attack=200, amp_decay=500, amp_sustain=85, amp_release=700, filter_attack=300, filter_decay=800,
        filter_sustain=60, filter_release=800, velocity=40, level=-6),
        inserts=[("chorus", dict(mix=45, depth=60, rate=0.5))]),
    "drums": dict(plugin="drum_synth", db=0, pan=0.0, send=-20, params=dict(
        snare_tune=2, snare_snappy=80, snare_decay=160, hat_decay=45, open_hat_decay=260, tom_decay=320, cymbal_decay=2000, level=-6),
        inserts=[("compressor", dict(threshold=-16, ratio=3, attack=6, release=80, makeup=3)), ("saturator", dict(drive=6, mix=40))]),
}
SNARE, CLAP, HAT, OHAT, CRASH = 38, 39, 42, 46, 49
TOMS = [50, 48, 47, 45, 43, 41]

DROP = ["Fm", "Db", "Ab", "Eb"]
BREAK = ["Db", "Ab", "Eb", "Fm"]
TRIAD = {"Fm": [53, 56, 60], "Db": [49, 53, 56], "Ab": [56, 60, 63], "Eb": [51, 55, 58]}
ROOT2 = {"Fm": 41, "Db": 37, "Ab": 44, "Eb": 39}  # bas i strojenie stopy (oktawa 2)
SCALE = [65, 67, 68, 70, 72, 73, 75]  # f-moll naturalny
HOOK = [
    "F5 . F5 F5 Ab5 . F5 - C6 . Bb5 Ab5 F5 - Eb5 F5",
    "F5 . F5 F5 Ab5 . F5 - Db6 . C6 Ab5 F5 - Eb5 Db5",
    "Eb5 . Eb5 Eb5 Ab5 . Eb5 - C6 . Bb5 Ab5 Eb5 - C5 Eb5",
    "Eb5 . Eb5 G5 Bb5 . Eb5 - Bb5 . Ab5 G5 Eb5 - F5 G5",
]
HOEDOWN = [
    "Db5 F5 Ab5 F5 Db5 F5 Ab5 Db6 C6 Ab5 F5 Ab5 Db5 F5 Ab5 F5",
    "C5 Eb5 Ab5 Eb5 C5 Eb5 Ab5 C6 Bb5 Ab5 Eb5 Ab5 C5 Eb5 Ab5 Eb5",
    "Bb4 Eb5 G5 Eb5 Bb4 Eb5 G5 Bb5 Ab5 G5 Eb5 G5 Bb4 Eb5 G5 Eb5",
    "C5 F5 Ab5 F5 C5 F5 Ab5 C6 Bb5 Ab5 G5 F5 Eb5 F5 G5 Ab5",
]

rng = random.Random(23)
notes = {}


def add(inst, pitch, start, dur, vel, human=0.006):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    start += rng.uniform(-human, human) if human else 0
    vel += rng.randint(-4, 4) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def line_notes(line):
    tokens = line.split()
    out = []
    for i, tok in enumerate(tokens):
        if tok in (".", "-"):
            continue
        length = 1
        while i + length < len(tokens) and tokens[i + length] == ".":
            length += 1
        out.append((midi(tok), i * 0.25, length * 0.25))
    return out


def third_below(pitch):
    pcs = [p % 12 for p in SCALE]
    pc = pitch % 12
    if pc not in pcs:
        return pitch - 3
    target = pcs[(pcs.index(pc) - 2) % 7]
    return pitch - (pc - target) % 12


def play(line, bar, fiddle=True, lead=True, fvel=100, lvel=100, octave=0, harmony=False):
    for p, s, d in line_notes(line):
        p += octave
        accent = 14 if s % 1 == 0 else (5 if s % 0.5 == 0 else 0)
        if fiddle:
            fp = third_below(p) if harmony else p
            add("fid_spic" if d <= 0.25 else "fiddle", fp, bar * 4 + s, d * 0.9, fvel + accent)
        if lead:
            add("screech", p, bar * 4 + s, d * 0.88, lvel + accent)


def kick(bar, ch, beats=(0, 1, 2, 3), vel=120):
    for k in beats:
        add("kick", ROOT2[ch], bar * 4 + k, 0.45, vel, 0)


def drop_drums(bar, crash=False, fill=False, hard=False):
    b = bar * 4
    for k in (1, 3):
        add("drums", CLAP, b + k, 0.5, 112)
        add("drums", SNARE, b + k, 0.5, 96)
    for k in range(4):
        add("drums", OHAT, b + k + 0.5, 0.3, 92)
    for k in range(16):
        if k % 4 != 2:
            add("drums", HAT, b + k * 0.25, 0.2, [64, 34, 0, 40][k % 4] + (10 if hard else 0))
    if crash:
        add("drums", CRASH, b, 2, 118, 0)
    if fill:
        for k in range(8):
            add("drums", TOMS[min(k // 2 + 1, 5)], b + 2 + k * 0.25, 0.25, 96 + k * 4)


def rave_bass(bar, ch, rolling=False):
    b = bar * 4
    root = ROOT2[ch]
    for k in range(4):
        if rolling:
            for s in (0.25, 0.5, 0.75):
                add("bass", root, b + k + s, 0.2, 112 if s == 0.5 else 98)
        else:
            add("bass", root, b + k + 0.5, 0.42, 116)
            if k == 3:
                add("bass", root + 12, b + k + 0.75, 0.2, 100)


def banjo_roll(bar, ch, vel=1.0):
    tones = sorted({p + o for p in TRIAD[ch] for o in (12, 24) if 63 <= p + o <= 82})
    # „Piąta struna”: nuta akordu najbliższa C5, żeby bęben nie gryzł się z harmonią.
    drone = min((p + o for p in TRIAD[ch] for o in (12, 24)), key=lambda q: abs(q - 72))
    i_, m_ = tones[-2], tones[-1]
    pattern = [drone, i_, m_, drone, i_, m_, drone, m_]
    for k in range(16):
        add("banjo", pattern[k % 8], bar * 4 + k * 0.25, 0.2, (96 if k % 4 == 0 else 76) * vel)


def pad(bar, ch, vel=66, beats=4):
    for p in TRIAD[ch]:
        add("pad", p + 12, bar * 4, beats * 0.98, vel, 0)


def fx(name, beat, vel=112, pitch=60):
    add(name, pitch, beat, 4, vel, 0)


def compose():
    # Intro
    for bar in range(8):
        ch = DROP[bar % 4]
        banjo_roll(bar, ch, 0.9)
        for k in (1, 3):
            add("drums", CLAP, bar * 4 + k, 0.5, 90 + bar * 3)
        if bar in (1, 3, 5):
            fx("hey", bar * 4 + 3)
        if bar >= 4:
            play(HOOK[bar % 4], bar, fiddle=True, lead=False, fvel=94)
            kick(bar, ch, vel=88 + bar * 4)
            pad(bar, ch, vel=56 + bar * 2)
        if bar >= 6:
            step = 0.5 if bar == 6 else 0.25
            for k in range(int(4 / step)):
                add("drums", SNARE, bar * 4 + k * step, 0.2, 54 + k * (6 if bar == 6 else 4))
    fx("riser", 4 * 4)
    fx("revcym", 6 * 4)
    fx("yeehaw", 7 * 4 + 1.0)

    # Drop 1
    for i in range(16):
        bar = 8 + i
        ch = DROP[i % 4]
        kick(bar, ch)
        rave_bass(bar, ch)
        drop_drums(bar, crash=(i in (0, 8)), fill=(i in (7, 15)))
        play(HOOK[i % 4], bar, fvel=100, lvel=100)
        pad(bar, ch)
        if i % 2 == 0:
            fx("hey", bar * 4 + 3)
        else:
            fx("ha", bar * 4 + 3)
            fx("ha", bar * 4 + 3.5)
    fx("impact", 8 * 4)
    fx("hoo", 23 * 4 + 2)

    # Break: hoedown
    for i in range(8):
        bar = 24 + i
        ch = BREAK[i % 4]
        banjo_roll(bar, ch)
        play(HOEDOWN[i % 4], bar, fiddle=True, lead=False, fvel=96)
        pad(bar, ch, vel=72)
        for k in (1, 3):
            add("drums", CLAP, bar * 4 + k, 0.5, 104)
        if i < 4:
            add("bass", ROOT2[ch] - 12, bar * 4, 3.8, 84, 0)
        else:
            kick(bar, ch, beats=(0, 1, 2, 3) if i < 6 else (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5), vel=96 + i * 3)
        if i == 7:
            for k in range(16):
                add("drums", SNARE, bar * 4 + k * 0.25, 0.2, 60 + k * 4)
        if i == 6:
            for k in range(4):
                fx("hey", bar * 4 + k, 96 + k * 6)
        if i == 7:
            for k in range(6):
                fx("hey", bar * 4 + k * 0.5, 100 + k * 4)
    fx("riser", 28 * 4)
    fx("revcym", 30 * 4)
    fx("yeehaw_low", 31 * 4 + 3.0)

    # Drop 2
    for i in range(16):
        bar = 32 + i
        ch = DROP[i % 4]
        kick(bar, ch, vel=124)
        rave_bass(bar, ch, rolling=True)
        drop_drums(bar, crash=(i % 4 == 0), fill=(i in (7, 15)), hard=True)
        play(HOOK[i % 4], bar, fvel=104, lvel=104, octave=12 if i >= 8 else 0, harmony=True)
        if i >= 8:
            play(HOOK[i % 4], bar, fiddle=True, lead=False, fvel=82)
        pad(bar, ch, vel=70)
        for s in (0, 1.5, 2.5):
            for p in TRIAD[ch]:
                add("horn_st", p + 12, bar * 4 + s, 0.4, 108 if s == 0 else 96)
        fx("hey", bar * 4 + 3)
        if i % 4 == 3:
            fx("ha", bar * 4 + 1.5)
            fx("hoo", bar * 4 + 2)
    fx("impact", 32 * 4)
    fx("yeehaw", 40 * 4 - 1.5)

    # Koniec: jedno uderzenie, cisza, YEE-HAW
    b = 48 * 4
    kick(48, "Fm", beats=(0,), vel=127)
    fx("impact", b)
    add("drums", CRASH, b, 4, 124, 0)
    add("bass", 41, b, 0.9, 120, 0)
    for p in TRIAD["Fm"]:
        add("horn_st", p + 12, b, 0.5, 116, 0)
        add("pad", p + 12, b, 0.9, 90, 0)
    add("screech", 77, b, 0.9, 110, 0)
    add("fiddle", 77, b, 0.9, 110, 0)
    fx("yeehaw", b + 2.0, 118)


def main():
    if not os.path.exists(FX + "kick_hs.wav") or "--fx" in sys.argv:
        os.makedirs(FX, exist_ok=True)
        bar = 4 * 60 / BPM
        fx_synth.save(fx_synth.hardstyle_kick(), FX + "kick_hs.wav")
        # Chór strojony do f-moll: głosy na F3, As3 i C4 (każdy podwójnie, lekko rozstrojony).
        chord = [1.0, 0.841, 1.26, 1.004, 0.838, 1.255]
        fx_synth.save(fx_synth.shout("e", 207.65, 0.30, 6, 4, chord), FX + "hey.wav")
        fx_synth.save(fx_synth.shout("a", 207.65, 0.26, 6, 5, chord), FX + "ha.wav")
        fx_synth.save(fx_synth.shout("o", 174.61, 0.5, 6, 6, [1.0, 1.189, 1.498, 0.997, 1.193, 1.5]), FX + "hoo.wav")
        fx_synth.save(fx_synth.yeehaw(0.95, 1.0, 7), FX + "yeehaw.wav")
        fx_synth.save(fx_synth.yeehaw(0.8, 1.2, 8), FX + "yeehaw_low.wav")
        fx_synth.save(fx_synth.riser(4 * bar), FX + "riser_4bar.wav")
        fx_synth.save(fx_synth.impact(), FX + "impact.wav")
        fx_synth.save(fx_synth.reverse_cymbal("D:/Audio/VSCO-2-CE/Percussion/cymbal-crash1_ff_rr1.wav", 2 * bar), FX + "rev_cymbal.wav")
    compose()
    sc_song.build("Rodeo Rave", WORK, BPM, END_BEAT, notes, OUT_OGG, sampled=SAMPLED, fx_tracks=FX_TRACKS, fx_dir=FX,
                  synths=SYNTHS, reverb={"decay": 1.4, "size": 50}, loudness=-12.5, fade=1.0,
                  master=[("compressor", {"threshold": -14, "ratio": 3, "attack": 10, "release": 120, "makeup": 3}),
                          ("maximizer", {"threshold": -5, "ceiling": -1})])


if __name__ == "__main__":
    main()
