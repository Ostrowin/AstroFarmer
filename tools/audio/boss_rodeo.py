"""„Boss Rodeo”: electro + country, muzyka walki z bossem (na później).

e-moll, 132 BPM, 4/4, ok. 95 s. Składane w SoundCraft jak „Star Rodeo”:
syntezatory SoundCraft (bas, lead, pad, automat perkusyjny) + próbki VSCO 2 CE
(skrzypce ludowe, harfa udająca banjo, róg staccato, kotły) + efekty z fx_synth.py
(okrzyk robo-kowboja „yee-haw”, riser, uderzenie, odwrócony talerz).

  Intro   (t. 1-8)    fiddle sam gra riff, hi-hat, pad; narasta riser, „YEE-HAW!” i...
  Drop A  (t. 9-24)   stopa na każdą ćwierćnutę, klaśnięcia, galopujący przesterowany bas
                      (country „da-dada” wokół stopy), lead i fiddle grają hoedown
  Break   (t. 25-32)  „train beat” na werblu (country), banjo-harfa gra rolle, pad; budowanie
  Drop B  (t. 33-48)  wszystko + róg staccato i kotły, lead w harmonii tercję niżej
  Outro   (t. 49-52)  wielkie uderzenie, okrzyk, ostatni riff z echem, akord

Użycie: python tools/audio/boss_rodeo.py
"""
import os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
import star_rodeo as sr  # noqa: E402  (strefy samplera, SoundCraft, nazwy nut)
import fx_synth  # noqa: E402
import sc_song  # noqa: E402

WORK = "D:/Audio/Sessions/BossRodeo/"
FX = WORK + "fx/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_OGG = os.path.join(ROOT, "audio", "music", "boss_rodeo.ogg")
BPM = 132
PPQ = 960
END_BEAT = 52 * 4 + 8
DELAY_MS = round(60000 / BPM * 0.75)  # ósemka z kropką

midi = sr.midi

# --- Instrumenty --------------------------------------------------------------
SAMPLED = {
    "fiddle":   dict(glob="Strings/Solo Violin/Arco Vib/*_f.wav", mode="gate", attack=8, release=180, db=0, pan=0.15, send=-14),
    "fid_spic": dict(glob="Strings/Solo Violin/spic/*_v2_rr1.wav", mode="one", attack=1, release=120, db=1, pan=0.15, send=-14),
    "banjo":    dict(glob="Strings/Harp/*_mf.wav", mode="gate", attack=1, release=90, db=5, pan=-0.35, send=-16,
                     inserts=[("eq_7band", {"hpf_on": 1, "hpf_freq": 180, "high_mid_freq": 3500, "high_mid_gain": 6}),
                              ("saturator", {"drive": 8, "mix": 35})]),
    "horn_st":  dict(glob="Brass/F Horn/stac/*_v3_rr1.wav", mode="one", attack=1, release=200, db=-13, pan=-0.1, send=-9),
    "timp":     dict(glob="Percussion/Timpani/Timpani*_Hit_v3_rr1*.wav", mode="one", attack=1, release=1200, db=7, pan=0.0, send=-10),
}
FX_TRACKS = {  # nazwa -> plik, dB, wysyłka na pogłos, echo
    "yeehaw": dict(file="yeehaw.wav", db=-7, send=-9, echo=True),
    "yeehaw_low": dict(file="yeehaw_low.wav", db=-8, send=-9, echo=True),
    "yeehaw_short": dict(file="yeehaw_short.wav", db=-9, send=-10, echo=True),
    "riser4": dict(file="riser_4bar.wav", db=-17, send=-12, echo=False),
    "riser2": dict(file="riser_2bar.wav", db=-17, send=-12, echo=False),
    "impact": dict(file="impact.wav", db=-9, send=-10, echo=False),
    "revcym": dict(file="rev_cymbal.wav", db=-12, send=-8, echo=False),
}
SYNTHS = {
    "bass": dict(plugin="subtractive_synth", db=-1, pan=0.0, send=-30, params=dict(
        osc1_wave=0, osc2_wave=1, osc2_semitones=-12, osc2_detune=0, osc_mix=35, cutoff=900, resonance=30,
        filter_env_amount=55, amp_attack=1, amp_decay=180, amp_sustain=55, amp_release=60, filter_attack=1,
        filter_decay=160, filter_sustain=20, filter_release=80, glide=0, velocity=60, level=-6),
        inserts=[("saturator", dict(drive=14, tone=5500, mix=70, output=-6)), ("eq_7band", dict(hpf_on=1, hpf_freq=32, low_mid_freq=300, low_mid_gain=-3)),
                 ("compressor", dict(threshold=-18, ratio=4, attack=5, release=80, makeup=4))]),
    "lead": dict(plugin="subtractive_synth", db=-1, pan=-0.1, send=-14, params=dict(
        osc1_wave=1, osc2_wave=0, osc2_semitones=0, osc2_detune=10, osc_mix=45, cutoff=3800, resonance=25,
        filter_env_amount=35, amp_attack=2, amp_decay=220, amp_sustain=60, amp_release=120, filter_attack=1,
        filter_decay=200, filter_sustain=40, filter_release=150, glide=12, velocity=50, level=-6),
        inserts=[("mod_delay", dict(time=DELAY_MS, feedback=28, mix=18, lpf=6000)), ("chorus", dict(mix=25, depth=40))]),
    "pad": dict(plugin="subtractive_synth", db=-10, pan=0.0, send=-8, params=dict(
        osc1_wave=0, osc2_wave=0, osc2_semitones=0, osc2_detune=14, osc_mix=50, cutoff=1700, resonance=10,
        filter_env_amount=15, amp_attack=260, amp_decay=600, amp_sustain=85, amp_release=900, filter_attack=400,
        filter_decay=900, filter_sustain=60, filter_release=900, velocity=40, level=-6),
        inserts=[("chorus", dict(mix=45, depth=60, rate=0.4))]),
    "drums": dict(plugin="drum_synth", db=-1, pan=0.0, send=-22, params=dict(
        kick_tune=-2, kick_decay=380, snare_tune=1, snare_snappy=70, snare_decay=180, hat_decay=55, open_hat_decay=320,
        tom_decay=380, cymbal_decay=2200, level=-6),
        inserts=[("compressor", dict(threshold=-16, ratio=3, attack=8, release=90, makeup=3)), ("saturator", dict(drive=4, mix=40))]),
}
KICK, SNARE, CLAP, HAT, OHAT, CRASH = 36, 38, 39, 42, 46, 49
TOMS = [50, 48, 47, 45, 43, 41]

