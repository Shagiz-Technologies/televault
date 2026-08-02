from __future__ import annotations

import unittest

from tool.android.check_release_logs import scan


class CheckReleaseLogsTest(unittest.TestCase):
    def test_accepts_redacted_operational_logs(self) -> None:
        content = "\n".join(
            (
                "TeleVault: TDLib client initialized.",
                "TeleVault: upload state changed to pending.",
                "TeleVault: Reviewer Demo simulated upload complete.",
            )
        )

        self.assertEqual([], scan(content, ["private-value"]))

    def test_reports_categories_without_returning_secret_values(self) -> None:
        secret = "do-not-echo-this"
        content = "\n".join(
            (
                'phone_number = "+15551234567"',
                'checkAuthenticationCode {"code":"12345"}',
                "api_hash=abc123",
                "TVRK1-AAAA-BBBB-CCCC-DDDD",
                "/data/user/0/et.shagiz.tele_vault/files/media.jpg",
                f"payload={secret}",
            )
        )

        findings = scan(content, [secret])

        self.assertGreaterEqual(len(findings), 6)
        self.assertFalse(any(secret in finding for finding in findings))


if __name__ == "__main__":
    unittest.main()
