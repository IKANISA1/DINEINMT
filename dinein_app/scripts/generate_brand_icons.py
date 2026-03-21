#!/usr/bin/env python3
"""Generate DINEIN brand app icons for Android, iOS, and Flutter preview.

Design spec (from user's provided logo):
  - Background: near-black (#141414)
  - "DINE" text: dark warm gold/bronze (#8B7A3D)
  - "IN" text: pure white (#FFFFFF)
  - Font: Bold italic sans-serif, large, centered
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT_DIR = Path(__file__).resolve().parents[1]
ANDROID_ICON_DIR = PROJECT_DIR / "android/app/src/main/res"
IOS_ICON_DIR = PROJECT_DIR / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
PREVIEW_DIR = PROJECT_DIR / "assets/branding"

# Exact colors from the user's provided logo
BACKGROUND = (20, 20, 20, 255)        # #141414 — near-black
GOLD = (139, 122, 61, 255)            # #8B7A3D — dark warm gold/bronze for "DINE"
WHITE = (255, 255, 255, 255)          # #FFFFFF — pure white for "IN"

FONT_CANDIDATES = [
    Path("/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf"),
    Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
    Path("/System/Library/Fonts/Helvetica Bold.ttf"),
    Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
]

ANDROID_TARGETS = {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}

IOS_TARGETS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def resolve_font() -> Path:
    for candidate in FONT_CANDIDATES:
        if candidate.exists():
            return candidate
    raise FileNotFoundError("No suitable bold system font found for icon generation.")


def build_master_icon(size: int, font_path: Path) -> Image.Image:
    """Build a master 1024x1024 icon matching the user's exact logo."""
    image = Image.new("RGBA", (size, size), BACKGROUND)
    draw = ImageDraw.Draw(image)

    # Font size: text should fill ~65-70% width, positioned slightly left of center vertically
    font_size = int(size * 0.23)
    font = ImageFont.truetype(str(font_path), font_size)

    # Measure full text
    full_text = "DINEIN"
    full_bbox = draw.textbbox((0, 0), full_text, font=font)
    full_width = full_bbox[2] - full_bbox[0]
    full_height = full_bbox[3] - full_bbox[1]

    # Center horizontally, slightly above center vertically (matching the logo)
    x = (size - full_width) / 2 - full_bbox[0]
    y = (size - full_height) / 2 - full_bbox[1] - size * 0.02

    # Draw "DINE" in dark gold
    draw.text((x, y), "DINE", font=font, fill=GOLD)

    # Measure "DINE" width to position "IN" right after
    dine_bbox = draw.textbbox((0, 0), "DINE", font=font)
    dine_width = dine_bbox[2] - dine_bbox[0]

    # Draw "IN" in white
    draw.text((x + dine_width, y), "IN", font=font, fill=WHITE)

    return image


def write_targets(master: Image.Image, targets: dict[str, int], base_dir: Path) -> None:
    for relative_path, target_size in targets.items():
        output_path = base_dir / relative_path
        output_path.parent.mkdir(parents=True, exist_ok=True)
        resized = master.resize((target_size, target_size), Image.Resampling.LANCZOS)
        resized.save(output_path)


def main() -> None:
    font_path = resolve_font()
    master = build_master_icon(1024, font_path)

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    master.save(PREVIEW_DIR / "dinein-brand-icon-1024.png")

    write_targets(master, ANDROID_TARGETS, ANDROID_ICON_DIR)
    write_targets(master, IOS_TARGETS, IOS_ICON_DIR)

    print(f"✅ Generated DINEIN brand icons using font: {font_path.name}")
    print(f"   Master: {PREVIEW_DIR / 'dinein-brand-icon-1024.png'}")
    print(f"   Android: {len(ANDROID_TARGETS)} icons")
    print(f"   iOS: {len(IOS_TARGETS)} icons")


if __name__ == "__main__":
    main()
