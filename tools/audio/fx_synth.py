"""Próbki efektów do utworów: okrzyk robo-kowboja („yee-haw”, synteza formantowa),
szum narastający (riser), odwrócony talerz i niskie uderzenie (impact).
Wszystko liczone od zera (poza talerzem z VSCO 2 CE, CC0).

Użycie: python tools/audio/fx_synth.py <folder wyjściowy>
"""
import os, subprocess, sys
import numpy as np

SR = 48000


def save(x, path):
    x = np.asarray(x, dtype=np.float32)
    if x.ndim == 1:
        x = np.stack([x, x], -1)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-c:a", "pcm_s24le", path],
                   input=x.tobytes(), check=True)


def resonator(x, freqs, bws):
    """Rezonator 2. rzędu ze zmienną w czasie częstotliwością (formant)."""
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    r = np.exp(-np.pi * bws / SR)
    c = 2 * r * np.cos(2 * np.pi * freqs / SR)
    g = 1 - r
    for i in range(len(x)):
        v = g[i] * x[i] + c[i] * y1 - r[i] * r[i] * y2
        y2, y1 = y1, v
        y[i] = v
    return y


def yeehaw(pitch=1.0, length=1.0, seed=1):
    """„Yee-haw!”: krótkie, wznoszące „yii”, przydech „h”, długie, opadające „haaaw”."""
    rng = np.random.default_rng(seed)
    T = 1.3 * length
    n = int(T * SR)
    t = np.arange(n) / SR
    k = np.array([0.0, 0.08, 0.36, 0.42, 0.50, 0.75, 1.05, 1.3]) * length
    f0 = np.interp(t, k, np.array([300, 380, 560, 520, 610, 560, 470, 380]) * pitch)
    vib = 1 + 0.03 * np.sin(2 * np.pi * 6.2 * t) * np.clip((t - 0.55 * length) / 0.3, 0, 1)
    f0 = f0 * vib * (1 + 0.004 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    phase = np.cumsum(2 * np.pi * f0 / SR)
    src = np.zeros(n)
    for h in range(1, 40):
        src += np.where(h * f0 < 9000, np.sin(h * phase) / h ** 1.1, 0)
    # Samogłoski: i (yii) -> a (haa) -> o (aw)
    F1 = np.interp(t, k, [260, 260, 290, 500, 760, 760, 640, 580])
    F2 = np.interp(t, k, [2300, 2300, 2250, 1500, 1250, 1200, 950, 880])
    F3 = np.interp(t, k, [3000, 3000, 3000, 2700, 2550, 2500, 2450, 2400])
    voiced_env = np.interp(t, k, [0, 0.8, 1.0, 0.25, 0.9, 1.0, 0.85, 0])
    noise_env = np.interp(t, [0, 0.38 * length, 0.42 * length, 0.47 * length, 0.52 * length, T], [0, 0, 0.9, 0.6, 0, 0])
    exc = src * voiced_env + rng.standard_normal(n) * noise_env * 0.35
    out = (resonator(exc, F1, np.full(n, 70.0)) * 1.0 + resonator(exc, F2, np.full(n, 100.0)) * 0.6 +
           resonator(exc, F3, np.full(n, 140.0)) * 0.3)
    # Robot-kowboj: lekka saturacja i cichy głos oktawę niżej.
    low = np.interp(np.arange(n) * 0.5, np.arange(n), out)
    out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.3) + 0.25 * low / (np.max(np.abs(low)) + 1e-9)
    fade = np.minimum(1, np.minimum(t / 0.01, (T - t) / 0.08))
    return out * fade


def riser(seconds):
    n = int(seconds * SR)
    rng = np.random.default_rng(3)
    noise = rng.standard_normal(n)
    hop, win = 512, 2048
    out = np.zeros(n + win)
    w = np.hanning(win)
    freqs = np.fft.rfftfreq(win, 1 / SR)
    for i in range(0, n - win, hop):
        p = i / n
        center = 300 * (8000 / 300) ** (p ** 1.6)
        band = np.exp(-0.5 * (np.log(freqs + 1) - np.log(center)) ** 2 / 0.35 ** 2)
        spec = np.fft.rfft(noise[i:i + win] * w) * band
        out[i:i + win] += np.fft.irfft(spec) * w
    out = out[:n] * (np.linspace(0, 1, n) ** 2.2)
    return out


