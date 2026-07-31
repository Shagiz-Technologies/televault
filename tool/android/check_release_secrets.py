#!/usr/bin/env python3
"""Reject tracked Android signing material and concrete Telegram credentials."""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys


DENIED_NAMES = {".env", "key.properties", "local.properties"}
DENIED_SUFFIXES = {
    ".aab",
    ".apk",
    ".db",
    ".jks",
    ".key",
    ".keystore",
    ".log",
    ".p12",
    ".pem",
    ".sha1",
    ".sqlite",
}
DENIED_DIRECTORIES = {"backups", "build", "playstore_release"}
CONTENT_PATTERNS = {
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "Telegram API hash": re.compile(r"TELEGRAM_API_HASH\s*[=:]\s*['\"]?[0-9a-fA-F]{32}\b"),
    "Telegram API ID": re.compile(r"TELEGRAM_API_ID\s*[=:]\s*['\"]?[1-9][0-9]{4,}\b"),
    "keystore password": re.compile(r"(?:storePassword|keyPassword)\s*=\s*(?!placeholder\b|<)[^\s#]+"),
}


def main() -> int:
    repo = Path(__file__).resolve().parents[2]
    result = subprocess.run(
        ["git", "ls-files", "-z"], cwd=repo, capture_output=True, check=True
    )
    tracked = [Path(value.decode()) for value in result.stdout.split(b"\0") if value]
    problems: list[str] = []
    for relative in tracked:
        denied_env = (
            relative.name == ".env"
            or relative.name.startswith(".env.")
        ) and relative.name != ".env.example"
        denied_directory = any(part.lower() in DENIED_DIRECTORIES for part in relative.parts)
        if (
            relative.name in DENIED_NAMES
            or denied_env
            or denied_directory
            or relative.suffix.lower() in DENIED_SUFFIXES
        ):
            problems.append(f"denied tracked file: {relative.as_posix()}")
            continue
        path = repo / relative
        try:
            content = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for label, pattern in CONTENT_PATTERNS.items():
            if label == "keystore password" and relative.suffix != ".properties":
                continue
            if pattern.search(content):
                problems.append(f"possible {label}: {relative.as_posix()}")
    if problems:
        print("Release secret scan failed:", file=sys.stderr)
        for problem in problems:
            print(f"- {problem}", file=sys.stderr)
        return 1
    print(f"Release secret scan passed for {len(tracked)} tracked files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
