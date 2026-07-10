# Experimental iOS Sideload Testing from Windows

TeleVault's iOS build is experimental. Android remains the supported release target, and Telegram login, upload, and restore must not be treated as working on iOS until TDLib/libtdjson support has been validated end to end.

The `Build unsigned iOS IPA` GitHub Actions workflow provides a remote macOS build machine for developers who use Windows. A Mac is still required somewhere in the build process because Apple's iOS toolchain only runs on macOS; GitHub Actions supplies that Mac remotely.

## What the Workflow Produces

The workflow builds `Runner.app` without Apple code signing and packages it as:

```text
TeleVault-unsigned.ipa
```

The GitHub Actions artifact is named `TeleVault-unsigned-ipa` and is retained for one day. It contains no Apple certificate, provisioning profile, App Store Connect key, or production Telegram credentials.

The IPA is unsigned. It cannot be installed directly on an iPhone until a sideloading tool signs it for your device.

## Build and Download the IPA

1. Open the TeleVault repository on GitHub.
2. Select **Actions**.
3. Select **Build unsigned iOS IPA**.
4. Choose **Run workflow** for the branch you want to test.
5. Wait for the workflow to finish successfully.
6. Open the completed workflow run.
7. Download the `TeleVault-unsigned-ipa` artifact.
8. Extract the downloaded ZIP to obtain `TeleVault-unsigned.ipa`.

If the workflow fails, inspect the failing step. A failed run does not produce a usable IPA.

## Install from Windows

Use Sideloadly or AltStore according to that tool's current installation instructions:

1. Install Sideloadly or AltStore on Windows.
2. Connect your iPhone to the PC with USB and unlock it.
3. Trust the computer on the iPhone if prompted.
4. Open the sideloading tool and select the connected iPhone.
5. Select `TeleVault-unsigned.ipa`.
6. Sign and install it using a free Apple ID.
7. On the iPhone, approve Developer Mode or trust the developer profile if iOS requests it.
8. Launch TeleVault and treat the installation as experimental local testing only.

Free Apple ID installations generally expire after about seven days and must be refreshed or reinstalled. Apple can change free provisioning behavior, and sideloading tools may have their own requirements.

If you do not want to enter your primary Apple ID into third-party sideloading software, use a secondary Apple ID dedicated to local testing. Review the tool's security model before providing any account credentials.

## Safety and Distribution Limits

- Do not upload or distribute the unsigned IPA publicly.
- Do not treat this workflow as App Store or TestFlight distribution.
- Do not add Apple credentials, certificates, provisioning profiles, or signing secrets to the repository.
- Do not assume that producing an IPA means Telegram-backed features work on iOS.
- The workflow uses placeholder Telegram API values, so it is intended to verify compilation and packaging, not production login.

See [iOS Feasibility Notes](IOS_FEASIBILITY.md) for the current platform status and known limitations.
