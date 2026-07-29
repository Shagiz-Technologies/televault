import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/services/external_url_service.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  static const lastUpdated = 'July 29, 2026';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Transparency')),
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
              'Privacy summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Gap(6),
            const Text(
              'Last policy update: $lastUpdated',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const Gap(24),
            const _PrivacySection(
              title: 'Where your data goes',
              body:
                  'TeleVault stores library, bucket, label, settings, and sync '
                  'metadata locally on your device. Selected backup media is '
                  'sent through TDLib to Telegram channels connected to your '
                  'Telegram account.',
            ),
            const _PrivacySection(
              title: 'Telegram is the storage provider',
              body:
                  'TeleVault does not operate a media-storage backend in the '
                  'current implementation. Telegram and TDLib process login, '
                  'channel access, uploaded files, and related account data '
                  'under Telegram\'s own terms and privacy practices.',
            ),
            const _PrivacySection(
              title: 'Encryption boundary',
              body:
                  'Normal non-vault media is not currently client-side '
                  'encrypted by TeleVault before upload. Media intentionally '
                  'processed through the TeleVault vault flow is encrypted by '
                  'that flow.',
            ),
            const _PrivacySection(
              title: 'Diagnostics',
              body:
                  'The reviewed app includes local operational diagnostics. '
                  'No external analytics or telemetry SDK was identified '
                  'during open-source preparation. Never share credentials, '
                  'private media, databases, or unredacted logs publicly.',
            ),
            const _PrivacySection(
              title: 'Deletion',
              body:
                  'Clearing app data or uninstalling normally removes local '
                  'application data. It does not automatically delete '
                  'Telegram bucket channels, messages, files, or exported '
                  'metadata packages.',
            ),
            const Gap(6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => openExternalUrl(
                  context,
                  ref.read(externalUrlServiceProvider),
                  LegalUrls.privacyPolicy,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Read full Privacy Policy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Gap(7),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
