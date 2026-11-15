"""Analiza utworu-odniesienia: tempo, tonacja, głośność, pasma, energia w czasie, stopa, bas.
Bez transkrypcji melodii (bierzemy tylko proporcje brzmienia, nie motywy).

Użycie:
  PYTHONIOENCODING=utf-8 python reference.py plik [plik2 ...]       (pełna analiza)
  PYTHONIOENCODING=utf-8 python reference.py --rhythm plik [...]      (siatka uderzeń)
Zmienne: BPM_RANGE="100,190" (zakres szukania tempa; inaczej łapie połowę/dwukrotność),
BPM_FIXED=144 (dokładne tempo dla siatki rytmu, tylko dla własnych utworów).
Na Windows bez PYTHONIOENCODING=utf-8 wywraca się na znakach ▁..█.
"""
import subprocess, sys
import numpy as np

SR = 22050
import os
LIMITS = tuple(float(v) for v in os.environ.get("BPM_RANGE", "100,190").split(","))


def load(path, ch=1):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, ch)


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))


def envelope(x, hop=256):
    n = len(x) // hop
    return np.sqrt(np.mean(x[: n * hop].reshape(n, hop) ** 2, axis=1)), SR / hop


def tempo(x):
    env, fr = envelope(band(x, 30, 150))
    onset = np.maximum(0, np.diff(env))
    ac = np.correlate(onset - onset.mean(), onset - onset.mean(), "full")[len(onset) - 1:]
    lags = np.arange(len(ac)) / fr
    sel = (lags > 60 / LIMITS[1]) & (lags < 60 / LIMITS[0])
    lag = lags[sel][np.argmax(ac[sel])]
    return 60 / lag, onset, fr


KS_MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KS_MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
NAMES = "C C# D D# E F F# G G# A A# B".split()


def key(x):
    chroma = np.zeros(12)
    win = 1 << 14
    for i in range(0, len(x) - win, win):
        sp = np.abs(np.fft.rfft(x[i:i + win] * np.hanning(win)))
        f = np.fft.rfftfreq(win, 1 / SR)
        sel = (f > 60) & (f < 2000)
        np.add.at(chroma, np.round(12 * np.log2(f[sel] / 440) + 69).astype(int) % 12, sp[sel] ** 2)
    chroma /= chroma.sum()
    best = max(((np.corrcoef(np.roll(prof, k), chroma)[0, 1], NAMES[k] + (" dur" if prof is KS_MAJ else " moll"))
                for prof in (KS_MAJ, KS_MIN) for k in range(12)))
    return best, chroma


def lufs(path):
    out = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    get = lambda tag: [l for l in out.splitlines() if tag in l][-1].split(":")[1].strip()
    return get("I:"), get("LRA:"), get("Peak:")


