#!/usr/bin/env python3
"""Generate Android and iOS launcher icons from the Capibara logo.

Usage:
    python3 scripts/generate_launcher_icons.py
"""

from __future__ import annotations

import json
import pathlib
import sys

from PIL import Image

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
MASCOT_PATH = REPO_ROOT / "assets/branding/capibara_icon.jpg"
BG_COLOR = (255, 255, 255, 255)  # White — matches logo background


def _load_mascot() -> Image.Image:
    """Load the mascot and convert to RGBA.
    JPEGs have no alpha; treat white background as-is."""
    img = Image.open(MASCOT_PATH).convert("RGBA")
    return img


def create_adaptive_foreground(mascot: Image.Image, size: int) -> Image.Image:
    """Adaptive foreground layer: mascot centered in 108dp safe zone."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Android safe zone is the central ~66% of 108dp
    mascot_size = int(size * 0.67)
    scaled = mascot.resize((mascot_size, mascot_size), Image.Resampling.LANCZOS)
    offset = (size - mascot_size) // 2
    # Paste without alpha mask (JPEG image, white BG is opaque)
    canvas.paste(scaled, (offset, offset))
    return canvas


def create_adaptive_background(size: int) -> Image.Image:
    return Image.new("RGBA", (size, size), BG_COLOR)


def create_adaptive_monochrome(mascot: Image.Image, size: int) -> Image.Image:
    """Monochrome layer: dark silhouette using luminance mask."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mascot_size = int(size * 0.67)
    scaled = mascot.resize((mascot_size, mascot_size), Image.Resampling.LANCZOS)
    # Use inverted luminance as alpha (dark logo areas become opaque dark ink)
    gray = scaled.convert("L")
    # Invert: dark pixels become high alpha
    alpha = gray.point(lambda p: max(0, 255 - p))
    dark_ink = Image.new("L", (mascot_size, mascot_size), 38)
    mono = Image.merge("RGBA", (dark_ink, dark_ink, dark_ink, alpha))
    offset = (size - mascot_size) // 2
    canvas.paste(mono, (offset, offset), mono)
    return canvas


def create_full_icon(mascot: Image.Image, size: int) -> Image.Image:
    """Square icon: mascot on white background, scaled to 90%."""
    canvas = Image.new("RGBA", (size, size), BG_COLOR)
    mascot_size = int(size * 0.90)
    scaled = mascot.resize((mascot_size, mascot_size), Image.Resampling.LANCZOS)
    offset = (size - mascot_size) // 2
    canvas.paste(scaled, (offset, offset))
    return canvas


def main() -> int:
    if not MASCOT_PATH.exists():
        sys.stderr.write(f"Icon source not found at {MASCOT_PATH}\n")
        sys.stderr.write("Copy capibara_icon.jpg to assets/branding/ first.\n")
        return 1

    mascot = _load_mascot()
    print(f"Loaded mascot: {mascot.size} {mascot.mode}")

    # 1. Android densities
    android_densities = {
        "mipmap-mdpi":    {"legacy": 48,  "adaptive": 108},
        "mipmap-hdpi":    {"legacy": 72,  "adaptive": 162},
        "mipmap-xhdpi":   {"legacy": 96,  "adaptive": 216},
        "mipmap-xxhdpi":  {"legacy": 144, "adaptive": 324},
        "mipmap-xxxhdpi": {"legacy": 192, "adaptive": 432},
    }

    android_roots = [
        REPO_ROOT / "android/app/src/main/res",
        REPO_ROOT / "apps/companion/android/app/src/main/res",
    ]

    for res_dir in android_roots:
        anydpi_dir = res_dir / "mipmap-anydpi-v26"
        anydpi_dir.mkdir(parents=True, exist_ok=True)
        xml_path = anydpi_dir / "ic_launcher.xml"
        xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""
        xml_path.write_text(xml_content)

        for density, sizes in android_densities.items():
            d_dir = res_dir / density
            d_dir.mkdir(parents=True, exist_ok=True)

            legacy_icon = create_full_icon(mascot, sizes["legacy"])
            legacy_icon.save(d_dir / "ic_launcher.png", "PNG")

            bg_icon = create_adaptive_background(sizes["adaptive"])
            bg_icon.save(d_dir / "ic_launcher_background.png", "PNG")

            fg_icon = create_adaptive_foreground(mascot, sizes["adaptive"])
            fg_icon.save(d_dir / "ic_launcher_foreground.png", "PNG")

            mono_icon = create_adaptive_monochrome(mascot, sizes["adaptive"])
            mono_icon.save(d_dir / "ic_launcher_monochrome.png", "PNG")

        print(f"Generated Android icons in {res_dir}")

    # 2. iOS Icons
    ios_iconset_dir = (
        REPO_ROOT
        / "apps/companion/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    )
    contents_path = ios_iconset_dir / "Contents.json"

    if contents_path.exists():
        contents = json.loads(contents_path.read_text())
        for item in contents.get("images", []):
            filename = item.get("filename")
            if not filename:
                continue
            size_str = item.get("size", "0x0")
            scale_str = item.get("scale", "1x")
            base_w, base_h = [float(x) for x in size_str.split("x")]
            scale = float(scale_str.replace("x", ""))
            w = int(round(base_w * scale))
            h = int(round(base_h * scale))

            icon = create_full_icon(mascot, w)
            icon.save(ios_iconset_dir / filename, "PNG")
            print(f"Generated iOS icon {filename} ({w}x{h})")

    # 3. Web icons
    web_dir = REPO_ROOT / "web"
    web_icons_dir = web_dir / "icons"
    web_icons_dir.mkdir(parents=True, exist_ok=True)

    favicon = create_full_icon(mascot, 16)
    favicon.save(web_dir / "favicon.png", "PNG")
    print("Generated web/favicon.png")

    for web_size in [192, 512]:
        web_icon = create_full_icon(mascot, web_size)
        web_icon.save(web_icons_dir / f"Icon-{web_size}.png", "PNG")
        web_icon.save(web_icons_dir / f"Icon-maskable-{web_size}.png", "PNG")
        print(f"Generated web/icons/Icon-{web_size}.png and Icon-maskable-{web_size}.png")

    print("All launcher icons successfully generated!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