def impact():
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    f = 30 + 70 * np.exp(-t * 6)
    boom = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t * 2.0)
    crack = np.random.default_rng(5).standard_normal(n) * np.exp(-t * 30) * 0.5
    return np.tanh(2.5 * (boom + crack))


def reverse_cymbal(path, seconds):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)[: int(seconds * SR)][::-1].copy()
    x *= np.linspace(0, 1, len(x))[:, None] ** 1.5
    return x


def hardstyle_kick(tail_hz=87.31, length=0.42):
    """Stopa hardstyle: trzask, szybki zjazd wysokości i przesterowany ogon strojony
    do `tail_hz` (domyślnie F2), żeby w samplerze dało się ją stroić pod akordy."""
    n = int(length * SR)
    t = np.arange(n) / SR
    f = tail_hz + 260 * np.exp(-t * 38) + 1400 * np.exp(-t * 260)
    body = np.sin(np.cumsum(2 * np.pi * f / SR))
    env = np.where(t < 0.28 * length / 0.42, 1.0, np.exp(-(t - 0.28 * length / 0.42) * 22))
    env *= np.minimum(1, t / 0.0015)
    x = np.tanh(5.5 * body * env)  # przester: ogon robi się „kwadratowy” i bzyczący
    x = 0.7 * x + 0.3 * np.clip(3 * body * env, -1, 1)
    click = np.random.default_rng(9).standard_normal(n) * np.exp(-t * 900) * 0.6
    punch = np.sin(2 * np.pi * 55 * t) * np.exp(-t * 30) * 0.5
    out = x + click + punch
    fade = np.minimum(1, (length - t) / 0.01)
    return out * fade


def sub_kick(tail_hz=49.0, length=0.39, grit=0.35, hold=0.8):
    """Twarda stopa z czystym subem: dół (ogon na `tail_hz`) trwa prawie cały beat
    i jest czysty, przester siedzi tylko w górnej warstwie (powyżej ~150 Hz)."""
    n = int(length * SR)
    t = np.arange(n) / SR
    f = tail_hz + 220 * np.exp(-t * 45) + 1800 * np.exp(-t * 320)
    body = np.sin(np.cumsum(2 * np.pi * f / SR))
    env = np.where(t < length * hold, 1.0, np.exp(-(t - length * hold) * 60)) * np.minimum(1, t / 0.001)
    sub = np.tanh(1.6 * body * env)  # tylko lekkie zaokrąglenie, dół zostaje czysty
    dirty = np.tanh(9 * body * env)
    spec = np.fft.rfft(dirty)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec *= 1 / (1 + (150 / np.maximum(freqs, 1)) ** 4)  # górnoprzepustowy ~150 Hz
    top = np.fft.irfft(spec, n)
    click = np.random.default_rng(12).standard_normal(n) * np.exp(-t * 1100) * 0.5
    out = sub + grit * top / (np.max(np.abs(top)) + 1e-9) + click
    return out * np.minimum(1, (length - t) / 0.006)


def banjo_note(freq, length=1.6, seed=0, pick_pos=0.13, brightness=0.996):
    """Banjo modelem fizycznym: Karplus-Strong (struna z tłumieniem), szarpnięcie blisko
    mostka (filtr grzebieniowy), membrana jako rezonatory (ok. 300 Hz, 1.4 kHz, 3 kHz),
    metaliczny „twang” i krótki szum kostki. Zwraca jedną nutę (mono)."""
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    period = SR / freq - 0.45  # filtr pętli opóźnia o ok. pół próbki: kompensacja stroju
    p = int(period)
    frac = period - p
    # Pobudzenie: szum z jasnym kolorem i grzebień (miejsce szarpnięcia)
    exc = rng.uniform(-1, 1, p + 2)
    shift = max(1, int(p * pick_pos))
    exc = exc - np.roll(exc, shift)
    buf = np.zeros(n + p + 2)
    buf[: p + 2] = exc
    loss = brightness ** (220.0 / freq)  # wyższe struny gasną szybciej, jak w prawdziwym banjo
    for i in range(p + 2, n + p + 2):
        a = buf[i - p] * (1 - frac) + buf[i - p - 1] * frac
        b = buf[i - p - 1] * (1 - frac) + buf[i - p - 2] * frac
        buf[i] = loss * (0.55 * a + 0.45 * b)  # lekko niesymetryczne uśrednianie = jaśniej
    s = buf[p + 2:]
    t = np.arange(n) / SR
    s *= np.exp(-t * (2.2 + freq / 400))  # membrana tłumi: krótkie wybrzmienie
    body = (resonator(s, np.full(n, 300.0), np.full(n, 160.0)) * 1.2 + resonator(s, np.full(n, 1400.0), np.full(n, 500.0)) * 0.8 +
            resonator(s, np.full(n, 3000.0), np.full(n, 900.0)) * 0.7)
    out = 0.55 * s / (np.max(np.abs(s)) + 1e-9) + 0.45 * body / (np.max(np.abs(body)) + 1e-9)
    pick = rng.standard_normal(n) * np.exp(-t * 600) * 0.25
    out = np.tanh(1.4 * (out + pick))
    return out * np.minimum(1, (length - t) / 0.05)


