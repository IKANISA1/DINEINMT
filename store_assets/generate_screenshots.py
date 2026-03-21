#!/usr/bin/env python3
"""
DineIn Malta — App Store Screenshot Generator
==============================================
Composites real app screenshots into store-ready framed images with
Claymorphism / Glassmorphism backgrounds + soft gradient + marketing headlines.

Usage:
    python3 generate_screenshots.py
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ─── Paths ────────────────────────────────────────────────────────
SRC_DIR = os.path.expanduser("~/Desktop/Screenshots")
OUT_ROOT = "/Volumes/PRO-G40/DINEIN MALTA/store_assets"

# ─── Brand Colors ─────────────────────────────────────────────────
BG_DARK = (10, 10, 10)
BG_MID = (26, 24, 18)
BRAND_GOLD = (196, 164, 105)
BRAND_GOLD_LIGHT = (220, 195, 140)
WHITE = (255, 255, 255)
GLASS_BORDER = (255, 255, 255, 30)  # 12% white
GLASS_FILL = (30, 30, 30, 153)  # ~60% opacity dark

# ─── Phone screenshots (source filename → headline) ──────────────
PHONE_SCREENSHOTS = [
    ("Screenshot 2026-03-21 at 17.00.31.png", "Discover Malta's\nBest Dining"),
    ("Screenshot 2026-03-21 at 17.12.15.png", "Browse Featured\nEstablishments"),
    ("Screenshot 2026-03-21 at 17.13.16.png", "Stunning Menu\nHighlights"),
    ("Screenshot 2026-03-21 at 17.11.20.png", "Easy & Flexible\nPayments"),
    ("Screenshot 2026-03-21 at 16.34.04.png", "Venue Dashboard\nat a Glance"),
    ("Screenshot 2026-03-21 at 16.34.35.png", "Real-Time Order\nManagement"),
    ("Screenshot 2026-03-21 at 16.34.57.png", "Full Menu\nControl"),
    ("Screenshot 2026-03-21 at 16.35.23.png", "Complete Venue\nSettings"),
]

TABLET_SCREENSHOTS = [
    ("Screenshot 2026-03-21 at 17.15.52.png", "Add & Manage\nYour Venue"),
    ("Screenshot 2026-03-21 at 17.13.16.png", "Explore Menu\nHighlights"),
    ("Screenshot 2026-03-21 at 17.12.28.png", "Featured Venues\nIn Malta"),
    ("Screenshot 2026-03-21 at 17.17.09.png", "Order Tracking\n& Analytics"),
    ("Screenshot 2026-03-21 at 17.14.04.png", "Powerful Venue\nManagement"),
]

# ─── Output dimensions ────────────────────────────────────────────
PHONE_SIZES = {
    "ios/iphone_6_9": (1320, 2868),
    "ios/iphone_6_7": (1290, 2796),
    "ios/iphone_6_5": (1284, 2778),
    "android/phone": (1080, 1920),
    "android/phone_tall": (1080, 2400),
}

TABLET_SIZES = {
    "ios/ipad_13": (2048, 2732),
    "ios/ipad_11": (1668, 2388),
    "android/tablet_7": (1200, 1920),
    "android/tablet_10": (1920, 1200),  # landscape
}


def get_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    """Try to load a system font; fall back to default."""
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFPro.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_radial_gradient(img: Image.Image, center: tuple, radius: float,
                          inner_color: tuple, outer_color: tuple) -> Image.Image:
    """Draw a soft radial gradient bloom on the image."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    steps = 80
    for i in range(steps, 0, -1):
        t = i / steps
        r = int(radius * t)
        # Interpolate color
        color = tuple(
            int(inner_color[c] * t + outer_color[c] * (1 - t))
            for c in range(3)
        )
        alpha = int(40 * t)  # subtle
        cx, cy = center
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(*color, alpha),
        )
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def create_background(width: int, height: int) -> Image.Image:
    """Create the dark gradient background with subtle gold radial bloom."""
    img = Image.new("RGBA", (width, height), (*BG_DARK, 255))
    draw = ImageDraw.Draw(img)

    # Vertical gradient: dark → slightly warm → dark
    for y in range(height):
        t = y / height
        # Peak warmth at ~35% from top
        warmth = math.exp(-((t - 0.35) ** 2) / 0.08) * 0.3
        r = int(BG_DARK[0] + (BG_MID[0] - BG_DARK[0]) * warmth)
        g = int(BG_DARK[1] + (BG_MID[1] - BG_DARK[1]) * warmth)
        b = int(BG_DARK[2] + (BG_MID[2] - BG_DARK[2]) * warmth)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # Radial gold bloom at ~30% from top, centered
    img = draw_radial_gradient(
        img,
        center=(width // 2, int(height * 0.28)),
        radius=min(width, height) * 0.5,
        inner_color=BRAND_GOLD,
        outer_color=BG_DARK,
    )
    return img


def draw_glass_card(draw: ImageDraw.Draw, img: Image.Image,
                     x: int, y: int, w: int, h: int, corner_r: int = 24):
    """Draw a glassmorphism card with frosted border and translucent fill."""
    # Glass fill
    glass = Image.new("RGBA", img.size, (0, 0, 0, 0))
    glass_draw = ImageDraw.Draw(glass)
    glass_draw.rounded_rectangle(
        [x, y, x + w, y + h],
        radius=corner_r,
        fill=GLASS_FILL,
        outline=GLASS_BORDER,
        width=2,
    )
    return Image.alpha_composite(img, glass)


def draw_headline(draw: ImageDraw.Draw, text: str,
                   x: int, y: int, max_width: int, font_size: int):
    """Draw DINEIN-styled headline: first word gold, rest white."""
    font = get_font(font_size)
    lines = text.split("\n")
    line_y = y
    for line in lines:
        # Get text size
        bbox = draw.textbbox((0, 0), line, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        # Center horizontally
        tx = x + (max_width - text_width) // 2
        draw.text((tx, line_y), line, fill=WHITE, font=font)
        line_y += text_height + int(font_size * 0.15)


def add_device_frame(screenshot: Image.Image, frame_w: int, frame_h: int,
                      corner_r: int = 32) -> Image.Image:
    """
    Place screenshot into a device frame with rounded corners and subtle shadow.
    """
    # Resize screenshot to fit within frame
    src_w, src_h = screenshot.size
    scale = min(frame_w / src_w, frame_h / src_h)
    new_w = int(src_w * scale)
    new_h = int(src_h * scale)
    resized = screenshot.resize((new_w, new_h), Image.LANCZOS)

    # Create frame with rounded corners
    frame = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 0))
    mask = Image.new("L", (new_w, new_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, new_w, new_h], radius=corner_r, fill=255)
    frame.paste(resized.convert("RGBA"), (0, 0))
    frame.putalpha(mask)

    # Add subtle border
    border_overlay = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_overlay)
    border_draw.rounded_rectangle(
        [0, 0, new_w - 1, new_h - 1],
        radius=corner_r,
        outline=(255, 255, 255, 40),
        width=3,
    )
    frame = Image.alpha_composite(frame, border_overlay)

    return frame


