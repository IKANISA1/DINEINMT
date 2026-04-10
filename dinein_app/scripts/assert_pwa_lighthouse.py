#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


PROFILE_THRESHOLDS = {
    "landing": {
        "categories": {
            "performance": 0.85,
            "accessibility": 0.98,
            "best-practices": 0.95,
            "seo": 0.95,
        },
        "metrics": {
            "largest-contentful-paint": 2500,
            "total-blocking-time": 200,
            "cumulative-layout-shift": 0.10,
        },
    },
    "guest": {
        "categories": {
            "performance": 0.85,
            "accessibility": 0.98,
            "best-practices": 0.95,
            "seo": 0.95,
        },
        "metrics": {
            "largest-contentful-paint": 2500,
            "total-blocking-time": 200,
            "cumulative-layout-shift": 0.10,
        },
    },
    "venue": {
        "categories": {
            "performance": 0.70,
            "accessibility": 0.95,
            "best-practices": 0.95,
            "seo": 0.90,
        },
        "metrics": {
            "largest-contentful-paint": 3000,
            "total-blocking-time": 300,
            "cumulative-layout-shift": 0.10,
        },
    },
    "admin": {
        "categories": {
            "performance": 0.70,
            "accessibility": 0.95,
            "best-practices": 0.95,
            "seo": 0.90,
        },
        "metrics": {
            "largest-contentful-paint": 3000,
            "total-blocking-time": 300,
            "cumulative-layout-shift": 0.10,
        },
    },
}
OPTIONAL_PWA_SIGNAL_AUDITS = [
    "service-worker",
    "installable-manifest",
    "maskable-icon",
]
REQUIRED_GO_LIVE_AUDITS = {
    "deprecations": 1,
}


def load_report(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def infer_profile(path: Path) -> str | None:
    stem = path.stem.lower()
    if "landing" in stem:
        return "landing"
    if "guest" in stem or "discover" in stem or "venues" in stem:
        return "guest"
    if "venue" in stem:
        return "venue"
    if "admin" in stem:
        return "admin"
    return None


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "Usage: assert_pwa_lighthouse.py <report.json> [report.json ...]",
            file=sys.stderr,
        )
        return 1

    failures: list[str] = []

    for raw_path in sys.argv[1:]:
        path = Path(raw_path)
        profile = infer_profile(path)
        report = load_report(path)
        categories = report.get("categories", {})
        audits = report.get("audits", {})

        if profile is None:
            failures.append(f"{path}: could not infer route profile from filename.")
            continue

        thresholds = PROFILE_THRESHOLDS[profile]

        for category_name, minimum_score in thresholds["categories"].items():
            category = categories.get(category_name)
            score = None if category is None else category.get("score")
            if score is None or score < minimum_score:
                failures.append(
                    f"{path}: category '{category_name}' scored {score!r}, expected >= {minimum_score:.2f}."
                )

        for audit_name, required_score in REQUIRED_GO_LIVE_AUDITS.items():
            audit = audits.get(audit_name)
            score = None if audit is None else audit.get("score")
            if score != required_score:
                failures.append(
                    f"{path}: audit '{audit_name}' scored {score!r}, expected {required_score}."
                )

        for metric_name, maximum_value in thresholds["metrics"].items():
            metric = audits.get(metric_name, {})
            numeric_value = metric.get("numericValue")
            if numeric_value is None or numeric_value > maximum_value:
                failures.append(
                    f"{path}: metric '{metric_name}' measured {numeric_value!r}, expected <= {maximum_value}."
                )

        available_pwa_audits = {}
        for audit_name in OPTIONAL_PWA_SIGNAL_AUDITS:
            audit = audits.get(audit_name)
            if audit is None:
                continue
            available_pwa_audits[audit_name] = audit.get("score")
            if audit.get("score") != 1:
                failures.append(
                    f"{path}: audit '{audit_name}' scored {audit.get('score')!r}, expected 1."
                )

        summary_metrics = {
            "lcp": audits.get("largest-contentful-paint", {}).get("numericValue"),
            "tbt": audits.get("total-blocking-time", {}).get("numericValue"),
            "cls": audits.get("cumulative-layout-shift", {}).get("numericValue"),
        }
        print(
            f"{path.name}: profile={profile} "
            f"scores=performance={categories.get('performance', {}).get('score')} "
            f"accessibility={categories.get('accessibility', {}).get('score')} "
            f"best-practices={categories.get('best-practices', {}).get('score')} "
            f"seo={categories.get('seo', {}).get('score')} "
            f"optional_pwa_audits={available_pwa_audits} "
            f"metrics={summary_metrics}"
        )

    if failures:
        print("PWA Lighthouse assertions failed:", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    print("PWA Lighthouse assertions passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
