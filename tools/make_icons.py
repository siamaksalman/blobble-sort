"""Build every export icon from the 2048px renders made by tools/render_icon.gd.

    godot --path . -s res://tools/render_icon.gd -- /tmp/icon_src
    python3 tools/make_icons.py /tmp/icon_src
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

src = Path(sys.argv[1])
out = Path(__file__).resolve().parent.parent / "assets" / "icons"
out.mkdir(parents=True, exist_ok=True)
full = Image.open(src / "icon_full.png").convert("RGBA")
fg = Image.open(src / "icon_fg.png").convert("RGBA")
bg = Image.open(src / "icon_bg.png").convert("RGBA")


def rounded(img, size, pad=0.0, radius=0.225):
    """Rounded-square icon; `pad` is the transparent margin as a fraction of size."""
    inner = round(size * (1 - 2 * pad))
    body = img.resize((inner, inner), Image.LANCZOS)
    mask = Image.new("L", (inner * 4, inner * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, inner * 4 - 1, inner * 4 - 1), radius=round(inner * 4 * radius), fill=255)
    body.putalpha(mask.resize((inner, inner), Image.LANCZOS))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(body, ((size - inner) // 2, (size - inner) // 2), body)
    return canvas


# Full-bleed square (iOS / App Store: no transparency, the OS rounds the corners).
full.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out / "icon_1024.png")

# Project icon (window, taskbar, web favicon, Linux).
rounded(full, 512).save(out.parent / "icon.png")

# PWA icons.
for s in (144, 180, 512):
    rounded(full, s).save(out / f"pwa_{s}.png")

# macOS: rounded square with the standard ~10% margin.
mac = rounded(full, 1024, pad=0.1, radius=0.2)
mac.save(out.parent / "icon.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128),
                                          (256, 256), (512, 512), (1024, 1024)])

# Windows .ico.
rounded(full, 256, radius=0.18).save(
    out.parent / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

# Android legacy launcher icon.
rounded(full, 192).save(out / "android_192.png")

# Android adaptive icon: art must fit the central safe circle (66% of 432px).
bbox = fg.getbbox()
art = fg.crop(bbox)
diag = math.hypot(*art.size)
scale = 432 * 0.64 / diag
art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
fg432 = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
fg432.paste(art, ((432 - art.width) // 2, (432 - art.height) // 2), art)
fg432.save(out / "android_foreground_432.png")
bg.convert("RGB").resize((432, 432), Image.LANCZOS).save(out / "android_background_432.png")
# Monochrome (themed icons): foreground silhouette.
mono = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
mono.putalpha(fg432.getchannel("A"))
mono.save(out / "android_monochrome_432.png")

print("icons written to", out)
