#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROUTES = (
    {
        "path": "/discover",
        "title": "DineIn Guest",
        "description": "Discover nearby venues, browse live menus, and order from your table with DineIn.",
        "application_category": "FoodAndDrinkApplication",
    },
    {
        "path": "/venues",
        "title": "Browse Venues | DineIn",
        "description": "Browse nearby venues, compare live menus, and jump straight into your next table order with DineIn.",
        "application_category": "FoodAndDrinkApplication",
    },
)


def _replace_once(pattern: str, replacement: str, html: str) -> str:
    updated, count = re.subn(pattern, replacement, html, count=1, flags=re.DOTALL)
    if count != 1:
        raise RuntimeError(f"Expected exactly one match for pattern: {pattern}")
    return updated


def _build_hreflang_block(path: str, default_origin: str, mt_origin: str, rw_origin: str) -> str:
    return "\n".join(
        (
            "  <!-- dinein-hreflang:begin -->",
            f'  <link rel="alternate" hreflang="en-MT" href="{mt_origin}{path}">',
            f'  <link rel="alternate" hreflang="en-RW" href="{rw_origin}{path}">',
            f'  <link rel="alternate" hreflang="x-default" href="{default_origin}{path}">',
            "  <!-- dinein-hreflang:end -->",
        )
    )


def _inject_hreflang_block(html: str, block: str) -> str:
    existing_pattern = r"\n  <!-- dinein-hreflang:begin -->.*?<!-- dinein-hreflang:end -->"
    if re.search(existing_pattern, html, flags=re.DOTALL):
        return re.sub(existing_pattern, "\n" + block, html, count=1, flags=re.DOTALL)
    canonical_pattern = r'(<link rel="canonical" id="canonical-link" href="[^"]*">)'
    return _replace_once(canonical_pattern, r"\1\n" + block, html)


def _render_route_html(
    index_html: str,
    *,
    path: str,
    title: str,
    description: str,
    application_category: str,
    default_origin: str,
    mt_origin: str,
    rw_origin: str,
) -> str:
    canonical_url = f"{default_origin}{path}"
    share_image = f"{default_origin}/icons/Icon-512.png"
    structured_data = json.dumps(
        {
            "@context": "https://schema.org",
            "@type": "WebApplication",
            "name": title,
            "description": description,
            "applicationCategory": application_category,
            "operatingSystem": "Any",
            "url": canonical_url,
        },
        indent=2,
    )

    html = index_html
    html = _replace_once(r'<base href="[^"]*">', '<base href="/">', html)
    html = _replace_once(r"<title>.*?</title>", f"<title>{title}</title>", html)
    html = _replace_once(
        r'<meta name="description" content="[^"]*">',
        f'<meta name="description" content="{description}">',
        html,
    )
    html = _replace_once(
        r'<meta property="og:title" content="[^"]*">',
        f'<meta property="og:title" content="{title}">',
        html,
    )
    html = _replace_once(
        r'<meta property="og:description" content="[^"]*">',
        f'<meta property="og:description" content="{description}">',
        html,
    )
    html = _replace_once(
        r'<meta property="og:image" content="[^"]*">',
        f'<meta property="og:image" content="{share_image}">',
        html,
    )
    html = _replace_once(
        r'<meta property="og:url" content="[^"]*">',
        f'<meta property="og:url" content="{canonical_url}">',
        html,
    )
    html = _replace_once(
        r'<meta name="twitter:title" content="[^"]*">',
        f'<meta name="twitter:title" content="{title}">',
        html,
    )
    html = _replace_once(
        r'<meta name="twitter:description" content="[^"]*">',
        f'<meta name="twitter:description" content="{description}">',
        html,
    )
    html = _replace_once(
        r'<meta name="twitter:image" content="[^"]*">',
        f'<meta name="twitter:image" content="{share_image}">',
        html,
    )
    html = _replace_once(
        r'<link rel="canonical" id="canonical-link" href="[^"]*">',
        f'<link rel="canonical" id="canonical-link" href="{canonical_url}">',
        html,
    )
    html = _replace_once(
        r'(<script type="application/ld\+json" id="structured-data">\s*)(.*?)(\s*</script>)',
        r"\1" + structured_data + r"\3",
        html,
    )
    html = html.replace('href="icons/Icon-192.png"', 'href="/icons/Icon-192.png"')
    html = html.replace('href="favicon.png"', 'href="/favicon.png"')
    html = html.replace('href="manifest.json"', 'href="/manifest.json"')
    html = html.replace(
        'src="assets/assets/branding/dinein-brand-icon-512.png"',
        'src="/assets/assets/branding/dinein-brand-icon-512.png"',
    )
    html = html.replace('src="flutter_bootstrap.js"', 'src="/flutter_bootstrap.js"')
    return _inject_hreflang_block(
        html,
        _build_hreflang_block(path, default_origin, mt_origin, rw_origin),
    )


def main() -> int:
    if len(sys.argv) != 5:
        print(
            "Usage: prerender_public_routes.py <build_dir> <default_guest_origin> <mt_guest_origin> <rw_guest_origin>",
            file=sys.stderr,
        )
        return 1

    build_dir = Path(sys.argv[1]).resolve()
    default_origin = sys.argv[2].rstrip("/")
    mt_origin = sys.argv[3].rstrip("/")
    rw_origin = sys.argv[4].rstrip("/")

    index_path = build_dir / "index.html"
    if not index_path.is_file():
        print(f"Missing index.html in {build_dir}", file=sys.stderr)
        return 1

    index_html = index_path.read_text(encoding="utf-8")

    for route in ROUTES:
        rendered = _render_route_html(
            index_html,
            path=route["path"],
            title=route["title"],
            description=route["description"],
            application_category=route["application_category"],
            default_origin=default_origin,
            mt_origin=mt_origin,
            rw_origin=rw_origin,
        )
        target_dir = build_dir / route["path"].lstrip("/")
        target_dir.mkdir(parents=True, exist_ok=True)
        (target_dir / "index.html").write_text(rendered, encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
