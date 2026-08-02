from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from tool.android.verify_play_store_readiness import REQUIRED_DOCUMENTS, verify


class VerifyPlayStoreReadinessTest(unittest.TestCase):
    def _write(self, root: Path, relative: str, content: str) -> None:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def _valid_tree(self, root: Path) -> None:
        for document in REQUIRED_DOCUMENTS:
            self._write(root, document, "release document\n")

        self._write(
            root,
            "lib/src/features/settings/presentation/privacy_policy_screen.dart",
            "\n".join(
                (
                    "not affiliated with, endorsed by, or sponsored by Telegram",
                    "Normal non-vault photos and videos are not client-side end-to-end encrypted",
                    "Android may delay, pause, or stop background work",
                    "do not automatically delete Telegram channels",
                    "Vault Recovery Key",
                )
            ),
        )
        self._write(
            root,
            "lib/src/features/settings/presentation/terms_summary_screen.dart",
            "Terms of Service\n",
        )
        self._write(
            root,
            "lib/src/features/auth/login_screen.dart",
            "Terms of Service\nPrivacy Policy\n",
        )
        self._write(
            root,
            "docs/play-store/STORE_LISTING_COPY.md",
            "# Store listing\n## Short description\nPrivate Telegram backup.\n"
            "## Full description\nAccurate details.\n",
        )
        self._write(
            root,
            "docs/play-store/APP_ACCESS.md",
            "\n".join(
                (
                    "Google Play Reviewer Demo",
                    "REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM",
                    "No Telegram account or reviewer credential is required",
                    "Exit reviewer demo",
                )
            ),
        )
        self._write(root, "pubspec.yaml", "dependencies:\n  flutter:\n")
        self._write(
            root,
            "android/app/src/main/AndroidManifest.xml",
            "READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_VISUAL_USER_SELECTED",
        )

    def test_accepts_valid_release_sources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._valid_tree(root)
            self.assertEqual([], verify(root))

    def test_rejects_forbidden_permission_dependency_and_copy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._valid_tree(root)
            self._write(
                root,
                "android/app/src/main/AndroidManifest.xml",
                "READ_MEDIA_IMAGES READ_MEDIA_VIDEO "
                "READ_MEDIA_VISUAL_USER_SELECTED ACCESS_MEDIA_LOCATION",
            )
            self._write(root, "pubspec.yaml", "dependencies:\n  google_sign_in: any\n")
            self._write(
                root,
                "docs/play-store/STORE_LISTING_COPY.md",
                "## Short description\nUnlimited cloud storage.\n"
                "## Full description\nDetails.\n",
            )

            errors = verify(root)
            self.assertTrue(any("ACCESS_MEDIA_LOCATION" in error for error in errors))
            self.assertTrue(any("google_sign_in" in error for error in errors))
            self.assertTrue(any("unlimited cloud storage" in error for error in errors))

    def test_rejects_retired_test_dc_reviewer_instructions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._valid_tree(root)
            self._write(
                root,
                "docs/play-store/APP_ACCESS.md",
                "Google Play reviewer access: enter 99966XYYYY and XXXXX.\n",
            )

            errors = verify(root)

            self.assertTrue(any("99966XYYYY" in error for error in errors))
            self.assertTrue(any("XXXXX" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
