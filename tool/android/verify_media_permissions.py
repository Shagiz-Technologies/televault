#!/usr/bin/env python3
"""Verify TeleVault's merged Android media permissions and release lockfile."""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"

REQUIRED = {
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
    "android.permission.READ_EXTERNAL_STORAGE",
}
FORBIDDEN = {
    "android.permission.ACCESS_MEDIA_LOCATION",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
    "android.permission.READ_MEDIA_AUDIO",
    "android.permission.WRITE_EXTERNAL_STORAGE",
}
FORBIDDEN_PACKAGES = {
    "google_sign_in",
    "googleapis",
    "googleapis_auth",
    "extension_google_sign_in_as_googleapis_auth",
}


class VerificationError(RuntimeError):
    pass


def verify_manifest(path: Path) -> set[str]:
    root = ET.parse(path).getroot()
    permissions: dict[str, ET.Element] = {}
    for node in root.findall("uses-permission"):
        name = node.attrib.get(f"{ANDROID}name")
        if name:
            permissions[name] = node

    missing = sorted(REQUIRED - permissions.keys())
    forbidden = sorted(FORBIDDEN & permissions.keys())
    if missing:
        raise VerificationError(f"Missing required permissions: {', '.join(missing)}")
    if forbidden:
        raise VerificationError(f"Forbidden permissions present: {', '.join(forbidden)}")

    legacy = permissions["android.permission.READ_EXTERNAL_STORAGE"]
    if legacy.attrib.get(f"{ANDROID}maxSdkVersion") != "32":
        raise VerificationError("READ_EXTERNAL_STORAGE must have maxSdkVersion=32")
    return set(permissions)


def verify_lockfile(path: Path) -> None:
    content = path.read_text(encoding="utf-8")
    found = sorted(
        package for package in FORBIDDEN_PACKAGES if f"  {package}:" in content
    )
    if found:
        raise VerificationError(
            f"Unused Google authentication dependencies remain: {', '.join(found)}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--lockfile", default=Path("pubspec.lock"), type=Path)
    args = parser.parse_args()
    try:
        permissions = verify_manifest(args.manifest)
        verify_lockfile(args.lockfile)
    except (OSError, ET.ParseError, VerificationError) as error:
        print(f"Media permission verification failed: {error}", file=sys.stderr)
        return 1
    print("Merged media permissions verified:")
    for permission in sorted(permissions):
        print(f"- {permission}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
