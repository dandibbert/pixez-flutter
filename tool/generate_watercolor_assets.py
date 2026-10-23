"""Renders the static watercolor textures used by the watercolor UI style.

The design asks for paper grain and pigment edges as pre-rendered images
rather than runtime filters. Every image is white with the shape in its
alpha channel, so the app tints it with any colour (BlendMode.srcIn).

    python3 tool/generate_watercolor_assets.py

Writes assets/watercolor/{paper,blob_round,blob_wide,blob_pill,blob_dot}.png.
"""

import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "watercolor")
rng = np.random.default_rng(7)


def blur_wrap(a, r):
    """Box blur that wraps around the edges, so the result tiles."""
    for axis in (0, 1):
        acc = np.zeros_like(a)
        for d in range(-r, r + 1):
            acc += np.roll(a, d, axis=axis)
        a = acc / (2 * r + 1)
    return a


def fractal(size, octaves, base, wrap=True):
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        grid = rng.random((cells, cells))
        img = Image.fromarray((grid * 255).astype(np.uint8))
        img = img.resize((size, size), Image.BICUBIC)
        layer = np.asarray(img, dtype=np.float64) / 255.0
        if wrap:
            layer = blur_wrap(layer, 1)
        total += layer * amp
        norm += amp
        amp *= 0.5
    total /= norm
    return (total - total.min()) / (total.max() - total.min())


def save_alpha(alpha, name):
    alpha = np.clip(alpha, 0, 1)
    rgba = np.zeros(alpha.shape + (4,), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (alpha * 255).round().astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name), optimize=True)


def paper():
    # Fine grain: per-pixel noise softened a little, tileable. Full alpha
    # range here; the app draws it at 7%.
    n = rng.random((256, 256))
    n = 0.6 * n + 0.4 * blur_wrap(n, 1)
    fibres = blur_wrap(rng.random((256, 256)), 3)
    n = 0.75 * n + 0.25 * fibres
    n = (n - n.min()) / (n.max() - n.min())
    save_alpha(n, "paper.png")


def blob(name, w, h, rx, ry, rough=0.09, pill=False):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    cx, cy = w / 2, h / 2
    if pill:
        # Distance to a horizontal capsule.
        half = rx - ry
        dx = np.maximum(np.abs(xs - cx) - half, 0)
        d = np.sqrt(dx ** 2 + (ys - cy) ** 2) / ry
    else:
        d = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    size = max(w, h)
    edge = fractal(size, 4, 3, wrap=False)[:h, :w]
    d = d + (edge - 0.5) * rough * 2
    body = np.clip((1.0 - d) / 0.06, 0, 1)
    # Pigment pools at the drying edge: slightly denser rim, lighter centre.
    rim = np.exp(-((d - 0.93) ** 2) / 0.004)
    grain = fractal(size, 3, 6, wrap=False)[:h, :w]
    alpha = body * (0.78 + 0.12 * grain) + rim * 0.14 * body
    save_alpha(alpha, name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    paper()
    blob("blob_round.png", 224, 200, 96, 84)
    blob("blob_wide.png", 320, 140, 146, 58)
    blob("blob_pill.png", 360, 120, 168, 50, rough=0.06, pill=True)
    blob("blob_dot.png", 96, 96, 40, 40, rough=0.12)
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)))
