from pathlib import Path
import sys
import unittest


sys.path.insert(0, str(Path(__file__).parent))
from verify_16kb import (  # noqa: E402
    VerificationError,
    parse_badging,
    parse_load_alignments,
    parse_objdump_load_alignments,
    verify_provenance_digest,
)


class Verify16KbTest(unittest.TestCase):
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
