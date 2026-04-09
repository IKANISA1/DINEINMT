#!/usr/bin/env python3
"""Validate required app icon asset dimensions for release artifacts."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


PROJECT_DIR = Path(__file__).resolve().parents[1]

EXPECTED_SIZES: dict[Path, tuple[int, int]] = {
    PROJECT_DIR / "assets/branding/dinein_logo.png": (1024, 1024),
    PROJECT_DIR / "assets/branding/dinein-brand-icon-1024.png": (1024, 1024),
    PROJECT_DIR / "assets/branding/dinein-brand-icon-512.png": (512, 512),
    PROJECT_DIR / "web/icons/Icon-512.png": (512, 512),
    PROJECT_DIR / "web/icons/Icon-maskable-512.png": (512, 512),
}


def validate_image(path: Path, expected_size: tuple[int, int]) -> list[str]:
    if not path.exists():
        return [f"FAIL: Missing icon asset: {path}"]

    try:
        with Image.open(path) as image:
            actual_size = image.size
    except Exception as exc:  # pragma: no cover - failure path
        return [f"FAIL: Could not read icon asset {path}: {exc}"]

    if actual_size != expected_size:
        return [
            f"FAIL: {path} must be {expected_size[0]}x{expected_size[1]}, "
            f"found {actual_size[0]}x{actual_size[1]}"
        ]

    return []


def main() -> int:
    errors: list[str] = []
    for path, expected_size in EXPECTED_SIZES.items():
        errors.extend(validate_image(path, expected_size))

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("PASS: App icon assets validated, including 512x512 release icons.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