def compose_store_image(
    source_path: str,
    headline: str,
    output_w: int,
    output_h: int,
    is_tablet: bool = False,
) -> Image.Image:
    """
    Compose a single store-ready screenshot image.
    """
    # 1. Create background
    bg = create_background(output_w, output_h)

    # 2. Load source screenshot
    src = Image.open(source_path).convert("RGBA")

    # 3. Calculate layout
    padding_x = int(output_w * 0.08)
    headline_area_top = int(output_h * 0.04)
    glass_card_h = int(output_h * 0.12)
    glass_card_y = headline_area_top
    glass_card_x = padding_x
    glass_card_w = output_w - 2 * padding_x

    # Device frame area
    device_top = glass_card_y + glass_card_h + int(output_h * 0.03)
    device_bottom = output_h - int(output_h * 0.04)
    device_h = device_bottom - device_top
    device_w = output_w - 2 * padding_x

    if is_tablet and output_w > output_h:
        # Landscape tablet: wider frame, less padding
        padding_x = int(output_w * 0.05)
        device_w = output_w - 2 * padding_x
        glass_card_w = output_w - 2 * padding_x
        glass_card_x = padding_x

    # 4. Draw glass card
    corner_r = int(min(glass_card_w, glass_card_h) * 0.12)
    bg = draw_glass_card(
        ImageDraw.Draw(bg), bg,
        glass_card_x, glass_card_y,
        glass_card_w, glass_card_h,
        corner_r=corner_r,
    )

    # 5. Draw headline text
    draw = ImageDraw.Draw(bg)
    font_size = int(output_h * 0.032)
    text_y = glass_card_y + int(glass_card_h * 0.15)
    draw_headline(draw, headline, glass_card_x, text_y, glass_card_w, font_size)

    # 6. Add device frame with screenshot
    device_corner_r = int(min(device_w, device_h) * 0.04)
    framed = add_device_frame(src, device_w, device_h, corner_r=device_corner_r)

    # Center the framed device
    fw, fh = framed.size
    device_x = (output_w - fw) // 2
    device_y_actual = device_top + (device_h - fh) // 2

    # Add drop shadow
    shadow = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    shadow_offset = max(4, int(output_w * 0.005))
    blur_r = max(12, int(output_w * 0.012))

    # Create shadow shape
    shadow_mask = Image.new("L", (fw, fh), 0)
    sd = ImageDraw.Draw(shadow_mask)
    sd.rounded_rectangle([0, 0, fw, fh], radius=device_corner_r, fill=80)
    shadow.paste(
        Image.new("RGBA", (fw, fh), (0, 0, 0, 80)),
        (device_x + shadow_offset, device_y_actual + shadow_offset),
        shadow_mask,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur_r))
    bg = Image.alpha_composite(bg, shadow)

    # Paste the framed screenshot
    bg.paste(framed, (device_x, device_y_actual), framed)

    return bg


