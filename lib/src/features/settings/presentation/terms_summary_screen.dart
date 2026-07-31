import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/services/external_url_service.dart';
import '../../../core/theme/app_theme.dart';

class TermsSummaryScreen extends ConsumerWidget {
  const TermsSummaryScreen({super.key});

  static const lastUpdated = 'July 29, 2026';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'Terms summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(6),
            const Text(
              'Last updated: $lastUpdated',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const Gap(24),
            const _TermsSection(
              title: 'Telegram is a dependency',
              body:
                  'TeleVault uses your existing Telegram account and TDLib. '
                  'Telegram controls account access, storage limits, service '
                  'availability, and uploaded files under its own terms.',
            ),
            const _TermsSection(
              title: 'Keep independent backups',
              body:
                  'TeleVault cannot guarantee storage capacity, file '
                  'permanence, uninterrupted uploads, or successful recovery. '
                  'Keep another copy of important files.',
            ),
            const _TermsSection(
              title: 'Use it lawfully',
              body:
                  'Only back up content you own or are authorized to process. '
                  'Do not use TeleVault to abuse Telegram, evade controls, or '
                  'violate applicable law.',
            ),
            const _TermsSection(
              title: 'Understand encryption boundaries',
              body:
                  'Normal non-vault uploads are not client-side encrypted by '
                  'TeleVault. Media processed through the vault flow is '
                  'encrypted by that flow.',
            ),
            const Gap(8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => openExternalUrl(
                  context,
                  ref.read(externalUrlServiceProvider),
                  LegalUrls.termsOfService,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Read full Terms of Service'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

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
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(7),
          Text(
            body,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
