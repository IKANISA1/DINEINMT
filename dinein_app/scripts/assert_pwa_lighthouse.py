#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


ROUTE_THRESHOLDS = {
    "guest": {
        "performance": 0.55,
        "accessibility": 0.95,
        "seo": 0.60,
    },
    "venue": {
        "performance": 0.25,
        "accessibility": 0.95,
        "seo": 0.60,
    },
    "admin": {
        "performance": 0.25,
        "accessibility": 0.95,
        "seo": 0.60,
    },
}
PWA_SIGNAL_AUDITS = [
    "service-worker",
    "installable-manifest",
    "maskable-icon",
]


def load_report(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: assert_pwa_lighthouse.py <guest.json> [venue.json ...]", file=sys.stderr)
        return 1

    failures: list[str] = []

    for raw_path in sys.argv[1:]:
        path = Path(raw_path)
        route = path.stem
        report = load_report(path)
        categories = report.get("categories", {})
        audits = report.get("audits", {})
        thresholds = ROUTE_THRESHOLDS.get(route)
        if thresholds is None:
            failures.append(f"{path}: no thresholds configured for route '{route}'.")
            continue

        for category_name, minimum_score in thresholds.items():
            category = categories.get(category_name)
            score = None if category is None else category.get("score")
            if score is None or score < minimum_score:
                failures.append(
                    f"{path}: category '{category_name}' scored {score!r}, expected >= {minimum_score:.2f}."
                )

        available_pwa_audits = 0
        for audit_name in PWA_SIGNAL_AUDITS:
            audit = audits.get(audit_name)
            if audit is None:
                continue
            available_pwa_audits += 1
            score = audit.get("score")
            if score != 1:
                failures.append(f"{path}: audit '{audit_name}' scored {score!r}, expected 1.")

        if available_pwa_audits != len(PWA_SIGNAL_AUDITS):
            missing = [
                audit_name
                for audit_name in PWA_SIGNAL_AUDITS
                if audits.get(audit_name) is None
            ]
            failures.append(
                f"{path}: missing required PWA audits: {', '.join(missing)}."
            )

        metrics = {
            "lcp": audits.get("largest-contentful-paint", {}).get("numericValue"),
            "tbt": audits.get("total-blocking-time", {}).get("numericValue"),
            "cls": audits.get("cumulative-layout-shift", {}).get("numericValue"),
        }
        print(f"{route}: scores="
              f"performance={categories.get('performance', {}).get('score')} "
              f"accessibility={categories.get('accessibility', {}).get('score')} "
              f"seo={categories.get('seo', {}).get('score')} "
              f"pwa_audits_present={available_pwa_audits} "
              f"metrics={metrics}")

    if failures:
        print("PWA Lighthouse assertions failed:", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    print("PWA Lighthouse assertions passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
