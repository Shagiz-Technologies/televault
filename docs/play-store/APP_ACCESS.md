# Google Play app access

Status: **do not submit this document unchanged until reviewer mode is implemented and verified.**

TeleVault requires Telegram authorization before its main backup features are available. Google Play reviewers must receive reusable, location-independent instructions that do not depend on a developer's personal Telegram account or a one-time production OTP.

## Required reviewer environment

The release candidate must provide an isolated build-time review mode that:

- sets TDLib `use_test_dc` to `true`;
- uses separate TDLib, Drift, cache, and secure-storage namespaces;
- shows a persistent `Telegram Test Environment` indicator;
- cannot read or modify production-mode local storage;
- contains no embedded production Telegram session, phone number, login code, password, API hash, or user media.

Telegram Test DC accounts use Telegram's documented synthetic-number flow. Record the exact reusable test number and code used for the submitted build in the private Play Console App access instructions. Do not commit them to this repository.

## Reviewer steps

1. Launch the review-mode build and confirm the `Telegram Test Environment` indicator is visible.
2. Open Privacy Policy and Terms of Service from the login screen.
3. Enter the reusable Telegram Test DC account details supplied privately in Play Console.
4. Complete authorization using the reusable test code.
5. Grant full or selected photo/video access.
6. Create or select a private bucket channel.
7. Select test media and start an upload.
8. Confirm the item reaches `Synced` only after Telegram reports send success.
9. Open Vault, record and confirm the generated Recovery Key, then vault one test item.
10. Open Settings and review Privacy & Data, Media Access, Diagnostics, and logout behavior.
11. Log out and confirm the app explains that remote Telegram channels and messages remain.

## Submission blocker

A normal production Telegram login that requires an unpredictable OTP is not sufficient reviewer access. Do not submit to production until the isolated Test DC flow has been exercised on the exact signed AAB or its Play-generated APKs.
