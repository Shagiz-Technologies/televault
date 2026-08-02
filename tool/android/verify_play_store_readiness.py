#!/usr/bin/env python3
"""Source-level Google Play release policy checks for TeleVault.

This complements, but does not replace, the merged-AAB and manual Play Console
review. It intentionally checks only stable repository invariants.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


REQUIRED_DOCUMENTS = (
    "docs/play-store/APP_ACCESS.md",
    "docs/play-store/DATA_SAFETY_WORKSHEET.md",
    "docs/play-store/PHOTO_VIDEO_PERMISSION_DECLARATION.md",
    "docs/play-store/FOREGROUND_SERVICE_DECLARATION.md",
    "docs/play-store/STORE_LISTING_COPY.md",
    "docs/play-store/RELEASE_CHECKLIST.md",
    "docs/play-store/REVIEW_VIDEO_SCRIPT.md",
)

FORBIDDEN_MARKERS = (
    "PRIVACY_CONTACT_EMAIL_REQUIRED",
    "we are too broke",
    "feed it to an ai model",
    "android does not care about our feelings",
)

MISLEADING_STORE_CLAIMS = (
    "unlimited cloud storage",
    "total privacy",
    "instant backup",
    "end-to-end encrypted backups",
)

REQUIRED_PRIVACY_MARKERS = (
    "not affiliated with, endorsed by, or sponsored by Telegram",
    "Normal non-vault photos and videos are not client-side end-to-end encrypted",
    "Android may delay, pause, or stop background work",
    "do not automatically delete Telegram channels",
    "Vault Recovery Key",
)

REQUIRED_LOGIN_MARKERS = (
    "Terms of Service",
    "Privacy Policy",
)

FORBIDDEN_DEPENDENCIES = (
    "google_sign_in:",
    "googleapis:",
    "googleapis_auth:",
    "firebase_analytics:",
    "google_mobile_ads:",
)

FORBIDDEN_REVIEW_ACCESS_MARKERS = (
    "99966XYYYY",
    "XXXXX",
    "TELEVAULT_PLAY_REVIEW=true",
    "Google Play reviewer access",
)

REQUIRED_REVIEW_DEMO_MARKERS = (
    "Google Play Reviewer Demo",
    "REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM",
    "No Telegram account or reviewer credential is required",
    "Exit reviewer demo",
)


def _read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise ValueError(f"Required file is missing: {relative}")
    return path.read_text(encoding="utf-8-sig")


def verify(root: Path) -> list[str]:
    errors: list[str] = []

    for relative in REQUIRED_DOCUMENTS:
        if not (root / relative).is_file():
            errors.append(f"Missing Play Store document: {relative}")

    files_to_scan = [
        "lib/src/features/settings/presentation/privacy_policy_screen.dart",
        "lib/src/features/settings/presentation/terms_summary_screen.dart",
        "lib/src/features/auth/login_screen.dart",
        "docs/play-store/STORE_LISTING_COPY.md",
    ]
    combined = "\n".join(
        _read(root, path) for path in files_to_scan if (root / path).is_file()
    ).lower()
    for marker in FORBIDDEN_MARKERS:
        if marker.lower() in combined:
            errors.append(f"Forbidden placeholder or informal copy remains: {marker}")

    privacy = _read(
        root, "lib/src/features/settings/presentation/privacy_policy_screen.dart"
    )
    for marker in REQUIRED_PRIVACY_MARKERS:
        if marker not in privacy:
            errors.append(f"Privacy screen is missing required disclosure: {marker}")

    login = _read(root, "lib/src/features/auth/login_screen.dart")
    for marker in REQUIRED_LOGIN_MARKERS:
        if marker not in login:
            errors.append(f"Login screen is missing pre-login legal access: {marker}")

    store_listing = _read(root, "docs/play-store/STORE_LISTING_COPY.md").lower()
    short_description_section = store_listing.split("## full description", 1)[0]
    for claim in MISLEADING_STORE_CLAIMS:
        if claim in short_description_section:
            errors.append(f"Misleading store-listing claim is present: {claim}")

    pubspec = _read(root, "pubspec.yaml").lower()
    for dependency in FORBIDDEN_DEPENDENCIES:
        if dependency in pubspec:
            errors.append(f"Disallowed release dependency is present: {dependency[:-1]}")

    review_docs = "\n".join(
        _read(root, relative)
        for relative in (
            "docs/play-store/APP_ACCESS.md",
            "docs/play-store/RELEASE_CHECKLIST.md",
            "docs/play-store/REVIEW_VIDEO_SCRIPT.md",
        )
    )
    for marker in FORBIDDEN_REVIEW_ACCESS_MARKERS:
        if marker in review_docs:
            errors.append(f"Obsolete Test DC reviewer guidance remains: {marker}")
    app_access = _read(root, "docs/play-store/APP_ACCESS.md")
    for marker in REQUIRED_REVIEW_DEMO_MARKERS:
        if marker not in app_access:
            errors.append(f"App access guide is missing Reviewer Demo copy: {marker}")

    manifest = _read(root, "android/app/src/main/AndroidManifest.xml")
    for permission in ("MANAGE_EXTERNAL_STORAGE", "ACCESS_MEDIA_LOCATION"):
        if permission in manifest:
            errors.append(f"Forbidden Android permission is present: {permission}")
    for permission in (
        "READ_MEDIA_IMAGES",
        "READ_MEDIA_VIDEO",
        "READ_MEDIA_VISUAL_USER_SELECTED",
    ):
        if permission not in manifest:
            errors.append(f"Required Android media permission is missing: {permission}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root",
    )
    args = parser.parse_args()

    try:
        errors = verify(args.root.resolve())
    except ValueError as exc:
        errors = [str(exc)]

    if errors:
        print("Play Store readiness verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Play Store source-level readiness checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
