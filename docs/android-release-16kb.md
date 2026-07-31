# Android release baseline and 16 KB verification

Android is TeleVault's supported release platform. This document pins the release toolchain and describes how native artifacts are built and verified. It does not contain signing material or Telegram credentials.

## Pinned release toolchain

| Component | Version / source |
| --- | --- |
| Flutter | 3.38.9, framework `67323de285` |
| Flutter engine | `587c18f873` |
| Dart | 3.10.8 |
| Android Gradle Plugin | 8.11.1 |
| Gradle | 8.14 |
| Kotlin | 2.2.20 |
| Java language/bytecode | 17 |
| CI Java runtime | Temurin 17 |
| Android compile SDK | 36 |
| Android target SDK | 36 |
| Android minimum SDK | 24 |
| Android NDK | 28.2.13676358 (r28b) |
| Android NDK Clang | 19.0.1, Android build 13624864 / LLVM `97a699bf4812a18fb657c2779f5296a4ab2694d2` |
| Android build tools | 36.1.0 |
| Android command-line tools | 13114758, SHA-256 `7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee` |
| bundletool | 1.18.3, SHA-256 `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29` |

`minSdk 24` matches the Flutter 3.38.9 Android baseline and is at least as high as the declared Android requirements of the current plugin set. Raising it further would unnecessarily remove supported devices.

The Android application ID and namespace are intentionally `et.shagiz.tele_vault`. The Kotlin `MainActivity` package uses the same value. Do not rename it after a Play release without treating the result as a different application.

## Native library provenance

The vendored Dart/Flutter wrapper is `libtdjson` 0.2.2, based on upstream commit `bcd82ac7735912ab5f2c5eae3a2fa3f033ea9ee3`, with TeleVault's platform-specific maintenance changes.

Android `libtdjson.so` is built from source rather than downloaded as an opaque binary:

- TDLib 1.8.66, official source commit `022d60202e446ad1287b9fb68e687c8a0760788b`.
- OpenSSL 3.5.7 LTS, official source commit `8cf17aaeb4599f8af87fefd810b5b5fee90fe69e`, statically linked.
- NDK 28.2.13676358 and CMake 3.22.1.
- Android SDK platform/build-tools 34/34.0.0 for TDLib's native source-generation helper; the app itself compiles against SDK 36.
- `RelWithDebInfo`, TDLib JSON interface, and static libc++.
- Built and packaged ABIs: `arm64-v8a` and `x86_64`.
- Builder base: Ubuntu 24.04 image digest `sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90`.

The exact output hashes and builder package versions are committed in `third_party/libtdjson/android/TDLIB_BUILD_PROVENANCE.txt`. TDLib's Boost Software License and OpenSSL's license are preserved beside the wrapper license.

Other packaged native libraries are mapped in `tool/android/native_origins.json`. Verification fails when a future dependency introduces a native filename without a provenance entry.

TeleVault no longer packages 32-bit ARM or x86. The current `sqlite3_flutter_libs` 0.5.41 and final binary-bearing 0.5.42 ARMv7 libraries both use 4 KB ELF alignment, so retaining `armeabi-v7a` would violate the all-native-library 16 KB release gate. Android devices use `arm64-v8a`; `x86_64` is retained for emulator validation.

### Verified release inventory

The API 36 release bundle built on 2026-07-31 produced this inventory. The
machine-readable equivalent is generated at
`build/reports/android-16kb-inventory.json` on every CI run.

| ABI | Library | Source | Minimum LOAD alignment | RELRO result |
| --- | --- | --- | --- | --- |
| `arm64-v8a` | `libapp.so` | Flutter 3.38.9 AOT output | `0x10000` | Not applicable: no relocation-sensitive sections |
| `arm64-v8a` | `libflutter.so` | Flutter engine `587c18f873` | `0x10000` | Enabled |
| `arm64-v8a` | `libsqlite3.so` | `sqlite3_flutter_libs` 0.5.41 / SQLite 3.51.1 | `0x4000` | Enabled |
| `arm64-v8a` | `libtdjson.so` | TDLib 1.8.66, pinned commit above | `0x4000` | Enabled |
| `x86_64` | `libapp.so` | Flutter 3.38.9 AOT output | `0x10000` | Not applicable: no relocation-sensitive sections |
| `x86_64` | `libflutter.so` | Flutter engine `587c18f873` | `0x10000` | Enabled |
| `x86_64` | `libsqlite3.so` | `sqlite3_flutter_libs` 0.5.41 / SQLite 3.51.1 | `0x4000` | Enabled |
| `x86_64` | `libtdjson.so` | TDLib 1.8.66, pinned commit above | `0x4000` | Enabled |

