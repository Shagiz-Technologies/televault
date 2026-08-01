import 'package:flutter/material.dart';

import '../../../core/presentation/responsive_layout.dart';

class TermsSummaryScreen extends StatelessWidget {
  const TermsSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
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
              'TeleVault Terms of Service',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective: August 1, $year',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),
            _section(
              'Service scope',
              'TeleVault is an independent Android application that helps you organize and upload selected photos and videos to private Telegram channels connected to your Telegram account. TeleVault is not affiliated with, endorsed by, or sponsored by Telegram.',
            ),
            _section(
              'Your Telegram account',
              'You are responsible for your Telegram account, login credentials, two-step verification, channel access, and compliance with Telegram rules. Telegram and TDLib process authentication, channels, messages, and uploaded files.',
            ),
            _section(
              'Storage and availability',
              'TeleVault does not operate the Telegram storage service. Upload limits, retention, availability, and account restrictions are controlled by Telegram and may change. Android may defer or stop background work because of battery, network, or operating-system restrictions.',
            ),
            _section(
              'Encryption boundaries',
              'Normal non-vault uploads are not client-side end-to-end encrypted by TeleVault. Files intentionally processed through the Vault use TeleVault client-side encryption. You must retain the Vault Recovery Key; losing both the installed secure-storage copy and your exported key can make Vault backups unrecoverable.',
            ),
            _section(
              'Deletion and logout',
              'Logging out or uninstalling removes or may remove local application data. It does not automatically delete private Telegram channels, uploaded files, messages, or metadata snapshots. You must remove remote Telegram content through Telegram or supported TeleVault controls.',
            ),
            _section(
              'No warranty',
              'TeleVault is provided without a guarantee that every upload, restore, background task, or third-party service will always be available. Keep an independent backup of important files and verify uploads before deleting local originals.',
            ),
            _section(
              'Acceptable use',
              'Do not use TeleVault to store or distribute content you do not have the right to possess or upload, to violate applicable law, or to interfere with Telegram or other services.',
            ),
            _section(
              'Open-source software',
              'The source repository and bundled third-party notices describe the open-source licenses that apply to TeleVault and its dependencies. These terms do not replace those licenses.',
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
