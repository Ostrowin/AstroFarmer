"""Wyrazistość rytmu: średnia energia w każdej szesnastce taktu, w trzech pasmach.

Użycie:
  python rhythm_grid.py plik.ogg BPM PIERWSZY_TAKT OSTATNI_TAKT
(takty liczone od 0, zakres półotwarty; np. 4 12 = takty 5-12 w nutach)

Tylko dla własnych utworów, gdzie tempo jest DOKŁADNIE znane: przy nagraniach
studyjnych tempo pływa i siatka się rozjeżdża (wzory wychodzą płaskie, bez sensu).
Czytanie: 0 = najmocniejsza szesnastka; „beat vs reszta” = o ile szesnastki na
beatach (0, 4, 8, 12) odstają od pozostałych. Ciągła ściana dołu ~ +1..2 dB,
wyraźny puls ~ +5..20 dB.
"""
import subprocess, sys
import numpy as np

SR = 22050


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))


def main():
    path, bpm, a, b = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    x = np.frombuffer(subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                                     capture_output=True).stdout, dtype=np.float32)
    beat = 60 / bpm
    for name, lo, hi in (("dół 40-150", 40, 150), ("werbel 1-4k", 1000, 4000), ("klask 2-8k", 2000, 8000), ("góra 6-11k", 6000, 11000)):
        y = band(x, lo, hi) ** 2
        g = np.zeros(16)
        for bar in range(a, b):
            for q in range(16):
                s = int((bar * 4 * beat + q * beat / 4) * SR)
                e = int((bar * 4 * beat + (q + 1) * beat / 4) * SR)
                g[q] += y[s:e].mean()
        g = 10 * np.log10(g / g.max() + 1e-12)
        on = g[[0, 4, 8, 12]].mean()
        off = np.delete(g, [0, 4, 8, 12]).mean()
        print(f"{name:12s} " + " ".join(f"{v:4.0f}" for v in g) + f"   | beat vs reszta {on - off:+.1f} dB, rozpiętość {g.max() - g.min():.0f} dB")


if __name__ == "__main__":
    main()
