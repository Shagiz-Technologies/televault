#!/usr/bin/env python3
"""Verify TeleVault's Android release bundle and its packaged native code."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile


EXPECTED_APPLICATION_ID = "et.shagiz.tele_vault"
EXPECTED_ABIS = {"arm64-v8a", "x86_64"}
EXPECTED_COMPILE_SDK = 36
EXPECTED_MIN_SDK = 24
EXPECTED_TARGET_SDK = 36
MINIMUM_LOAD_ALIGNMENT = 1 << 14


class VerificationError(RuntimeError):
    pass


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if check and result.returncode != 0:
        output = "\n".join(part for part in (result.stdout, result.stderr) if part.strip())
        raise VerificationError(f"Command failed ({result.returncode}): {' '.join(command)}\n{output}")
    return result


def version_key(path: Path) -> tuple[int, ...]:
    return tuple(int(part) for part in re.findall(r"\d+", path.parent.name))


def ndk_version_key(path: Path) -> tuple[int, ...]:
    for part in reversed(path.parts):
        if re.fullmatch(r"\d+(?:\.\d+)+", part):
            return tuple(int(value) for value in part.split("."))
    return ()


def find_android_tool(name: str, explicit: str | None) -> Path:
    executable = f"{name}.exe" if os.name == "nt" else name
    if explicit:
        path = Path(explicit).resolve()
        if path.is_file():
            return path
        raise VerificationError(f"Android tool does not exist: {path}")

    located = shutil.which(executable)
    if located:
        return Path(located).resolve()

    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if sdk:
        matches = sorted(Path(sdk).glob(f"build-tools/*/{executable}"), key=version_key, reverse=True)
        if matches:
            return matches[0].resolve()
    raise VerificationError(f"Unable to locate {executable}; pass its path explicitly")


def find_ndk_tool(name: str, explicit: str | None) -> Path:
    executable = f"llvm-{name}.exe" if os.name == "nt" else f"llvm-{name}"
    if explicit:
        path = Path(explicit).resolve()
        if path.is_file():
            return path
        raise VerificationError(f"{executable} does not exist: {path}")

    ndk = os.environ.get("ANDROID_NDK_HOME") or os.environ.get("ANDROID_NDK_ROOT")
    candidates: list[Path] = []
    if ndk:
        candidates.extend(Path(ndk).glob(f"toolchains/llvm/prebuilt/*/bin/{executable}"))
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if sdk:
        candidates.extend(Path(sdk).glob(f"ndk/*/toolchains/llvm/prebuilt/*/bin/{executable}"))
    candidates = sorted(candidates, key=ndk_version_key, reverse=True)
    if candidates:
        return candidates[0].resolve()
    raise VerificationError(f"Unable to locate NDK {executable}; pass --{name}")


def verify_source_configuration(repo_root: Path) -> None:
    app_gradle = (repo_root / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    settings_gradle = (repo_root / "android/settings.gradle.kts").read_text(encoding="utf-8")
    plugin_gradle = (repo_root / "third_party/libtdjson/android/build.gradle").read_text(
        encoding="utf-8"
    )
    wrapper_properties = (repo_root / "android/gradle/wrapper/gradle-wrapper.properties").read_text(
        encoding="utf-8"
    )
    plugin_wrapper_properties = (
        repo_root / "third_party/libtdjson/android/gradle/wrapper/gradle-wrapper.properties"
    ).read_text(encoding="utf-8")
    tdlib_dockerfile = (repo_root / "tool/android/tdlib/Dockerfile").read_text(encoding="utf-8")
    tdlib_dockerfile_digest = hashlib.sha256(tdlib_dockerfile.encode("utf-8")).hexdigest()
    tdlib_provenance = (
        repo_root / "third_party/libtdjson/android/TDLIB_BUILD_PROVENANCE.txt"
    ).read_text(encoding="utf-8")
    main_activity = (
        repo_root / "android/app/src/main/kotlin/et/shagiz/tele_vault/MainActivity.kt"
    ).read_text(encoding="utf-8")
    required_patterns = {
        "compileSdk 36": (app_gradle, r"compileSdk\s*=\s*36\b"),
        "targetSdk 36": (app_gradle, r"targetSdk\s*=\s*36\b"),
        "minSdk 24": (app_gradle, r"minSdk\s*=\s*24\b"),
        "NDK 28.2.13676358": (app_gradle, r'ndkVersion\s*=\s*"28\.2\.13676358"'),
        "application ID": (app_gradle, rf'applicationId\s*=\s*"{re.escape(EXPECTED_APPLICATION_ID)}"'),
        "namespace": (app_gradle, rf'namespace\s*=\s*"{re.escape(EXPECTED_APPLICATION_ID)}"'),
        "Java 17 source": (app_gradle, r"sourceCompatibility\s*=\s*JavaVersion\.VERSION_17"),
        "Java 17 target": (app_gradle, r"targetCompatibility\s*=\s*JavaVersion\.VERSION_17"),
        "64-bit app ABIs": (
            app_gradle,
            r'abiFilters\s*\+=\s*listOf\("arm64-v8a",\s*"x86_64"\)',
        ),
        "32-bit JNI exclusion": (
            app_gradle,
            r'excludes\s*\+=\s*setOf\("\*\*/armeabi-v7a/\*\.so",\s*"\*\*/x86/\*\.so"\)',
        ),
        "AGP 8.11.1": (settings_gradle, r'com\.android\.application"\) version "8\.11\.1"'),
        "Kotlin 2.2.20": (settings_gradle, r'org\.jetbrains\.kotlin\.android"\) version "2\.2\.20"'),
        "Gradle 8.14": (wrapper_properties, r"gradle-8\.14-all\.zip"),
        "plugin compileSdk 36": (plugin_gradle, r"compileSdk\s*=\s*36\b"),
        "plugin minSdk 24": (plugin_gradle, r"minSdk\s*=\s*24\b"),
        "plugin AGP 8.11.1": (plugin_gradle, r"com\.android\.tools\.build:gradle:8\.11\.1"),
        "plugin Gradle 8.14": (plugin_wrapper_properties, r"gradle-8\.14-all\.zip"),
        "64-bit TDLib ABIs": (
            plugin_gradle,
            r"abiFilters\s+'arm64-v8a',\s*'x86_64'",
        ),
        "MainActivity package": (main_activity, rf"package\s+{re.escape(EXPECTED_APPLICATION_ID)}\b"),
        "TDLib source commit": (
            tdlib_dockerfile,
            r"TDLIB_COMMIT=022d60202e446ad1287b9fb68e687c8a0760788b",
        ),
        "OpenSSL source commit": (
            tdlib_dockerfile,
            r"OPENSSL_COMMIT=8cf17aaeb4599f8af87fefd810b5b5fee90fe69e",
        ),
        "TDLib builder recipe hash": (
            tdlib_provenance,
            rf"Builder recipe SHA-256:\s*{tdlib_dockerfile_digest}\b",
        ),
    }
    missing = [label for label, (content, pattern) in required_patterns.items() if not re.search(pattern, content)]
    if missing:
        raise VerificationError(f"Release source configuration is not pinned: {', '.join(missing)}")


def parse_badging(output: str) -> tuple[str, int, int]:
    package = re.search(r"^package: name='([^']+)'", output, re.MULTILINE)
    min_sdk = re.search(r"^(?:sdkVersion|minSdkVersion):'(\d+)'", output, re.MULTILINE)
    target_sdk = re.search(r"^targetSdkVersion:'(\d+)'", output, re.MULTILINE)
    if not package or not min_sdk or not target_sdk:
        raise VerificationError("Unable to parse package/minSdk/targetSdk from aapt2 badging output")
    return package.group(1), int(min_sdk.group(1)), int(target_sdk.group(1))


def parse_load_alignments(output: str) -> list[int]:
    alignments = []
    for line in output.splitlines():
        if re.match(r"^\s*LOAD\b", line):
            match = re.search(r"(0x[0-9a-fA-F]+)\s*$", line)
            if not match:
                raise VerificationError(f"Unable to parse ELF LOAD alignment: {line}")
            alignments.append(int(match.group(1), 16))
    if not alignments:
        raise VerificationError("ELF has no LOAD segments")
    return alignments


def parse_objdump_load_alignments(output: str) -> list[int]:
    alignments = []
    for line in output.splitlines():
        if re.match(r"^\s*LOAD\b", line):
            match = re.search(r"align\s+2\*\*(\d+)\s*$", line)
            if not match:
                raise VerificationError(f"Unable to parse ELF LOAD alignment: {line}")
            alignments.append(1 << int(match.group(1)))
    if not alignments:
        raise VerificationError("ELF has no LOAD segments")
    return alignments


def verify_elf(path: Path, readelf: Path, objdump: Path) -> tuple[list[int], bool, str]:
    program_headers = run([str(objdump), "-p", str(path)]).stdout
    alignments = parse_objdump_load_alignments(program_headers)
    readelf_program_headers = run([str(readelf), "-lW", str(path)]).stdout
    relro = bool(
        re.search(r"^\s*RELRO\b", program_headers, re.MULTILINE)
        or re.search(r"^\s*GNU_RELRO\b", readelf_program_headers, re.MULTILINE)
    )
    if min(alignments) < MINIMUM_LOAD_ALIGNMENT:
        raise VerificationError(
            f"{path.name} has LOAD alignment {min(alignments):#x}; expected at least 0x4000"
        )
    relro_status = "enabled"
    if not relro:
        sections = run([str(readelf), "-SW", str(path)]).stdout
        if "Section Headers:" not in sections:
            raise VerificationError("Unable to inspect ELF section headers")
        relocation_sections = re.findall(
            r"\.(?:got(?:\.plt)?|data\.rel\.ro|rel(?:a)?\.[^\s]+|init_array|fini_array)\b",
            sections,
        )
        if relocation_sections:
            raise VerificationError(
                f"{path.name} has relocation-sensitive sections without GNU_RELRO: "
                f"{sorted(set(relocation_sections))}"
            )
        relro_status = "not-applicable-no-relocation-sections"
    return alignments, relro, relro_status


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_provenance_digest(
    *, entry: str, abi: str, digest: str, provenance: dict[str, object]
) -> None:
    expected_by_abi = provenance.get("sha256_by_abi", {})
    if not isinstance(expected_by_abi, dict):
        raise VerificationError(f"Invalid sha256_by_abi provenance for {entry}")
    expected_digest = expected_by_abi.get(abi)
    if expected_digest and digest != expected_digest:
        raise VerificationError(
            f"{entry} SHA-256 {digest} does not match reviewed provenance {expected_digest}"
        )


def verify_not_debug_signed(aab: Path) -> str:
    result = run(["jarsigner", "-verify", "-verbose", "-certs", str(aab)], check=False)
    output = f"{result.stdout}\n{result.stderr}"
    if re.search(r"CN=Android Debug|Android Debug", output, re.IGNORECASE):
        raise VerificationError("Release bundle is signed with an Android debug certificate")
    return "signed-non-debug" if "Signer" in output or "CN=" in output else "unsigned"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--aab", required=True, type=Path)
    parser.add_argument("--bundletool", required=True, type=Path)
    parser.add_argument("--origins", type=Path, default=Path("tool/android/native_origins.json"))
    parser.add_argument("--report", type=Path, default=Path("build/reports/android-16kb-inventory.json"))
    parser.add_argument("--zipalign")
    parser.add_argument("--aapt2")
    parser.add_argument("--readelf")
    parser.add_argument("--objdump")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    aab = args.aab.resolve()
    bundletool = args.bundletool.resolve()
    if not aab.is_file() or not bundletool.is_file():
        raise VerificationError("The AAB and bundletool JAR must both exist")

    verify_source_configuration(repo_root)
    origins = json.loads(args.origins.read_text(encoding="utf-8"))
    zipalign = find_android_tool("zipalign", args.zipalign)
    aapt2 = find_android_tool("aapt2", args.aapt2)
    readelf = find_ndk_tool("readelf", args.readelf)
    objdump = find_ndk_tool("objdump", args.objdump)

    config = run(["java", "-jar", str(bundletool), "dump", "config", f"--bundle={aab}"]).stdout
    if "PAGE_ALIGNMENT_16K" not in config:
        raise VerificationError("bundletool did not report PAGE_ALIGNMENT_16K")

    with tempfile.TemporaryDirectory(prefix="televault-16kb-") as temporary:
        root = Path(temporary)
        apks = root / "release.apks"
        run(
            [
                "java",
                "-jar",
                str(bundletool),
                "build-apks",
                f"--bundle={aab}",
                f"--output={apks}",
                "--mode=universal",
                "--overwrite",
            ]
        )
        with zipfile.ZipFile(apks) as archive:
            candidates = [name for name in archive.namelist() if name.endswith("universal.apk")]
            if len(candidates) != 1:
                raise VerificationError(f"Expected one universal APK, found {candidates}")
            archive.extract(candidates[0], root)
        apk = root / candidates[0]

        run([str(zipalign), "-c", "-P", "16", "-v", "4", str(apk)])
        badging = run([str(aapt2), "dump", "badging", str(apk)]).stdout
        package, min_sdk, target_sdk = parse_badging(badging)
        platform_build = re.search(r"platformBuildVersionCode='(\d+)'", badging)
        if not platform_build or int(platform_build.group(1)) < EXPECTED_COMPILE_SDK:
            raise VerificationError("Generated APK does not report platformBuildVersionCode 36 or newer")
        if (package, min_sdk, target_sdk) != (
            EXPECTED_APPLICATION_ID,
            EXPECTED_MIN_SDK,
            EXPECTED_TARGET_SDK,
        ):
            raise VerificationError(
                f"Unexpected manifest baseline: package={package}, minSdk={min_sdk}, targetSdk={target_sdk}"
            )

        native_root = root / "native"
        inventory = []
        with zipfile.ZipFile(apk) as archive:
            native_entries = [name for name in archive.namelist() if re.match(r"^lib/[^/]+/[^/]+\.so$", name)]
            if not native_entries:
                raise VerificationError("Universal APK contains no native shared libraries")
            for entry in native_entries:
                archive.extract(entry, native_root)
                _, abi, filename = entry.split("/")
                if filename not in origins:
                    raise VerificationError(f"Native library has no provenance mapping: {filename}")
                library = native_root / entry
                print(f"Verifying {entry}", flush=True)
                try:
                    alignments, relro, relro_status = verify_elf(library, readelf, objdump)
                except VerificationError as error:
                    raise VerificationError(f"{entry}: {error}") from error
                digest = sha256(library)
                provenance = origins[filename]
                verify_provenance_digest(
                    entry=entry,
                    abi=abi,
                    digest=digest,
                    provenance=provenance,
                )
                inventory.append(
                    {
                        "abi": abi,
                        "filename": filename,
                        "origin": provenance["origin"],
                        "sha256": digest,
                        "load_alignments": [f"0x{value:x}" for value in alignments],
                        "minimum_load_alignment": f"0x{min(alignments):x}",
                        "gnu_relro": relro,
                        "relro_verification": relro_status,
                    }
                )

        packaged_abis = {item["abi"] for item in inventory}
        if packaged_abis != EXPECTED_ABIS:
            raise VerificationError(
                f"Unexpected packaged ABIs: {sorted(packaged_abis)}; expected {sorted(EXPECTED_ABIS)}"
            )

    report = {
        "application_id": EXPECTED_APPLICATION_ID,
        "compile_sdk": EXPECTED_COMPILE_SDK,
        "min_sdk": EXPECTED_MIN_SDK,
        "target_sdk": EXPECTED_TARGET_SDK,
        "bundle_page_alignment": "PAGE_ALIGNMENT_16K",
        "zipalign_page_size": 16384,
        "bundle_signing": verify_not_debug_signed(aab),
        "native_libraries": sorted(inventory, key=lambda item: (item["abi"], item["filename"])),
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except VerificationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
