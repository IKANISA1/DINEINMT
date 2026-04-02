#!/usr/bin/env python3
"""Generate DINEIN launcher icons from the approved square master asset."""
from __future__ import annotations

from pathlib import Path

from PIL import Image


PROJECT_DIR = Path(__file__).resolve().parents[1]
ANDROID_ICON_DIR = PROJECT_DIR / "android/app/src/main/res"
IOS_ICON_DIR = PROJECT_DIR / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
WEB_ICON_DIR = PROJECT_DIR / "web/icons"
WEB_ROOT_DIR = PROJECT_DIR / "web"
PREVIEW_DIR = PROJECT_DIR / "assets/branding"
ADAPTIVE_ICON_DIR = ANDROID_ICON_DIR / "mipmap-anydpi-v26"
ANDROID_VALUES_DIR = ANDROID_ICON_DIR / "values"
SOURCE_ICON = PREVIEW_DIR / "dinein_logo.png"
BRAND_ICON_1024 = PREVIEW_DIR / "dinein-brand-icon-1024.png"
SOURCE_ICON_512 = PREVIEW_DIR / "dinein-brand-icon-512.png"

CONTENT_SCALE = 0.84
MASKABLE_CONTENT_SCALE = 0.78

ANDROID_TARGETS = {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}

ANDROID_ADAPTIVE_FOREGROUND_TARGETS = {
    "mipmap-mdpi/ic_launcher_foreground.png": 108,
    "mipmap-hdpi/ic_launcher_foreground.png": 162,
    "mipmap-xhdpi/ic_launcher_foreground.png": 216,
    "mipmap-xxhdpi/ic_launcher_foreground.png": 324,
    "mipmap-xxxhdpi/ic_launcher_foreground.png": 432,
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


ADAPTIVE_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""


def load_master_icon() -> Image.Image:
    if not SOURCE_ICON.exists():
        raise FileNotFoundError(f"Missing launcher source asset: {SOURCE_ICON}")

    image = Image.open(SOURCE_ICON).convert("RGBA")
    if image.size != (1024, 1024):
        image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    return image


def render_square(
    master: Image.Image,
    target_size: int,
    content_scale: float = CONTENT_SCALE,
) -> Image.Image:
    background = master.getpixel((0, 0))
    content_size = max(1, min(target_size, round(target_size * content_scale)))
    content = master.resize((content_size, content_size), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), background)
    offset = ((target_size - content_size) // 2, (target_size - content_size) // 2)
    canvas.paste(content, offset, content)
    return canvas


def write_targets(
    master: Image.Image,
    targets: dict[str, int],
    base_dir: Path,
    content_scale: float = CONTENT_SCALE,
) -> None:
    for relative_path, target_size in targets.items():
        output_path = base_dir / relative_path
        output_path.parent.mkdir(parents=True, exist_ok=True)
        render_square(master, target_size, content_scale).save(output_path)


def write_text(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8")


def to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def write_adaptive_resources(master: Image.Image) -> None:
    bg_hex = to_hex(master.getpixel((0, 0))[:3])
    colors_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{bg_hex}</color>
</resources>
"""
    write_text(ANDROID_VALUES_DIR / "colors.xml", colors_xml)
    write_text(ADAPTIVE_ICON_DIR / "ic_launcher.xml", ADAPTIVE_ICON_XML)
    write_text(ADAPTIVE_ICON_DIR / "ic_launcher_round.xml", ADAPTIVE_ICON_XML)


def write_web_targets(master: Image.Image) -> None:
    web_targets = {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }
    for relative_path, target_size in web_targets.items():
        content_scale = MASKABLE_CONTENT_SCALE if "maskable" in relative_path else CONTENT_SCALE
        output_path = WEB_ICON_DIR / relative_path
        output_path.parent.mkdir(parents=True, exist_ok=True)
        render_square(master, target_size, content_scale).save(output_path)

    render_square(master, 16, CONTENT_SCALE).save(WEB_ROOT_DIR / "favicon.png")


def main() -> None:
    master = load_master_icon()

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    write_targets(
        master,
        {
            BRAND_ICON_1024.name: 1024,
            SOURCE_ICON_512.name: 512,
        },
        PREVIEW_DIR,
    )
    write_targets(master, ANDROID_TARGETS, ANDROID_ICON_DIR)
    write_targets(master, ANDROID_ADAPTIVE_FOREGROUND_TARGETS, ANDROID_ICON_DIR)
    write_targets(master, IOS_TARGETS, IOS_ICON_DIR)
    write_web_targets(master)
    write_adaptive_resources(master)

    print(f"✅ Generated DINEIN launcher icons from: {SOURCE_ICON.name}")
    print(f"   App master: {SOURCE_ICON_512.name} (512x512)")
    print(
        "   Android: "
        f"{len(ANDROID_TARGETS)} legacy + "
        f"{len(ANDROID_ADAPTIVE_FOREGROUND_TARGETS)} adaptive foreground icons"
    )
    print(f"   iOS: {len(IOS_TARGETS)} icons")
    print("   Web: 192/512 standard and maskable icons + favicon")
    print(f"   Adaptive XML: {ADAPTIVE_ICON_DIR}")


if __name__ == "__main__":
    main()