def analyze(path):
    st = load(path, 2)
    x = st.mean(axis=1)
    dur = len(x) / SR
    print(f"\n=== {path.replace(chr(92), '/').split('/')[-1]}  ({dur:.1f} s)")
    bpm, onset, fr = tempo(x)
    print(f"Tempo: ~{bpm:.1f} BPM")
    (corr, k), chroma = key(x)
    print(f"Tonacja: {k} (dopasowanie {corr:.2f}); najsilniejsze klasy: {', '.join(NAMES[i] for i in np.argsort(chroma)[::-1][:5])}")
    I, LRA, peak = lufs(path)
    rms = np.sqrt(np.mean(x ** 2)); crest = 20 * np.log10(np.max(np.abs(x)) / rms)
    print(f"Głośność: {I}, zakres LRA {LRA}, szczyt {peak}, crest factor {crest:.1f} dB")
    side = (st[:, 0] - st[:, 1]) / 2; mid = (st[:, 0] + st[:, 1]) / 2
    print(f"Szerokość stereo (side/mid): {20 * np.log10(np.sqrt(np.mean(side ** 2)) / np.sqrt(np.mean(mid ** 2))):.1f} dB")
    # Barwa: udział pasm
    sp = np.abs(np.fft.rfft(x)) ** 2; f = np.fft.rfftfreq(len(x), 1 / SR)
    bands = [("sub 20-60", 20, 60), ("bas 60-150", 60, 150), ("niski środek 150-500", 150, 500), ("środek 500-2k", 500, 2000),
             ("wyższy środek 2-5k", 2000, 5000), ("góra 5-11k", 5000, 11000)]
    tot = sp.sum()
    print("Pasma: " + ", ".join(f"{n} {10 * np.log10(sp[(f >= a) & (f < b)].sum() / tot):.1f} dB" for n, a, b in bands))
    # Energia w czasie (co takt)
    bar = 4 * 60 / bpm
    nb = int(dur / bar)
    lows = band(x, 30, 150); highs = band(x, 2000, 10000)
    rows = []
    for i in range(nb):
        s, e = int(i * bar * SR), int((i + 1) * bar * SR)
        rows.append((20 * np.log10(np.sqrt(np.mean(x[s:e] ** 2)) + 1e-9), 20 * np.log10(np.sqrt(np.mean(lows[s:e] ** 2)) + 1e-9),
                     20 * np.log10(np.sqrt(np.mean(highs[s:e] ** 2)) + 1e-9)))
    rows = np.array(rows)
    print(f"Energia co takt ({nb} taktów; ▁..█ = cicho..głośno; L = dół 30-150 Hz):")
    blocks = "▁▂▃▄▅▆▇█"
    def spark(v):
        v = (v - v.min()) / (np.ptp(v) + 1e-9)
        return "".join(blocks[int(min(7, q * 8))] for q in v)
    print("  całość: " + spark(rows[:, 0]))
    print("  dół:    " + spark(rows[:, 1]))
    print("  góra:   " + spark(rows[:, 2]))
    # Stopa: średni kształt uderzenia z taktów o dużej energii dołu
    env, efr = envelope(band(x, 30, 150), 64)
    beat = 60 / bpm
    loud_bars = np.argsort(rows[:, 1])[-max(4, nb // 3):]
    hits = []
    for b_ in loud_bars:
        for k in range(4):
            t0 = b_ * bar + k * beat
            i0 = int(t0 * efr); i1 = int((t0 + beat * 0.3) * efr)
            if i1 < len(env):
                j = i0 + int(np.argmax(np.diff(env[i0:i1 + 1]) if i1 > i0 else 0))
                hits.append(j / efr)
    # wyrównaj i uśrednij
    L = int(beat * SR)
    stack = []
    for t in hits:
        s = int(t * SR) - int(0.005 * SR)
        if 0 < s and s + L < len(x):
            stack.append(x[s:s + L])
    if stack:
        k_ = np.mean(stack, axis=0)
        e = np.abs(k_); peak_i = int(np.argmax(e))
        # wysokość w oknach czasowych
        pitches = []
        for t_ms in (5, 15, 30, 60, 100, 150, 220):
            s = int(t_ms / 1000 * SR); seg = k_[s:s + int(0.03 * SR)]
            if len(seg) > 100:
                spc = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), 1 << 15)); ff = np.fft.rfftfreq(1 << 15, 1 / SR)
                pitches.append((t_ms, ff[np.argmax(spc * (ff > 30) * (ff < 600))]))
        decay_env, _ = envelope(k_, 64)
        dB = 20 * np.log10(decay_env / decay_env.max() + 1e-9)
        tail = np.argmax(dB < -20) * 64 / SR if np.any(dB < -20) else L / SR
        harm = band(k_, 150, 3000); low = band(k_, 30, 150)
        print(f"Stopa (średnia z {len(stack)} uderzeń): wysokość w czasie " + ", ".join(f"{t}ms {p:.0f}Hz" for t, p in pitches))
        print(f"  długość ogona do -20 dB: {tail * 1000:.0f} ms (beat = {beat * 1000:.0f} ms); harmoniczne 150-3k vs dół: "
              f"{20 * np.log10(np.sqrt(np.mean(harm ** 2)) / np.sqrt(np.mean(low ** 2))):.1f} dB (więcej = brudniej/przester)")
    # Bas / dół w siatce szesnastek w głośnych taktach
    grid = np.zeros(16)
    lows_env, lfr = envelope(band(x, 40, 200), 64)
    for b_ in loud_bars:
        for q in range(16):
            t0 = b_ * bar + q * beat / 4
            i = int(t0 * lfr); j = int((t0 + beat / 4) * lfr)
            if j < len(lows_env):
                grid[q] += lows_env[i:j].mean()
    grid = 20 * np.log10(grid / grid.max() + 1e-9)
    print("Dół w siatce szesnastek (głośne takty), dB: " + " ".join(f"{v:4.0f}" for v in grid))
    # Pompowanie: stosunek energii w drugiej połowie beatu do pierwszej (wyższe pasmo)
    mids_env, mfr = envelope(band(x, 300, 4000), 64)
    first = second = 0
    for b_ in loud_bars:
        for k in range(4):
            t0 = b_ * bar + k * beat
            a, m_, z = int(t0 * mfr), int((t0 + beat / 2) * mfr), int((t0 + beat) * mfr)
            if z < len(mids_env):
                first += mids_env[a:m_].mean(); second += mids_env[m_:z].mean()
    print(f"Pompowanie środka (2. połowa beatu vs 1.): {20 * np.log10(second / first):+.1f} dB (dodatnie = środek ucicha przy stopie)")


if len(sys.argv) > 1 and sys.argv[1] != "--rhythm":
    for p in sys.argv[1:]:
        analyze(p)


def rhythm(path):
    """Wyrazistość rytmu i wzory uderzeń: dół (stopa), środek (werbel/klaśnięcie), góra (hi-hat/banjo)."""
    x = load(path, 1)[:, 0]
    bpm, onset, fr = tempo(x)
    if os.environ.get("BPM_FIXED"):
        bpm = float(os.environ["BPM_FIXED"])
    beat = 60 / bpm
    bar = 4 * beat
    out = []
    for name, lo, hi in (("dół 40-150", 40, 150), ("werbel 1-4k", 1000, 4000), ("góra 5-10k", 5000, 10000)):
        env, efr = envelope(band(x, lo, hi), 64)
        on = np.maximum(0, np.diff(env))
        # wyrazistość: średnia siła uderzeń na siatce szesnastek vs mediana tła
        grid = np.zeros(16)
        nb = int(len(x) / SR / bar)
        for b in range(nb):
            for q in range(16):
                i = int((b * bar + q * beat / 4) * efr)
                if i + 3 < len(on):
                    grid[q] += on[max(0, i - 2):i + 3].max()
        grid /= max(nb, 1)
        contrast = 20 * np.log10(grid.max() / (np.median(on) + 1e-9))
        pattern = 20 * np.log10(grid / grid.max() + 1e-9)
        out.append(f"  {name:12s} kontrast {contrast:5.1f} dB | " + " ".join(f"{v:4.0f}" for v in pattern))
    print("Uderzenia w siatce szesnastek (0 = najmocniej; kontrast = jak bardzo uderzenia odstają od tła):")
    print("\n".join(out))


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--rhythm":
    for p in sys.argv[2:]:
        print("\n===", p.replace(chr(92), "/").split("/")[-1])
        rhythm(p)
