#!/usr/bin/env python3
"""Finalize TeleVault release verification for ARMv7 plus 64-bit Android ABIs."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise RuntimeError(f"Expected one match in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> None:
    verifier = ROOT / "tool/android/verify_16kb.py"

    replace_once(
        verifier,
        'EXPECTED_ABIS = {"arm64-v8a", "x86_64"}\n'
        'EXPECTED_COMPILE_SDK = 36\n'
        'EXPECTED_MIN_SDK = 24\n'
        'EXPECTED_TARGET_SDK = 36\n'
        'MINIMUM_LOAD_ALIGNMENT = 1 << 14',
        'EXPECTED_ABIS = {"armeabi-v7a", "arm64-v8a", "x86_64"}\n'
        'EXPECTED_COMPILE_SDK = 36\n'
        'EXPECTED_MIN_SDK = 24\n'
        'EXPECTED_TARGET_SDK = 36\n'
        'MINIMUM_LOAD_ALIGNMENT_BY_ABI = {\n'
        '    "armeabi-v7a": 1 << 12,\n'
        '    "arm64-v8a": 1 << 14,\n'
        '    "x86_64": 1 << 14,\n'
        '}',
    )

    replace_once(
        verifier,
        '''        "64-bit app ABIs": (
            app_gradle,
            r'abiFilters\\s*\\+=\\s*listOf\\("arm64-v8a",\\s*"x86_64"\\)',
        ),
        "32-bit JNI exclusion": (
            app_gradle,
            r'excludes\\s*\\+=\\s*setOf\\("\\*\\*/armeabi-v7a/\\*\\.so",\\s*"\\*\\*/x86/\\*\\.so"\\)',
        ),''',
        '''        "release app ABIs": (
            app_gradle,
            r'abiFilters\\s*\\+=\\s*listOf\\("armeabi-v7a",\\s*"arm64-v8a",\\s*"x86_64"\\)',
        ),
        "unsupported x86 JNI exclusion": (
            app_gradle,
            r'excludes\\s*\\+=\\s*setOf\\("\\*\\*/x86/\\*\\.so"\\)',
        ),''',
    )

    replace_once(
        verifier,
        '''        "64-bit TDLib ABIs": (
            plugin_gradle,
            r"abiFilters\\s+'arm64-v8a',\\s*'x86_64'",
        ),''',
        '''        "release TDLib ABIs": (
            plugin_gradle,
            r"abiFilters\\s+'armeabi-v7a',\\s*'arm64-v8a',\\s*'x86_64'",
        ),''',
    )

    replace_once(
        verifier,
        'def verify_elf(path: Path, objdump: Path) -> tuple[list[int], bool, str]:',
        'def verify_elf(\n'
        '    path: Path, objdump: Path, minimum_load_alignment: int\n'
        ') -> tuple[list[int], bool, str]:',
    )

    replace_once(
        verifier,
        '''    if min(alignments) < MINIMUM_LOAD_ALIGNMENT:
        raise VerificationError(
            f"{path.name} has LOAD alignment {min(alignments):#x}; expected at least 0x4000"
        )''',
        '''    if min(alignments) < minimum_load_alignment:
        raise VerificationError(
            f"{path.name} has LOAD alignment {min(alignments):#x}; "
            f"expected at least {minimum_load_alignment:#x}"
        )''',
    )

    replace_once(
        verifier,
        '                    alignments, relro, relro_status = verify_elf(library, objdump)',
        '                    minimum_load_alignment = MINIMUM_LOAD_ALIGNMENT_BY_ABI.get(abi)\n'
        '                    if minimum_load_alignment is None:\n'
        '                        raise VerificationError(\n'
        '                            f"No native alignment policy configured for ABI {abi}"\n'
        '                        )\n'
        '                    alignments, relro, relro_status = verify_elf(\n'
        '                        library, objdump, minimum_load_alignment\n'
        '                    )',
    )

    replace_once(
        verifier,
        '''                        "minimum_load_alignment": f"0x{min(alignments):x}",
                        "gnu_relro": relro,''',
        '''                        "minimum_load_alignment": f"0x{min(alignments):x}",
                        "required_minimum_load_alignment": (
                            f"0x{minimum_load_alignment:x}"
                        ),
                        "gnu_relro": relro,''',
    )

    tests = ROOT / "tool/android/test_verify_16kb.py"
    replace_once(
        tests,
        '''from verify_16kb import (  # noqa: E402
    VerificationError,''',
        '''from verify_16kb import (  # noqa: E402
    MINIMUM_LOAD_ALIGNMENT_BY_ABI,
    VerificationError,''',
    )
    replace_once(
        tests,
        '''class Verify16KbTest(unittest.TestCase):
    def test_parses_aapt_badging(self) -> None:''',
        '''class Verify16KbTest(unittest.TestCase):
    def test_uses_abi_specific_alignment_policy(self) -> None:
        self.assertEqual(MINIMUM_LOAD_ALIGNMENT_BY_ABI["armeabi-v7a"], 0x1000)
        self.assertEqual(MINIMUM_LOAD_ALIGNMENT_BY_ABI["arm64-v8a"], 0x4000)
        self.assertEqual(MINIMUM_LOAD_ALIGNMENT_BY_ABI["x86_64"], 0x4000)

    def test_parses_aapt_badging(self) -> None:''',
    )

    report = ROOT / "third_party/libtdjson/android/ARMEABI_V7A_BUILD_REPORT.txt"
    report.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
