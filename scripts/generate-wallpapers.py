#!/usr/bin/env python3
"""AETHER "Obsidian Horizon" wallpapers.

Renders two related images procedurally (no downloaded artwork, no licensing
questions):

  desktop    near-black sky, a thin cyan horizon, violet haze above it
  lockscreen darker, horizon pushed low, open space for the clock and panel

Needs numpy and ImageMagick (`magick`). Usage:

  scripts/generate-wallpapers.py [--width 3840 --height 2160] [--out DIR]
"""

import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np


def hex_rgb(value):
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


BASE_TOP = hex_rgb("#070A0F")
BASE_BOTTOM = hex_rgb("#030508")
CYAN = hex_rgb("#55D6FF")
CYAN_BRIGHT = hex_rgb("#8BE7FF")
VIOLET = hex_rgb("#9B8CFF")
DEEP_BLUE = hex_rgb("#0B1A2A")


def gaussian(x, center, width):
    return np.exp(-((x - center) ** 2) / (2.0 * width ** 2))


def render(width, height, horizon, intensity, haze, star_density, vignette, seed):
    rng = np.random.default_rng(seed)
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
    x = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :]
    aspect = width / height
    xc = (x - 0.5) * aspect

    # Sky: base gradient, slightly lifted toward the horizon.
    t = np.clip(y / horizon, 0.0, 1.0)
    img = BASE_TOP * (1.0 - t[..., None]) * 0.9 + DEEP_BLUE * (t[..., None] ** 3) * 0.35 * intensity
    img = img + np.zeros((height, width, 3), dtype=np.float32)

    # Below the horizon: obsidian floor, darker than the sky.
    curve = horizon + 0.06 * xc ** 2
    below = y > curve
    floor_t = np.clip((y - curve) / (1.0 - horizon), 0.0, 1.0)
    img = np.where(below[..., None], BASE_BOTTOM * (0.75 + 0.25 * (1.0 - floor_t[..., None])), img)

    # Horizontal falloff: brightest in the middle, fading out at the edges.
    spread = gaussian(xc, 0.0, 0.30 * aspect)
    wide = gaussian(xc, 0.0, 0.55 * aspect)

    # The horizon bows gently, like the edge of a planet seen from orbit.
    d = y - curve
    core = gaussian(d, 0.0, 0.0012) * spread
    bloom = gaussian(d, 0.0, 0.012) * spread
    glow_up = np.exp(-np.clip(-d, 0, None) / 0.09) * (d < 0) * wide
    glow_down = np.exp(-np.clip(d, 0, None) / 0.03) * (d >= 0) * spread
    # Atmosphere shifts from cyan at the horizon to violet higher up.
    violet_band = np.exp(-np.clip(-d - 0.06, 0, None) / 0.22) * (d < -0.02) * wide
    img += CYAN_BRIGHT * (core[..., None] * 0.65 * intensity)
    img += CYAN * (bloom[..., None] * 0.18 * intensity)
    img += CYAN * (glow_up[..., None] * 0.10 * intensity)
    img += CYAN * (glow_down[..., None] * 0.05 * intensity)
    img += VIOLET * (violet_band[..., None] * 0.045 * haze)

    # Faint reflection streak on the floor.
    streak = gaussian(xc, 0.0, 0.18 * aspect) * gaussian(d, 0.05, 0.05) * (d > 0)
    img += CYAN * (streak[..., None] * 0.025 * intensity)

    # Violet atmosphere: two off-centre clouds high in the sky, used sparingly.
    for cx, cy, r, a in ((-0.55, 0.22, 0.55, 1.0), (0.75, 0.35, 0.45, 0.7)):
        cloud = np.exp(-(((xc - cx * aspect * 0.6) ** 2) + ((y - cy) * 1.4) ** 2) / (2 * r ** 2))
        img += VIOLET * (cloud[..., None] * 0.045 * haze * a)

    # Sparse, dim stars in the upper sky only.
    n_stars = int(width * height * star_density)
    sx = rng.integers(0, width, n_stars)
    sy = (rng.random(n_stars) ** 1.8 * horizon * 0.85 * height).astype(int)
    brightness = rng.random(n_stars) ** 3 * 0.35 + 0.05
    for px, py, b in zip(sx, sy, brightness):
        img[py, px] += CYAN_BRIGHT * b * 0.6 + b * 0.4

    # Vignette.
    r2 = ((x - 0.5) * 1.15) ** 2 + ((y - 0.5) * 1.3) ** 2
    img *= (1.0 - vignette * np.clip(r2, 0.0, 1.0))[..., None]

    # Fine grain so the gradients do not band on 8-bit displays.
    img += (rng.random((height, width, 1), dtype=np.float32) - 0.5) * (1.6 / 255.0)
    return np.clip(img, 0.0, 1.0)


def save_png(img, path):
    height, width, _ = img.shape
    data = (img * 65535.0 + 0.5).astype(">u2")
    with tempfile.NamedTemporaryFile(suffix=".ppm", delete=False) as tmp:
        tmp.write(f"P6\n{width} {height}\n65535\n".encode())
        tmp.write(data.tobytes())
        ppm = tmp.name
    try:
        subprocess.run(["magick", ppm, "-depth", "8", "-strip", path], check=True)
    finally:
        os.unlink(ppm)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--width", type=int, default=3840)
    parser.add_argument("--height", type=int, default=2160)
    parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "theme"))
    args = parser.parse_args()

    out = os.path.abspath(args.out)
    os.makedirs(os.path.join(out, "backgrounds"), exist_ok=True)

    desktop = render(args.width, args.height, horizon=0.64, intensity=1.0, haze=1.0,
                     star_density=0.00006, vignette=0.35, seed=7)
    save_png(desktop, os.path.join(out, "backgrounds", "1-obsidian-horizon.png"))
    print("wrote backgrounds/1-obsidian-horizon.png")

    lock = render(args.width, args.height, horizon=0.80, intensity=0.75, haze=0.7,
                  star_density=0.00003, vignette=0.5, seed=11)
    save_png(lock, os.path.join(out, "lockscreen.png"))
    print("wrote lockscreen.png")

    # Thumbnail for Omarchy's theme picker.
    subprocess.run(["magick", os.path.join(out, "backgrounds", "1-obsidian-horizon.png"),
                    "-resize", "960x540^", "-gravity", "center", "-extent", "960x540",
                    os.path.join(out, "preview.png")], check=True)
    print("wrote preview.png")


if __name__ == "__main__":
    sys.exit(main())
