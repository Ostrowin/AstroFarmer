"""Cechy plików audio: długość, szczyt, RMS, środek ciężkości widma, atak, płaskość widma.
Przydatne przy doborze próbek, których nie da się odsłuchać.
Użycie: python features.py plik [plik...]"""
import subprocess, sys
import numpy as np

SR = 22050


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def db(x):
    return 20 * np.log10(max(x, 1e-9))


print(f"{'file':60s} {'dur':>5s} {'peak':>6s} {'rms':>6s} {'cent':>6s} {'atk':>5s} {'flat':>5s}")
for p in sys.argv[1:]:
    x = load(p)
    if len(x) == 0:
        print(p, "EMPTY")
        continue
    peak = np.max(np.abs(x))
    rms = np.sqrt(np.mean(x ** 2))
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    cent = float(np.sum(freqs * spec) / max(np.sum(spec), 1e-9))
    flat = float(np.exp(np.mean(np.log(spec + 1e-9))) / max(np.mean(spec), 1e-9))
    env = np.abs(x)
    atk = int(np.argmax(env > peak * 0.5)) / SR
    name = p.replace("\\", "/").split("_incoming/")[-1]
    print(f"{name:60s} {len(x)/SR:5.2f} {db(peak):6.1f} {db(rms):6.1f} {cent:6.0f} {atk:5.2f} {flat:5.2f}")