VOWELS = {"e": (530, 1840, 2480), "a": (760, 1150, 2450), "o": (570, 840, 2410), "i": (280, 2250, 2950)}


def shout(vowel="e", pitch=210.0, length=0.32, voices=5, seed=4, factors=None):
    """Krótki okrzyk tłumu („HEY!”, „HA!”): przydech „h” + samogłoska, kilka głosów
    o różnej wysokości i lekko przesuniętych w czasie, rozłożonych w stereo."""
    rng = np.random.default_rng(seed)
    total = int((length + 0.05) * SR)
    left, right = np.zeros(total), np.zeros(total)
    F1, F2, F3 = VOWELS[vowel]
    for v in range(voices):
        factor = (factors or [1.0, 0.86, 1.13, 0.93, 1.21, 0.8, 1.07])[v % len(factors or [0] * 7)]
        offset = int(rng.uniform(0, 0.022) * SR)
        n = int(length * SR)
        t = np.arange(n) / SR
        f0 = pitch * factor * (1.12 - 0.22 * t / length) * (1 + 0.01 * np.sin(2 * np.pi * 7 * t))
        phase = np.cumsum(2 * np.pi * f0 / SR)
        src = sum(np.where(h * f0 < 8000, np.sin(h * phase) / h, 0) for h in range(1, 36))
        voiced = np.interp(t, [0, 0.035, 0.06, length * 0.55, length], [0, 0.2, 1, 0.8, 0])
        breath = np.interp(t, [0, 0.01, 0.05, 0.08, length], [0, 1, 0.6, 0, 0])
        exc = src * voiced + rng.standard_normal(n) * breath * 0.8
        sh = 1 + 0.06 * (factor - 1)  # wyższy głos = nieco wyższe formanty
        y = (resonator(exc, np.full(n, F1 * sh), np.full(n, 80.0)) + 0.7 * resonator(exc, np.full(n, F2 * sh), np.full(n, 110.0)) +
             0.35 * resonator(exc, np.full(n, F3 * sh), np.full(n, 150.0)))
        y = np.tanh(2 * y / (np.max(np.abs(y)) + 1e-9))
        pan = (v / max(voices - 1, 1)) * 2 - 1
        left[offset:offset + n] += y * np.sqrt((1 - pan * 0.7) / 2)
        right[offset:offset + n] += y * np.sqrt((1 + pan * 0.7) / 2)
    return np.stack([left, right], -1)


def main(out):
    os.makedirs(out, exist_ok=True)
    save(yeehaw(1.0, 1.0, 1), os.path.join(out, "yeehaw.wav"))
    save(yeehaw(0.84, 1.15, 2), os.path.join(out, "yeehaw_low.wav"))
    save(yeehaw(1.12, 0.8, 3), os.path.join(out, "yeehaw_short.wav"))
    bar = 4 * 60 / 132
    save(riser(4 * bar), os.path.join(out, "riser_4bar.wav"))
    save(riser(2 * bar), os.path.join(out, "riser_2bar.wav"))
    save(impact(), os.path.join(out, "impact.wav"))
    save(reverse_cymbal("D:/Audio/VSCO-2-CE/Percussion/cymbal-crash1_ff_rr1.wav", 2 * bar), os.path.join(out, "rev_cymbal.wav"))
    print("FX:", out)


if __name__ == "__main__":
    main(sys.argv[1])