# --- Harmonia i riff ------------------------------------------------------------
DROP = ["Em", "C", "G", "D"]
BREAK = ["Am", "Em", "C", "D"]
TRIAD = {"Em": [52, 55, 59], "C": [48, 52, 55], "G": [55, 59, 62], "D": [50, 54, 57], "Am": [57, 60, 64]}
BASS = {"Em": 40, "C": 36, "G": 43, "D": 38, "Am": 45}
RIFF = [  # szesnastki: nuta, "." = trzymaj, "-" = pauza
    "E5 - E5 B4 E5 G5 A5 G5 E5 - D5 B4 D5 E5 - -",
    "C5 - C5 G4 C5 E5 G5 E5 C5 - B4 G4 B4 C5 - -",
    "D5 - D5 B4 D5 G5 B5 G5 D5 - B4 G4 A4 B4 - -",
    "F#5 - F#5 D5 F#5 A5 B5 A5 F#5 E5 D5 B4 A4 B4 D5 E5",
    "G5 F#5 E5 D5 E5 - B4 - E5 F#5 G5 A5 B5 - A5 G5",
    "E5 D5 C5 B4 C5 - G4 - C5 D5 E5 G5 A5 - G5 E5",
    "D5 C5 B4 A4 B4 - G4 - B4 C5 D5 E5 G5 - A5 B5",
    "A5 - F#5 - D5 - A4 - D5 E5 F#5 A5 B5 . . .",
]
SCALE = [64, 66, 67, 69, 71, 72, 74]  # e-moll naturalny (stopnie od E4)

rng = random.Random(11)
notes = {}  # instrument -> [(pitch, start, dur, vel)]


def add(inst, pitch, start, dur, vel, human=0.008):
    if isinstance(pitch, str):
        pitch = midi(pitch)
    start += rng.uniform(-human, human) if human else 0
    vel += rng.randint(-4, 4) if human else 0
    notes.setdefault(inst, []).append((pitch, max(0.0, start), dur, int(max(15, min(127, vel)))))


