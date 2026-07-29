# Native Binary Provenance

## Status

**Release blocker:** the committed Android `libtdjson.so` files do not have
enough provenance information for a production release. The repository
identifies the vendored Flutter wrapper as `libtdjson` `0.2.2` from
`up9cloud/flutter_libtdjson`, but that metadata does not prove the TDLib source
revision or build process used for the native files.

All four binaries first appear in public commit
`5f08d7e0e91c1b3711665837b1ff32374c2a8962` on July 8, 2026. That is a commit
date, not a native build date.

## Inventory

| Path | ABI | Size | SHA-256 |
| --- | --- | ---: | --- |
| `third_party/libtdjson/android/src/main/jniLibs/arm64-v8a/libtdjson.so` | arm64-v8a | 28,127,248 | `78320ecf549cb3126996e85ee82b8cc1514de96ea72b04cac620afebca8e58c6` |
| `third_party/libtdjson/android/src/main/jniLibs/armeabi-v7a/libtdjson.so` | armeabi-v7a | 18,447,720 | `61a8f4cf2b0ec6671376c7c2a087c299a4e6236352e62bd95b26f53bbb33ab56` |
| `third_party/libtdjson/android/src/main/jniLibs/x86/libtdjson.so` | x86 | 29,908,096 | `ac201c22feb5f9c50271d0dc2da818783374af57e77545b008a898cbe0427843` |
| `third_party/libtdjson/android/src/main/jniLibs/x86_64/libtdjson.so` | x86_64 | 27,606,208 | `2e07c8c77a8a8bc428a0c55736cc520736903ecc6eccb4dd55729bbd10c6d839` |

## Known and unknown fields

| Field | Recorded status |
| --- | --- |
| Wrapper source project | Metadata points to `https://github.com/up9cloud/flutter_libtdjson`. |
| Wrapper version | `0.2.2` in `third_party/libtdjson/pubspec.yaml`. |
| Wrapper license | MIT file at `third_party/libtdjson/LICENSE`. |
| Native source project | Expected to be TDLib/libtdjson, but exact source checkout is not recorded. |
| Native version or commit | Unknown. |
| Native build origin | Unknown. |
| Native build date | Unknown. |
| Native build flags and NDK | Unknown. |
| Native license verification | Incomplete; the wrapper's MIT license alone does not establish the provenance or redistribution record for these binaries. |
| Source ABIs | arm64-v8a, armeabi-v7a, x86, and x86_64 files are present. |
| Gradle ABI filters | arm64-v8a, armeabi-v7a, and x86_64; final artifact contents still require inspection. |
| 16 KB page-size status | Not verified. |

## Required remediation

Before production distribution:

1. Identify the exact TDLib source version and all native dependencies.
2. Preserve the source URL, commit, patches, build container/toolchain, NDK
   version, flags, and reproducible build commands.
3. Confirm every required third-party license and notice.
4. Rebuild each supported ABI from that recorded source.
5. Verify ELF LOAD alignment, APK/AAB ZIP alignment, ABI coverage, and 16 KB
   page-size behavior using the final release artifact.
6. Replace the committed binaries only after Telegram login, upload, download,
   restore, and interruption testing on physical Android devices.
7. Update this inventory and `NOTICE.md` with the verified results.

Do not suppress native compatibility warnings or infer compatibility from a
successful compile alone.