Flutter's generated `libapp.so` does not contain `.got`, relocation,
`init_array`, or `fini_array` sections, so there is no writable relocation
region for GNU RELRO to protect. The verifier records this exception and still
fails any library that has relocation-sensitive sections without GNU RELRO.

## Rebuild TDLib

Docker BuildKit is required. From the repository root:

```bash
docker build \
  --progress=plain \
  --output type=local,dest=build/tdlib-android \
  -f tool/android/tdlib/Dockerfile \
  tool/android/tdlib
```

On a development network that requires a custom root certificate, provide it as a BuildKit secret. The certificate is not copied to the output or repository:

```bash
docker build \
  --secret id=ca_bundle,src=/absolute/path/to/network-root.crt \
  --output type=local,dest=build/tdlib-android \
  -f tool/android/tdlib/Dockerfile \
  tool/android/tdlib
```

Compare `build/tdlib-android/SHA256SUMS` and `build-toolchain.txt` with the committed provenance record. Replace the vendored files only after both outputs pass the ELF checks:

```bash
for abi in arm64-v8a x86_64; do
  cp "build/tdlib-android/libs/$abi/libtdjson.so" \
    "third_party/libtdjson/android/src/main/jniLibs/$abi/libtdjson.so"
done
```

## Build and inspect a release

Real Telegram values and Play signing keys are intentionally unnecessary for structural validation:

```bash
flutter pub get
flutter build appbundle --release \
  --target-platform=android-arm64,android-x64 \
  --dart-define=TELEGRAM_API_ID=0 \
  --dart-define=TELEGRAM_API_HASH=placeholder
```

The explicit target list is required. Flutter otherwise builds its default
32-bit ARM AOT target even when Gradle has 64-bit ABI filters, which would
reintroduce the 4 KB-aligned ARMv7 SQLite library.

Download the pinned bundletool JAR and verify its SHA-256 above. Then run:

```bash
python3 tool/android/verify_16kb.py \
  --aab build/app/outputs/bundle/release/app-release.aab \
  --bundletool /absolute/path/to/bundletool-all-1.18.3.jar
```

The verifier:

1. Confirms the Gradle API, NDK, Java, package, and ABI baseline.
2. Requires bundletool to report `PAGE_ALIGNMENT_16K`.
3. Creates a universal APK from the AAB.
4. Runs `zipalign -c -P 16 -v 4`.
5. Confirms the generated package, minimum SDK, compile SDK, and target SDK.
6. Checks every ELF LOAD segment for alignment of at least `0x4000`.
7. Requires GNU RELRO whenever a `.so` contains relocation-sensitive sections. Flutter's generated `libapp.so` has no such sections, so its missing RELRO header is recorded as not applicable rather than silently ignored.
8. Rejects unknown native-library provenance and Android debug signing.
9. Writes `build/reports/android-16kb-inventory.json`.

CI builds an unsigned release bundle. Production signing is applied only when a complete, local `android/key.properties` points to the real release keystore. An incomplete signing configuration fails during Gradle configuration; CI never falls back to the debug key.

## Required 16 KB runtime test

Artifact inspection does not replace runtime testing. Use an Android 16/API 36 16 KB page-size emulator image or a physical 16 KB device:

```bash
adb shell getconf PAGE_SIZE
```

The command must print `16384`. Install and launch TeleVault, then verify:

- The process starts without a native-loader or `dlopen` failure.
- TDLib creates a client and reaches the expected unauthenticated or restored-session authorization state.
- Telegram login can begin when personal credentials are injected from a file outside the repository.
- SQLite opens the existing local schema.
- The app can be backgrounded, resumed, and cold-started.

Use a local file outside the repository for runtime credentials. Do not put values directly in shell history, logs, screenshots, test reports, or Git.

### Baseline runtime result

The 2026-07-31 release baseline was installed from an AAB-derived universal
APK on `Medium_Phone_API_36.1`, using the Android 16/API 36.1 Google APIs
Play Store `ps16k` x86_64 image. Verification observed:

- `getconf PAGE_SIZE` returned `16384`.
- TeleVault remained alive after a cold launch and a 30-second observation.
- The TDLib native client initialized successfully.
- No TeleVault native-loader, fatal-exception, or SQLite startup error appeared.

This structural test used placeholder Telegram build values. It confirms that
the 16 KB runtime can load and initialize TDLib; it does not constitute a real
Telegram authorization or upload test. Complete that release-candidate check
with credentials supplied from outside the repository.