def riff_notes(bar_riff):
    """Riff jednego taktu -> [(nuta, start, długość)] w beatach."""
    tokens = bar_riff.split()
    out = []
    for i, tok in enumerate(tokens):
        if tok in (".", "-"):
            continue
        length = 1
        while i + length < len(tokens) and tokens[i + length] == ".":
            length += 1
        out.append((midi(tok), i * 0.25, length * 0.25))
    return out


def diatonic_down(pitch, steps=2):
    """Ta sama nuta przesunięta o `steps` stopni gamy e-moll w dół (tercja = 2)."""
    pcs = [p % 12 for p in SCALE]
    pc = pitch % 12
    if pc not in pcs:
        return pitch - 3
    idx = pcs.index(pc)
    target = pcs[(idx - steps) % 7]
    diff = (pc - target) % 12
    return pitch - diff


def play_riff(bar, phrase_bar, fiddle_vel=100, lead=True, lead_harmony=False, lead_vel=96, fiddle=True, octave=0):
    for p, s, d in riff_notes(RIFF[phrase_bar % 8]):
        p += octave
        accent = 14 if s % 1 == 0 else (6 if s % 0.5 == 0 else 0)
        if fiddle:
            add("fid_spic" if d <= 0.25 else "fiddle", p, bar * 4 + s, d * 0.92, fiddle_vel + accent)
        if lead:
            lp = diatonic_down(p) if lead_harmony else p
            add("lead", lp, bar * 4 + s, d * 0.9, lead_vel + accent)