def process_screenshots():
    """Generate all store-ready screenshots."""
    total = 0

    # ─── Phone screenshots ───
    for filename, headline in PHONE_SCREENSHOTS:
        src_path = os.path.join(SRC_DIR, filename)
        if not os.path.exists(src_path):
            print(f"  ⚠ Missing: {filename}")
            continue

        for folder, (w, h) in PHONE_SIZES.items():
            out_dir = os.path.join(OUT_ROOT, folder)
            os.makedirs(out_dir, exist_ok=True)
            idx = PHONE_SCREENSHOTS.index((filename, headline)) + 1
            out_path = os.path.join(out_dir, f"{idx:02d}_{headline.split(chr(10))[0].lower().replace(' ', '_').replace("'", '')}.png")

            print(f"  📱 {folder}/{os.path.basename(out_path)} ({w}×{h})")
            img = compose_store_image(src_path, headline, w, h, is_tablet=False)
            img.convert("RGB").save(out_path, "PNG", optimize=True)
            total += 1

    # ─── Tablet screenshots ───
    for filename, headline in TABLET_SCREENSHOTS:
        src_path = os.path.join(SRC_DIR, filename)
        if not os.path.exists(src_path):
            print(f"  ⚠ Missing: {filename}")
            continue

        for folder, (w, h) in TABLET_SIZES.items():
            out_dir = os.path.join(OUT_ROOT, folder)
            os.makedirs(out_dir, exist_ok=True)
            idx = TABLET_SCREENSHOTS.index((filename, headline)) + 1
            out_path = os.path.join(out_dir, f"{idx:02d}_{headline.split(chr(10))[0].lower().replace(' ', '_').replace("'", '')}.png")

            print(f"  📱 {folder}/{os.path.basename(out_path)} ({w}×{h})")
            img = compose_store_image(src_path, headline, w, h, is_tablet=True)
            img.convert("RGB").save(out_path, "PNG", optimize=True)
            total += 1

    print(f"\n✅ Generated {total} store-ready screenshots in {OUT_ROOT}")


if __name__ == "__main__":
    print("🎨 DineIn Malta — Store Screenshot Generator")
    print("=" * 50)
    process_screenshots()
