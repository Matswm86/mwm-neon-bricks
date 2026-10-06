"""Render the MWM Neon Bricks sound effects to assets/sfx/*.ogg.

Own synthesis (FM and modal bells, filtered noise, convolution reverb) layered
with a few Kenney CC0 impact samples (see CREDITS.md). Output: 44.1 kHz mono
Ogg Vorbis. Deterministic: every random layer has a fixed seed.

Usage:
    python3 tools/render_sfx.py --kenney <dir with kenney_impact-sounds> [--out assets/sfx]
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
PENTA = [1.0, 1.125, 1.25, 1.5, 1.667, 2.0, 2.25, 2.5, 3.0]


# ------------------------------------------------------------------ helpers


def tt(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def env(dur: float, attack: float, tau: float) -> np.ndarray:
    t = tt(dur)
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    a = 0.5 - 0.5 * np.cos(np.pi * a)
    # Taper the last 25% to zero so a cut segment never clicks.
    tail = np.clip((dur - t) / (0.25 * dur), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / tau) * (0.5 - 0.5 * np.cos(np.pi * tail))


def fit(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.pad(x, (0, n - len(x)))


def mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, g in parts:
        out[: len(p)] += p * g
    return out


def at(x: np.ndarray, start: float, total: float) -> np.ndarray:
    out = np.zeros(int(total * SR))
    i = int(start * SR)
    seg = x[: max(0, len(out) - i)]
    out[i : i + len(seg)] += seg
    return out


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="lowpass", fs=SR, output="sos"), x)


def hp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="highpass", fs=SR, output="sos"), x)


def noise(dur: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(dur * SR))


def swept_bp(x: np.ndarray, f0: float, f1: float, q: float = 2.0) -> np.ndarray:
    """State-variable band-pass whose centre glides from f0 to f1 (exponential)."""
    n = len(x)
    fc = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    out = np.zeros(n)
    low = band = 0.0
    damp = 1.0 / q
    for i in range(n):
        f = 2.0 * np.sin(np.pi * fc[i] / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        out[i] = band
    return out


def sine_glide(dur: float, f0: float, f1: float, glide: float) -> np.ndarray:
    t = tt(dur)
    f = f1 + (f0 - f1) * np.exp(-t / max(glide, 1e-4))
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def modal(f: float, dur: float, ratios, amps, taus, attack: float = 0.001) -> np.ndarray:
    t = tt(dur)
    out = np.zeros(len(t))
    for r, a, tau in zip(ratios, amps, taus, strict=True):
        if f * r < SR * 0.45:
            out += a * np.sin(2.0 * np.pi * f * r * t) * env(dur, attack, tau)
    return out


def fm_bell(
    f: float, dur: float, ratio: float, index: float, idx_tau: float, tau: float
) -> np.ndarray:
    t = tt(dur)
    mod = index * np.exp(-t / idx_tau) * np.sin(2.0 * np.pi * f * ratio * t)
    return np.sin(2.0 * np.pi * f * t + mod) * env(dur, 0.002, tau)


def soft_saw(f: float, dur: float, harmonics: int = 18) -> np.ndarray:
    """Band-limited saw (additive), so no aliasing and no 8-bit edge."""
    t = tt(dur)
    out = np.zeros(len(t))
    for k in range(1, harmonics + 1):
        if f * k > 9000.0:
            break
        out += np.sin(2.0 * np.pi * f * k * t) / k
    return out


def reverb(x: np.ndarray, rt: float, wet: float, damp: float = 6000.0, seed: int = 7) -> np.ndarray:
    """Convolution with a synthetic room: dense decaying noise, darker over time."""
    n = int(rt * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    bright = rng.uniform(-1, 1, n)
    dark = lp(rng.uniform(-1, 1, n), damp * 0.35)
    mixw = np.exp(-t / (rt * 0.25))
    ir = (bright * mixw + dark * 2.0 * (1.0 - mixw)) * np.exp(-6.9 * t / rt)
    ir = lp(ir, damp)
    pre = int(0.012 * SR)
    ir = np.concatenate([np.zeros(pre), ir])
    ir /= np.sqrt(np.sum(ir**2)) + 1e-9
    w = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
    dry = np.pad(x, (0, len(w) - len(x)))
    return dry * (1.0 - wet * 0.5) + w * wet


def finish(
    x: np.ndarray, peak_db: float, fade_ms: float = 30.0, floor_db: float = -60.0
) -> np.ndarray:
    x = hp(x, 35.0)
    # Trim the silent tail, then fade.
    a = np.abs(x)
    thr = np.max(a) * 10 ** (floor_db / 20.0)
    idx = np.nonzero(a > thr)[0]
    if len(idx):
        x = x[: idx[-1] + 1]
    nf = min(len(x), int(fade_ms / 1000.0 * SR))
    if nf > 0:
        x[-nf:] *= np.linspace(1.0, 0.0, nf) ** 2
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20.0)
    return x


def load_kenney(root: Path, name: str) -> np.ndarray:
    hits = list(root.rglob(name))
    if not hits:
        raise FileNotFoundError(f"Kenney sample not found: {name}")
    data, sr = sf.read(str(hits[0]), always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        mono = signal.resample_poly(mono, SR, sr)
    return mono / (np.max(np.abs(mono)) + 1e-9)


# ------------------------------------------------------------------ sounds


def bop(variant: int) -> np.ndarray:
    """Paddle: soft rubbery thump with a rounded bell top and a clean click."""
    f0 = [233.08, 246.94, 220.0][variant]
    d = 0.45
    body = sine_glide(d, f0 * 1.5, f0, 0.012) * env(d, 0.002, 0.085)
    second = sine_glide(d, f0 * 3.0, f0 * 2.0, 0.01) * env(d, 0.001, 0.04)
    top = fm_bell(f0 * 4.0, d, 1.0, 0.8, 0.02, 0.05)
    click = hp(noise(0.012, 11 + variant), 2500.0) * env(0.012, 0.0005, 0.0025)
    x = mix((body, 1.0), (second, 0.28), (top, 0.12), (click, 0.22))
    x = lp(x, 7000.0)
    return finish(reverb(x, 0.45, 0.14, 5000.0, seed=21 + variant), -5.0)


def tink(variant: int, kenney: Path) -> np.ndarray:
    """Brick hit, not broken: small glass chime with a real glass clink."""
    f = [1760.0, 1864.7, 1661.2][variant]
    d = 0.9
    chime = modal(f, d, [1.0, 2.32, 4.25, 6.63], [1.0, 0.45, 0.22, 0.1], [0.22, 0.1, 0.05, 0.03])
    shimmer = modal(f * 1.004, d, [1.0], [0.35], [0.18])
    clink = hp(load_kenney(kenney, f"impactGlass_light_00{variant}.ogg"), 1500.0)
    x = mix((chime, 1.0), (shimmer, 1.0), (clink, 0.35))
    return finish(reverb(x, 0.8, 0.22, 7000.0, seed=31 + variant), -7.0)


def chime() -> np.ndarray:
    """Brick break tone (C5), pitched up the pentatonic ladder in game."""
    f = 523.25
    d = 1.6
    main = fm_bell(f, d, 3.5, 1.1, 0.05, 0.45)
    pure = modal(f, d, [1.0, 2.0, 3.0, 4.01], [0.8, 0.35, 0.12, 0.08], [0.6, 0.3, 0.15, 0.08])
    det = modal(f * 1.0035, d, [1.0], [0.4], [0.5])
    mallet = bp(noise(0.02, 41), 1500.0, 6000.0) * env(0.02, 0.0005, 0.004)
    x = mix((main, 0.55), (pure, 1.0), (det, 1.0), (mallet, 0.25))
    x = lp(x, 9000.0)
    return finish(reverb(x, 1.2, 0.3, 6500.0, seed=43), -6.0)


def shatter(variant: int, kenney: Path) -> np.ndarray:
    """Glass brick breaking: real glass hit plus a sprinkle of tiny crystal pings."""
    d = 0.7
    rng = np.random.default_rng(100 + variant)
    sprinkle = np.zeros(int(d * SR))
    for k in range(26):
        start = 0.004 + (rng.random() ** 2) * 0.22
        f = rng.uniform(2600.0, 7200.0)
        ping = modal(f, 0.12, [1.0, 2.7], [1.0, 0.3], [rng.uniform(0.012, 0.045), 0.01])
        sprinkle += at(ping, start, d) * rng.uniform(0.25, 1.0) * (1.0 - k / 40.0)
    crunch = bp(noise(d, 120 + variant), 1800.0, 9000.0) * env(d, 0.001, 0.035)
    glass = hp(load_kenney(kenney, f"impactGlass_medium_00{variant}.ogg"), 900.0)
    x = mix((sprinkle, 0.5), (crunch, 0.35), (glass, 0.6))
    x = lp(x, 11000.0)
    return finish(reverb(x, 0.6, 0.2, 7000.0, seed=130 + variant), -10.0)


def ting(variant: int, kenney: Path) -> np.ndarray:
    """Chrome: bright metallic ping with a slow shimmer."""
    f = [1318.5, 1396.9][variant]
    d = 1.4
    bar = modal(f, d, [1.0, 2.76, 5.4, 8.93], [1.0, 0.5, 0.25, 0.12], [0.55, 0.25, 0.12, 0.06])
    beat = modal(f * 1.002, d, [1.0, 2.76], [0.5, 0.2], [0.5, 0.2])
    hit = hp(load_kenney(kenney, f"impactMetal_light_00{variant}.ogg"), 800.0)
    x = mix((bar, 1.0), (beat, 1.0), (hit, 0.3))
    return finish(reverb(x, 1.0, 0.25, 8000.0, seed=51 + variant), -7.0)


def tick(variant: int) -> np.ndarray:
    """Wall: small soft tap."""
    f = [1396.9, 1318.5, 1480.0][variant]
    d = 0.2
    tone = sine_glide(d, f * 1.2, f, 0.006) * env(d, 0.001, 0.022)
    click = bp(noise(0.01, 61 + variant), 1500.0, 5000.0) * env(0.01, 0.0005, 0.002)
    x = mix((tone, 1.0), (click, 0.4))
    return finish(reverb(x, 0.3, 0.12, 5000.0, seed=65 + variant), -9.0)


def bwomm() -> np.ndarray:
    """Net catch: warm, bouncy trampoline 'bwomm' (soft, never scary)."""
    d = 0.9
    t = tt(d)
    f = 110.0 * (
        1.0 + 0.35 * np.exp(-t / 0.06) * np.cos(2 * np.pi * 9.0 * t) + 0.12 * (1 - np.exp(-t / 0.3))
    )
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    body = (np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)) * env(d, 0.008, 0.22)
    top = fm_bell(392.0, d, 2.0, 0.6, 0.05, 0.18)
    fwump = lp(noise(0.08, 71), 400.0) * env(0.08, 0.002, 0.02)
    x = mix((body, 1.0), (top, 0.12), (fwump, 0.5))
    x = lp(x, 3000.0)
    return finish(reverb(x, 0.6, 0.18, 3000.0, seed=73), -5.0)


def hum() -> np.ndarray:
    """Touch-down: soft bubble pop."""
    d = 0.16
    x = sine_glide(d, 520.0, 880.0, 0.03) * env(d, 0.004, 0.04)
    x = mix((x, 1.0), (bp(noise(0.006, 81), 2000.0, 6000.0) * env(0.006, 0.0005, 0.0015), 0.15))
    return finish(reverb(x, 0.3, 0.1, 5000.0, seed=83), -10.0)


def zip_up() -> np.ndarray:
    """Loop nudge: airy swish upward with a little sparkle."""
    d = 0.32
    n = noise(d, 91)
    sw = swept_bp(n, 1200.0, 6500.0, 3.0) * np.sin(np.pi * np.clip(tt(d) / 0.26, 0, 1)) ** 2
    spark = at(modal(2637.0, 0.2, [1.0, 2.0], [1.0, 0.2], [0.05, 0.02]), 0.17, d)
    x = lp(mix((sw, 1.0), (spark, 0.25)), 7000.0, order=4)
    return finish(reverb(x, 0.5, 0.2, 7000.0, seed=93), -9.0)


def whoosh() -> np.ndarray:
    """Gentle restart: soft rewind swoosh (reversed chime swell into a falling air sweep)."""
    d = 1.0
    c = chime()[: int(0.9 * SR)]
    swell = c[::-1][: int(0.55 * SR)] * np.linspace(0.2, 1.0, int(0.55 * SR))
    air = swept_bp(noise(0.8, 101), 5000.0, 500.0, 1.6)
    air *= np.sin(np.pi * np.clip(tt(0.8) / 0.8, 0, 1)) ** 2
    x = mix((at(swell, 0.0, d), 0.6), (at(air, 0.1, d), 0.9))
    x = lp(x, 4500.0, order=4)
    return finish(reverb(x, 0.8, 0.2, 5000.0, seed=103), -7.0)


def komet() -> np.ndarray:
    """Komet caught: rising whoosh with a bright sparkle run and a shimmer tail."""
    d = 1.6
    air = swept_bp(noise(0.5, 111), 700.0, 7000.0, 2.2)
    air *= np.sin(np.pi * np.clip(tt(0.5) / 0.5, 0, 1)) ** 1.5
    x = at(air, 0.0, d) * 0.9
    notes = [783.99, 1046.5, 1318.5, 1568.0, 2093.0, 2637.0]
    for k, f in enumerate(notes):
        b = fm_bell(f, 0.8, 2.0, 0.9, 0.03, 0.18) + 0.3 * modal(f * 1.004, 0.8, [1.0], [1.0], [0.2])
        x += at(b, 0.16 + k * 0.045, d) * (0.35 + 0.08 * k)
    rng = np.random.default_rng(117)
    for _ in range(18):
        f = rng.uniform(3500.0, 8000.0)
        x += (
            at(modal(f, 0.15, [1.0], [1.0], [rng.uniform(0.02, 0.06)]), rng.uniform(0.35, 0.9), d)
            * 0.12
        )
    lift = sine_glide(0.4, 98.0, 196.0, 0.15) * env(0.4, 0.05, 0.12)
    x = mix((x, 1.0), (at(lift, 0.05, d), 0.35))
    x = lp(x, 11000.0)
    return finish(reverb(x, 1.3, 0.3, 8000.0, seed=119), -5.0)


def win() -> np.ndarray:
    """Win stinger: warm pad swell, rising bell melody and sparkle, long tail."""
    d = 3.2
    pad = np.zeros(int(d * SR))
    for f in [130.81, 196.0, 261.63, 329.63, 392.0, 493.88, 587.33]:
        for cents in (-7.0, 7.0):
            pad += soft_saw(f * 2 ** (cents / 1200.0), d)
    pad = lp(pad, 2200.0) * env(d, 0.25, 1.1) * 0.08
    x = pad
    melody = [(783.99, 0.0), (1046.5, 0.11), (1318.5, 0.22), (1568.0, 0.33), (2093.0, 0.5)]
    for f, s in melody:
        b = fm_bell(f, 2.2, 3.5, 0.9, 0.06, 0.55) * 0.5 + modal(
            f, 2.2, [1.0, 2.0], [0.7, 0.2], [0.8, 0.3]
        )
        x = x + at(b, s, d) * 0.4
    rng = np.random.default_rng(131)
    for _ in range(30):
        f = rng.uniform(3000.0, 8000.0)
        x = (
            x
            + at(modal(f, 0.2, [1.0], [1.0], [rng.uniform(0.02, 0.07)]), rng.uniform(0.45, 1.8), d)
            * 0.07
        )
    thump = sine_glide(0.5, 130.0, 65.0, 0.05) * env(0.5, 0.003, 0.12)
    x = mix((x, 1.0), (thump, 0.3))
    x = lp(x, 11000.0)
    return finish(reverb(x, 2.0, 0.35, 7000.0, seed=137), -4.0, fade_ms=200.0)


def build(kenney: Path) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for v in range(3):
        out[f"bop_{v + 1}"] = bop(v)
        out[f"tink_{v + 1}"] = tink(v, kenney)
        out[f"tick_{v + 1}"] = tick(v)
        out[f"shatter_{v + 1}"] = shatter(v, kenney)
    for v in range(2):
        out[f"ting_{v + 1}"] = ting(v, kenney)
    out["chime"] = chime()
    out["bwomm"] = bwomm()
    out["hum"] = hum()
    out["zip"] = zip_up()
    out["whoosh"] = whoosh()
    out["komet"] = komet()
    out["win"] = win()
    return out


def write_ogg(x: np.ndarray, path: Path, quality: str = "4") -> None:
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "x.wav"
        sf.write(str(wav), x.astype(np.float32), SR, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", "1", "-ar", str(SR)]
            + ["-c:a", "libvorbis", "-q:a", quality, str(path)],
            check=True,
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--kenney", type=Path, required=True, help="folder holding kenney_impact-sounds"
    )
    ap.add_argument(
        "--out", type=Path, default=Path(__file__).resolve().parent.parent / "assets" / "sfx"
    )
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, x in build(args.kenney).items():
        write_ogg(x, args.out / f"nb_{name}.ogg")
        print(f"nb_{name}.ogg  {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main()
