import tempfile
import unittest
from pathlib import Path

from tool.android.verify_media_permissions import (
    VerificationError,
    verify_lockfile,
    verify_manifest,
)


class MediaPermissionVerifierTest(unittest.TestCase):
    def test_release_manifest_passes(self):
        with tempfile.TemporaryDirectory() as root:
            manifest = Path(root) / "AndroidManifest.xml"
            manifest.write_text(_manifest(), encoding="utf-8")
            permissions = verify_manifest(manifest)
            self.assertIn(
                "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
                permissions,
            )

    def test_location_and_all_files_permissions_fail(self):
        with tempfile.TemporaryDirectory() as root:
            manifest = Path(root) / "AndroidManifest.xml"
            manifest.write_text(
                _manifest(
                    '<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />'
                ),
                encoding="utf-8",
            )
            with self.assertRaises(VerificationError):
                verify_manifest(manifest)

    def test_google_auth_dependency_fails(self):
        with tempfile.TemporaryDirectory() as root:
            lockfile = Path(root) / "pubspec.lock"
            lockfile.write_text("packages:\n  google_sign_in:\n", encoding="utf-8")
            with self.assertRaises(VerificationError):
                verify_lockfile(lockfile)


def _manifest(extra: str = "") -> str:
    return f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
      <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
      <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
      <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
      <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
      {extra}
    </manifest>'''


if __name__ == "__main__":
    unittest.main()
