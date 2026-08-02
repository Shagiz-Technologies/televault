#!/usr/bin/env python3
"""Scan captured release logs without echoing sensitive log contents."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


SENSITIVE_PATTERNS = {
    "phone number": re.compile(
        r"(?:phone[_ ]?number|setAuthenticationPhoneNumber)"
        r".{0,32}(?:\"phone_number\"\s*:\s*)?[\"']?\+?\d{6,}",
        re.IGNORECASE,
    ),
    "authentication code": re.compile(
        r"(?:checkAuthenticationCode|authentication[_ ]?code|login[_ ]?code|otp)"
        r".{0,48}(?:\"code\"\s*:\s*\"?\d{4,8}|\b\d{4,8}\b)",
        re.IGNORECASE,
    ),
    "API credential": re.compile(
        r"(?:api_hash|telegram_api_hash|telegram_api_id)\s*[:=]\s*[^\s,}]+",
        re.IGNORECASE,
    ),
    "Recovery Key": re.compile(r"TVRK1-[A-Z2-7-]{12,}", re.IGNORECASE),
    "private local path": re.compile(
        r"(?:/data/(?:user/\d+|data)/et\.shagiz\.tele_vault|"
        r"/storage/emulated/\d+|[A-Z]:\\Users\\)",
        re.IGNORECASE,
    ),
    "Telegram session material": re.compile(
        r"(?:auth[_ ]?key|session[_ ]?(?:id|key|data))\s*[:=]\s*[^\s,}]+",
        re.IGNORECASE,
    ),
}


def scan(content: str, forbidden_values: list[str] | None = None) -> list[str]:
    findings: list[str] = []
    lines = content.splitlines()
    for line_number, line in enumerate(lines, start=1):
        for category, pattern in SENSITIVE_PATTERNS.items():
            if pattern.search(line):
                findings.append(f"line {line_number}: {category}")
        for value in forbidden_values or []:
            if value and value in line:
                findings.append(f"line {line_number}: configured forbidden value")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument(
        "--forbidden-value",
        action="append",
        default=[],
        help="Exact sensitive value to reject. Values are never printed.",
    )
    args = parser.parse_args()

    if not args.log.is_file():
        print("Release log scan failed: capture file is missing.", file=sys.stderr)
        return 2

    findings = scan(
        args.log.read_text(encoding="utf-8", errors="replace"),
        args.forbidden_value,
    )
    if findings:
        print("Release log scan found sensitive output:", file=sys.stderr)
        for finding in findings:
            print(f"- {finding}", file=sys.stderr)
        return 1

    print("Release log scan passed; no configured sensitive values were found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
