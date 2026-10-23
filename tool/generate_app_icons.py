"""Builds the app icons from the watercolor "P" artwork.

    python3 tool/generate_app_icons.py assets/branding/watercolor_icon_source.jpg

The artwork comes with rounded corners painted in. The platforms cut their
own shape, so the painted corners are first filled with the surrounding
paper texture. Writes the iOS app icon, the Android legacy, round and
adaptive launcher icons, and the in-app logo (assets/images/icon.png).
"""

import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent


def corner_mask(rgb: np.ndarray) -> np.ndarray:
    """Pixels outside the painted rounded square: the flat corner colour,
    flood-filled from each corner."""
    h, w, _ = rgb.shape
    target = rgb[2, 2].astype(int)
    close = (np.abs(rgb.astype(int) - target).sum(axis=2) <= 6)
    mask = np.zeros((h, w), bool)
    stack = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or mask[y, x] or not close[y, x]:
            continue
        mask[y, x] = True
        stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    # Grow by a few pixels to swallow the anti-aliased rim.
    grown = Image.fromarray(mask.astype(np.uint8) * 255).filter(
        ImageFilter.MaxFilter(7)
    )
    return np.array(grown) > 0


def paper_patch(rgb: np.ndarray) -> np.ndarray:
    """A clean stretch of paper along the top edge, used as texture."""
    return rgb[110:230, 40:160]


def fill_corners(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    patch = paper_patch(rgb)
    ph, pw, _ = patch.shape
    h, w, _ = rgb.shape
    tiled = np.tile(patch, (h // ph + 1, w // pw + 1, 1))[:h, :w]
    out = rgb.copy()
    out[mask] = tiled[mask]
    return out


def rounded(img: Image.Image, size: int, radius: float) -> Image.Image:
    img = img.resize((size, size), Image.LANCZOS).convert("RGBA")
    scale = 4
    m = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1),
        radius=radius * size * scale,
        fill=255,
    )
    img.putalpha(m.resize((size, size), Image.LANCZOS))
    return img


def circle(img: Image.Image, size: int) -> Image.Image:
    img = img.resize((size, size), Image.LANCZOS).convert("RGBA")
    scale = 4
    m = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size * scale - 1, size * scale - 1), fill=255)
    img.putalpha(m.resize((size, size), Image.LANCZOS))
    return img


def main() -> None:
    source = Image.open(sys.argv[1]).convert("RGB").resize((1024, 1024))
    rgb = np.array(source)
    mask = corner_mask(rgb)
    filled = Image.fromarray(fill_corners(rgb, mask))

    # iOS: one icon. The painted texture compresses poorly and Xcode renders
    # every size from each appearance, so dark and tinted are left to iOS,
    # which derives them from this one.
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    filled.save(ios / "icon-1024.png", optimize=True)

    # Android.
    res = ROOT / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    patch = Image.fromarray(paper_patch(rgb))
    for name, d in densities.items():
        folder = res / f"mipmap-{name}"
        legacy = round(48 * d)
        rounded(filled, legacy, 0.22).save(folder / "ic_launcher.png")
        circle(filled, legacy).save(folder / "ic_launcher_round.png")
        canvas = round(108 * d)
        # Paper behind, the artwork inside the 72dp safe zone with a soft
        # edge so it melts into that paper.
        bg = patch.resize((canvas, canvas), Image.LANCZOS)
        bg.save(folder / "ic_launcher_background.png")
        inner = round(72 * d)
        art = filled.resize((inner, inner), Image.LANCZOS).convert("RGBA")
        feather = Image.new("L", (inner, inner), 0)
        edge = max(2, inner // 14)
        ImageDraw.Draw(feather).rectangle((edge, edge, inner - edge, inner - edge), fill=255)
        art.putalpha(feather.filter(ImageFilter.GaussianBlur(edge / 2)))
        fg = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        offset = (canvas - inner) // 2
        fg.alpha_composite(art, (offset, offset))
        fg.save(folder / "ic_launcher_foreground.png")
    rounded(filled, 144, 0.22).save(res / "drawable-nodpi/ic_launcher.png")

    # In-app logo: the same rounded square as the launcher icon.
    rounded(filled, 144, 0.22).save(ROOT / "assets/images/icon.png")
    print("icons written")


if __name__ == "__main__":
    main()
