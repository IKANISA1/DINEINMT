#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


EXCLUDED_RELATIVE_PATHS = {
    ".last_build_id",
    "_headers",
    "_redirects",
    "custom_sw.js",
    "flutter_service_worker.js",
    "pwa-shell-manifest.json",
}
EXCLUDED_SUFFIXES = (".map", ".symbols")
PRIORITY_ASSETS = [
    "/index.html",
    "/offline.html",
    "/manifest.json",
    "/flutter.js",
    "/flutter_bootstrap.js",
    "/main.dart.js",
]
FLUTTER_LOCKED_VIEWPORT = (
    "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
)
ACCESSIBLE_VIEWPORT = "width=device-width, initial-scale=1.0, viewport-fit=cover"


def should_include(rel_path: str) -> bool:
    if rel_path in EXCLUDED_RELATIVE_PATHS:
        return False
    return not rel_path.endswith(EXCLUDED_SUFFIXES)


def sort_resources(resources: list[str]) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()
    for asset in PRIORITY_ASSETS:
        if asset in resources and asset not in seen:
            ordered.append(asset)
            seen.add(asset)
    for asset in resources:
        if asset not in seen:
            ordered.append(asset)
            seen.add(asset)
    return ordered


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: stamp_pwa_bundle.py <build-web-dir>", file=sys.stderr)
        return 1

    build_dir = Path(sys.argv[1]).resolve()
    if not build_dir.is_dir():
        print(f"Build directory does not exist: {build_dir}", file=sys.stderr)
        return 1

    custom_sw_path = build_dir / "custom_sw.js"
    if not custom_sw_path.is_file():
        print(f"Missing custom service worker: {custom_sw_path}", file=sys.stderr)
        return 1

    main_js_path = build_dir / "main.dart.js"
    if main_js_path.is_file():
        main_js_contents = main_js_path.read_text(encoding="utf-8")
        if FLUTTER_LOCKED_VIEWPORT in main_js_contents:
            main_js_path.write_text(
                main_js_contents.replace(FLUTTER_LOCKED_VIEWPORT, ACCESSIBLE_VIEWPORT),
                encoding="utf-8",
            )
            print("Patched Flutter's generated viewport meta to keep browser zoom enabled.")

    resources: list[str] = []
    digest = hashlib.sha256()

    for path in sorted(build_dir.rglob("*")):
        if not path.is_file():
            continue
        rel_path = path.relative_to(build_dir).as_posix()
        if not should_include(rel_path):
            continue
        resources.append(f"/{rel_path}")
        digest.update(rel_path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")

    resources = sort_resources(resources)
    version = digest.hexdigest()[:20]

    shell_manifest_path = build_dir / "pwa-shell-manifest.json"
    shell_manifest_path.write_text(
        json.dumps({"version": version, "resources": resources}, indent=2) + "\n",
        encoding="utf-8",
    )

    index_path = build_dir / "index.html"
    index_contents = index_path.read_text(encoding="utf-8")
    index_contents = index_contents.replace("__DINEIN_PWA_VERSION__", version)
    if "__DINEIN_PWA_" in index_contents:
        print("index.html still contains unresolved PWA placeholders.", file=sys.stderr)
        return 1
    index_path.write_text(index_contents, encoding="utf-8")

    bootstrap_path = build_dir / "flutter_bootstrap.js"
    if bootstrap_path.is_file():
        bootstrap_contents = bootstrap_path.read_text(encoding="utf-8")
        versioned_main_path = f'"mainJsPath":"main.dart.js?v={version}"'
        if versioned_main_path not in bootstrap_contents:
            if '"mainJsPath":"main.dart.js"' not in bootstrap_contents:
                print(
                    "flutter_bootstrap.js is missing the expected mainJsPath marker.",
                    file=sys.stderr,
                )
                return 1
            bootstrap_contents = bootstrap_contents.replace(
                '"mainJsPath":"main.dart.js"',
                versioned_main_path,
                1,
            )
            bootstrap_path.write_text(bootstrap_contents, encoding="utf-8")

    sw_contents = custom_sw_path.read_text(encoding="utf-8")
    sw_contents = sw_contents.replace("__DINEIN_PWA_VERSION__", version)
    sw_contents = sw_contents.replace(
        "__DINEIN_PWA_SHELL_ASSETS__",
        json.dumps(resources, indent=2),
    )
    if "__DINEIN_PWA_" in sw_contents:
        print("Service worker still contains unresolved PWA placeholders.", file=sys.stderr)
        return 1
    custom_sw_path.write_text(sw_contents, encoding="utf-8")

    flutter_sw_path = build_dir / "flutter_service_worker.js"
    if flutter_sw_path.exists():
        flutter_sw_path.unlink()

    print(
        f"Stamped custom_sw.js with version {version} and {len(resources)} cached resources."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
