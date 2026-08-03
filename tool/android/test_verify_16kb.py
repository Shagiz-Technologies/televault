from pathlib import Path
import sys
import unittest


sys.path.insert(0, str(Path(__file__).parent))
from verify_16kb import (  # noqa: E402
    MINIMUM_LOAD_ALIGNMENT_BY_ABI,
    VerificationError,
    parse_badging,
    parse_load_alignments,
    parse_objdump_load_alignments,
    parse_relocation_sensitive_sections,
    verify_provenance_digest,
)


class Verify16KbTest(unittest.TestCase):
    def test_uses_abi_specific_alignment_policy(self) -> None:
        self.assertEqual(MINIMUM_LOAD_ALIGNMENT_BY_ABI["armeabi-v7a"], 0x1000)
        self.assertEqual(MINIMUM_LOAD_ALIGNMENT_BY_ABI["arm64-v8a"], 0x4000)
        self.assertEqual(MINIMUM_LOAD_ALIGNMENT_BY_ABI["x86_64"], 0x4000)

    def test_parses_aapt_badging(self) -> None:
        package, min_sdk, target_sdk = parse_badging(
            "package: name='et.shagiz.tele_vault' versionCode='1' platformBuildVersionCode='36'\n"
            "sdkVersion:'24'\ntargetSdkVersion:'36'\n"
        )
        self.assertEqual((package, min_sdk, target_sdk), ("et.shagiz.tele_vault", 24, 36))

    def test_parses_current_aapt2_min_sdk_label(self) -> None:
        package, min_sdk, target_sdk = parse_badging(
            "package: name='et.shagiz.tele_vault' versionCode='1' "
            "platformBuildVersionCode='36'\n"
            "minSdkVersion:'24'\ntargetSdkVersion:'36'\n"
        )
        self.assertEqual((package, min_sdk, target_sdk), ("et.shagiz.tele_vault", 24, 36))

    def test_parses_all_load_alignments(self) -> None:
        output = (
            "  LOAD 0x000000 0x0 0x0 0x1 0x1 R   0x4000\n"
            "  LOAD 0x004000 0x1 0x1 0x2 0x2 R E 0x10000\n"
        )
        self.assertEqual(parse_load_alignments(output), [0x4000, 0x10000])

    def test_rejects_unparseable_load_alignment(self) -> None:
        with self.assertRaises(VerificationError):
            parse_load_alignments("  LOAD malformed\n")

    def test_parses_official_objdump_load_alignments(self) -> None:
        output = (
            "    LOAD off 0x0000 vaddr 0x0000 paddr 0x0000 align 2**14\n"
            "    LOAD off 0x4000 vaddr 0x4000 paddr 0x4000 align 2**16\n"
        )
        self.assertEqual(parse_objdump_load_alignments(output), [0x4000, 0x10000])

    def test_parses_relocation_sensitive_objdump_sections(self) -> None:
        output = (
            "Sections:\n"
            "Idx Name          Size     VMA              Type\n"
            "  0 .text         00000010 0000000000000000 TEXT\n"
            "  1 .got          00000008 0000000000000010 DATA\n"
            "  2 .rela.dyn     00000018 0000000000000018 DATA\n"
        )
        self.assertEqual(
            parse_relocation_sensitive_sections(output), [".got", ".rela.dyn"]
        )

    def test_accepts_objdump_sections_without_relocations(self) -> None:
        output = (
            "Sections:\n"
            "Idx Name          Size     VMA              Type\n"
            "  0 .text         00000010 0000000000000000 TEXT\n"
        )
        self.assertEqual(parse_relocation_sensitive_sections(output), [])

    def test_rejects_unrecognized_objdump_sections(self) -> None:
        with self.assertRaises(VerificationError):
            parse_relocation_sensitive_sections("no section table")

    def test_accepts_reviewed_native_hash(self) -> None:
        verify_provenance_digest(
            entry="lib/arm64-v8a/libtdjson.so",
            abi="arm64-v8a",
            digest="reviewed",
            provenance={"sha256_by_abi": {"arm64-v8a": "reviewed"}},
        )

    def test_rejects_unreviewed_native_hash(self) -> None:
        with self.assertRaises(VerificationError):
            verify_provenance_digest(
                entry="lib/arm64-v8a/libtdjson.so",
                abi="arm64-v8a",
                digest="changed",
                provenance={"sha256_by_abi": {"arm64-v8a": "reviewed"}},
            )


if __name__ == "__main__":
    unittest.main()