def drop_drums(bar, energy=1, fill=False, crash=False):
    b = bar * 4
    for k in range(4):
        add("drums", KICK, b + k, 0.5, 118, 0)
    for k in (1, 3):
        add("drums", CLAP, b + k, 0.5, 104)
        add("drums", SNARE, b + k, 0.5, 92)
    for k in range(16):
        pos = b + k * 0.25
        if energy >= 2 and k % 4 == 2:
            add("drums", OHAT, pos, 0.25, 84)
        else:
            add("drums", HAT, pos, 0.25, [74, 38, 88, 42][k % 4])
    if crash:
        add("drums", CRASH, b, 2, 112, 0)
    if fill:
        for k in range(8):
            add("drums", TOMS[min(k // 2 + 1, 5)], b + 2 + k * 0.25, 0.25, 90 + k * 4)


def gallop_bass(bar, ch, octave_jump=True):
    b = bar * 4
    root = BASS[ch]
    for k in range(4):
        add("bass", root, b + k + 0.5, 0.22, 104)
        add("bass", root + (12 if (octave_jump and k == 3) else 0), b + k + 0.75, 0.2, 96)


def pad(bar, ch, beats=4, vel=70, up=12):
    for p in TRIAD[ch]:
        add("pad", p + up, bar * 4, beats * 0.98, vel, 0)


def banjo_roll(bar, ch):
    tones = sorted({p + o for p in TRIAD[ch] for o in (12, 24) if 64 <= p + o <= 81})
    drone = 71  # „piąta struna”: wysokie B
    i_, m_ = tones[-2], tones[-1]
    pattern = [drone, i_, m_, drone, i_, m_, drone, m_]
    for k in range(16):
        add("banjo", pattern[k % 8], bar * 4 + k * 0.25, 0.22, 92 if k % 4 == 0 else 74)


def train_beat(bar, vel=1.0):
    for k in range(16):
        accent = k in (4, 12)
        add("drums", SNARE, bar * 4 + k * 0.25, 0.2, (104 if accent else 46 + (10 if k % 2 == 0 else 0)) * vel)


def fx(name, beat):
    add(name, 60, beat, 4, 110, 0)


def compose():
    # Intro (t. 1-8)
    for bar in range(8):
        ch = DROP[bar % 4]
        pad(bar, ch, vel=58 + bar * 3)
        play_riff(bar, bar, fiddle_vel=88, lead=False)
        for k in range(8):
            add("drums", HAT, bar * 4 + k * 0.5, 0.25, 50 + bar * 4)
        if bar >= 4:
            add("drums", KICK, bar * 4, 0.5, 70 + bar * 5, 0)
            add("drums", KICK, bar * 4 + 2, 0.5, 70 + bar * 5, 0)
        if bar >= 6:
            for k in range(8 if bar == 6 else 16):
                step = 0.5 if bar == 6 else 0.25
                add("drums", SNARE, bar * 4 + k * step, 0.2, 50 + k * (4 if bar == 6 else 4))
    fx("riser4", 4 * 4)
    fx("revcym", 6 * 4)
    fx("yeehaw", 7 * 4 + 1.0)

    # Drop A (t. 9-24)
    for i in range(16):
        bar = 8 + i
        ch = DROP[i % 4]
        play_riff(bar, i, fiddle_vel=100, lead=True, lead_vel=92, octave=12 if i >= 8 else 0)
        gallop_bass(bar, ch)
        pad(bar, ch, vel=64)
        drop_drums(bar, energy=1 if i < 8 else 2, fill=(i in (7, 15)), crash=(i in (0, 8)))
    fx("impact", 8 * 4)
    fx("yeehaw_short", 15 * 4 + 2.5)
    fx("riser2", 22 * 4)

    # Break (t. 25-32): train beat i banjo
    for i in range(8):
        bar = 24 + i
        ch = BREAK[i % 4]
        banjo_roll(bar, ch)
        pad(bar, ch, vel=72)
        add("bass", BASS[ch] - 12, bar * 4, 3.8, 90, 0)
        train_beat(bar, 0.85 if i < 4 else 1.0)
        if i >= 4:
            for k in range(4 if i < 7 else 8):
                add("drums", KICK, bar * 4 + k * (1 if i < 7 else 0.5), 0.4, 90 + i * 3, 0)
        if i >= 6:  # fiddle wraca: frazy riffu do akordów C i D
            play_riff(bar, 5 if ch == "C" else 7, fiddle_vel=92, lead=False)
    fx("riser4", 28 * 4)
    fx("revcym", 30 * 4)
    fx("yeehaw_low", 31 * 4 + 0.5)

    # Drop B (t. 33-48): + róg, kotły, lead w harmonii
    for i in range(16):
        bar = 32 + i
        ch = DROP[i % 4]
        play_riff(bar, (i + 4) % 8 if i < 8 else i, fiddle_vel=104, lead=True, lead_harmony=True, lead_vel=94)
        gallop_bass(bar, ch)
        pad(bar, ch, vel=70)
        drop_drums(bar, energy=2, fill=(i in (7, 15)), crash=(i in (0, 8)))
        for s in (0, 1.5, 2.5):
            for p in TRIAD[ch]:
                add("horn_st", p + 12, bar * 4 + s, 0.4, 104 if s == 0 else 92)
        add("timp", BASS[ch] + 12 if BASS[ch] < 40 else BASS[ch], bar * 4, 1, 110, 0)
        if i % 4 == 3:
            add("timp", BASS[ch], bar * 4 + 3, 0.5, 96, 0)
            add("timp", BASS[ch], bar * 4 + 3.5, 0.5, 104, 0)
    fx("impact", 32 * 4)
    fx("yeehaw_short", 39 * 4 + 2.5)
    fx("riser2", 46 * 4)

    # Outro (t. 49-52)
    b = 48 * 4
    fx("impact", b)
    fx("yeehaw", b + 0.5)
    add("drums", CRASH, b, 4, 120, 0)
    add("drums", KICK, b, 0.5, 124, 0)
    add("bass", 40, b, 3.5, 110, 0)
    pad(48, "Em", beats=8, vel=80)
    for p in TRIAD["Em"]:
        add("horn_st", p + 12, b, 0.5, 112, 0)
    add("timp", 40, b, 1, 120, 0)
    play_riff(49, 4, fiddle_vel=96, lead=False)
    play_riff(50, 5, fiddle_vel=92, lead=True, lead_vel=80)
    pad(50, "C", vel=74)
    end = 51 * 4
    for inst, ps in (("horn_st", [64, 67, 71]), ("fiddle", [76]), ("lead", [64, 76]), ("pad", [64, 67, 71, 76])):
        for p in ps:
            add(inst, p, end, 1.5, 116, 0)
    add("bass", 40, end, 1.5, 120, 0)
    add("drums", KICK, end, 0.5, 127, 0)
    add("drums", CRASH, end, 4, 124, 0)
    add("timp", 40, end, 1, 124, 0)
    fx("impact", end)


def main():
    if not os.path.exists(FX + "yeehaw.wav"):
        fx_synth.main(FX)
    compose()
    sc_song.build("Boss Rodeo", WORK, BPM, END_BEAT, notes, OUT_OGG, sampled=SAMPLED, fx_tracks=FX_TRACKS, fx_dir=FX,
                  synths=SYNTHS, loudness=-14.0)


if __name__ == "__main__":
    main()
