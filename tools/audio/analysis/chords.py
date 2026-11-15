"""Zgodność harmonii z planem akordów, takt po takcie (chroma), plus spektrogram PNG.

Użycie:
  python chords.py plik.wav BPM "G G Em Em C Am D D G G ..." [spektrogram.png]
Akordy: dur (G, Bb, F#) albo moll (Em, F#m). Zgodność = udział energii w dźwiękach
akordu (0..1). Dla akustycznej muzyki ok. 0,8-0,95; dla electro z szumem perkusji
ok. 0,6. Takty z gwałtownym spadkiem warto odsłuchać/sprawdzić nuty.
"""
import struct, subprocess, sys, zlib
import numpy as np

NAMES = "C C# D D# E F F# G G# A A# B".split()
FLAT = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}


def triad(name):
    minor = name.endswith("m")
    root = name[:-1] if minor else name
    root = FLAT.get(root, root)
    r = NAMES.index(root)
    return [r, (r + (3 if minor else 4)) % 12, (r + 7) % 12]


def main():
    wav, bpm, plan = sys.argv[1], float(sys.argv[2]), sys.argv[3].split()
    png = sys.argv[4] if len(sys.argv) > 4 else None
    SR = 22050
    x = np.frombuffer(subprocess.run(["ffmpeg", "-v", "error", "-i", wav, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                                     capture_output=True).stdout, dtype=np.float32)
    bar = 4 * 60 / bpm
    total = 0
    print("takt  rms_dB  akord  chroma-top3      zgodność")
    for b, ch in enumerate(plan):
        seg = x[int(b * bar * SR): int((b + 1) * bar * SR)]
        if len(seg) < 1000:
            break
        n = 1 << 15
        spec = np.abs(np.fft.rfft(seg[:n] * np.hanning(min(len(seg), n)), n))
        f = np.fft.rfftfreq(n, 1 / SR)
        sel = (f > 60) & (f < 2000)
        chroma = np.zeros(12)
        np.add.at(chroma, np.round(12 * np.log2(f[sel] / 440.0) + 69).astype(int) % 12, spec[sel] ** 2)
        chroma /= chroma.sum() + 1e-12
        match = chroma[triad(ch)].sum()
        total += match
        top = " ".join(NAMES[t] for t in np.argsort(chroma)[::-1][:3])
        rms = 20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-9)
        print(f"{b + 1:4d}  {rms:6.1f}  {ch:5s}  {top:15s}  {match:5.2f}")
    print(f"średnia zgodność: {total / max(1, len(plan)):.2f}")
    if png:
        spectrogram(x, SR, bar, png)


def spectrogram(x, SR, bar, png, W=1600):
    hop, win = 512, 2048
    frames = (len(x) - win) // hop
    S = np.zeros((256, frames))
    w = np.hanning(win)
    fr = np.fft.rfftfreq(win, 1 / SR)[:1024]
    for i in range(frames):
        S[:, i] = np.interp(np.geomspace(40, 8000, 256), fr, np.abs(np.fft.rfft(x[i * hop: i * hop + win] * w))[:1024])
    S = 20 * np.log10(S + 1e-6)
    S = np.clip((S - (S.max() - 70)) / 70, 0, 1)[::-1]
    img = np.array([np.interp(np.linspace(0, frames - 1, W), np.arange(frames), row) for row in S])
    rgb = (np.clip(np.stack([img ** 0.6, img ** 1.2, (1 - img) * 0.35 + img ** 3], -1), 0, 1) * 255).astype(np.uint8)
    for b in range(int(len(x) / SR / bar) + 1):  # linie taktów (co 8 jaśniejsze)
        xp = int(b * bar / (len(x) / SR) * W)
        if xp < W:
            rgb[:, xp] = [255, 255, 255] if b % 8 == 0 else [90, 90, 90]
    h, wd = rgb.shape[:2]
    raw = b"".join(b"\x00" + rgb[r].tobytes() for r in range(h))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(png, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", wd, h, 8, 2, 0, 0, 0)) +
                          chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    print("spektrogram:", png)


if __name__ == "__main__":
    main()
