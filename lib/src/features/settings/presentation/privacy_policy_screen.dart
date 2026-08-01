import 'package:flutter/material.dart';

import '../../../core/presentation/responsive_layout.dart';
import 'terms_summary_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & transparency')),
      body: SingleChildScrollView(
        padding: AppResponsive.pagePaddingWithBottomSafe(
          context,
          horizontal: 20,
          top: 20,
          bottomExtra: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TeleVault Privacy Summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: August 1, $year',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),
            _section(
              'Who provides the app',
              'TeleVault is developed by Shagiz Technologies. It is an independent project and is not affiliated with, endorsed by, or sponsored by Telegram.',
            ),
            _section(
              'Data stored on your device',
              'TeleVault stores local bucket records, media identifiers, paths exposed by Android, labels, upload and retry status, Telegram message references, settings, vault state, and local diagnostics in application-private storage. TDLib separately stores the Telegram session and cache in application-private storage.',
            ),
            _section(
              'Data sent to Telegram',
              'When backup is enabled, selected photos, videos, and encrypted metadata snapshots are sent through TDLib to Telegram channels associated with your authenticated Telegram account. Telegram and TDLib process login, channels, messages, file transfer, storage, and retrieval. TeleVault does not operate a separate media-storage backend.',
            ),
            _section(
              'Encryption boundaries',
              'Normal non-vault photos and videos are not client-side end-to-end encrypted by TeleVault before upload. Files intentionally processed through the Vault use authenticated TeleVault client-side encryption. Metadata snapshots use their documented encrypted format. A private Telegram channel does not prevent Telegram from processing its contents.',
            ),
            _section(
              'Vault Recovery Key',
              'The Vault PIN, password, or device biometric controls local access. Portable Vault recovery uses a separate high-entropy Recovery Key. Keep an exported copy private. Losing both the installed secure-storage copy and your exported key can make Vault backups unrecoverable.',
            ),
            _section(
              'Android permissions',
              'Photo and video permission is used to discover, display, organize, and back up media. On Android 14 and later, selected-media access limits TeleVault to the items you choose. Internet access is used for Telegram. Biometric permissions support optional app and Vault access. TeleVault does not request all-files access or media-location access.',
            ),
            _section(
              'Background backup',
              'Android may delay, pause, or stop background work because of network, battery, device-vendor, or operating-system restrictions. TeleVault cannot guarantee immediate or uninterrupted background backup. Verify important uploads before deleting local originals.',
            ),
            _section(
              'Retention and deletion',
              'Logging out removes account-scoped local metadata, caches, temporary exports, access secrets, and the TDLib session, subject to the options shown during logout. Uninstalling normally removes local application data. Logout and uninstall do not automatically delete Telegram channels, uploaded files, messages, or metadata snapshots. Delete remote content through Telegram or supported TeleVault controls.',
            ),
            _section(
              'Analytics and advertising',
              'The current production implementation does not include advertising SDKs or an external analytics SDK. Local diagnostics are used for operational troubleshooting and should not intentionally include authentication secrets or private media content.',
            ),
            _section(
              'Support and security',
              'Use the TeleVault GitHub issue forms for non-sensitive support. Never post Telegram login codes, passwords, API credentials, session files, private media, database files, Recovery Keys, or unredacted logs publicly. Report security vulnerabilities through the repository private vulnerability-reporting channel.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('Read Terms of Service'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsSummaryScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© $year Shagiz Technologies',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[300],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
