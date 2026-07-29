import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/services/external_url_service.dart';
import '../../../core/theme/app_theme.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_summary_screen.dart';

class LegalSupportSection extends ConsumerWidget {
  const LegalSupportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final externalUrls = ref.read(externalUrlServiceProvider);

    Future<void> open(String url) async {
      await openExternalUrl(context, externalUrls, url);
    }

    void navigate(Widget screen) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Legal & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _LegalTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => navigate(const PrivacyPolicyScreen()),
              ),
              _LegalTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => navigate(const TermsSummaryScreen()),
              ),
              _LegalTile(
                icon: Icons.delete_outline_rounded,
                title: 'Data & Deletion',
                onTap: () => open(LegalUrls.dataDeletion),
              ),
              _LegalTile(
                icon: Icons.support_agent_rounded,
                title: 'Support',
                onTap: () => open(LegalUrls.support),
              ),
              _LegalTile(
                icon: Icons.security_outlined,
                title: 'Security',
                onTap: () => open(LegalUrls.security),
              ),
              _LegalTile(
                icon: Icons.balance_outlined,
                title: 'Open-source licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'TeleVault',
                  applicationLegalese:
                      'TeleVault source is available under the MIT License. '
                      'Third-party packages retain their own licenses.',
                ),
              ),
              _LegalTile(
                icon: Icons.code_rounded,
                title: 'Source code',
                onTap: () => open(LegalUrls.sourceCode),
              ),
              _LegalTile(
                icon: Icons.info_outline_rounded,
                title: 'About TeleVault',
                showDivider: false,
                onTap: () => navigate(const AboutScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(height: 1, indent: 56, color: Colors.white10),
      ],
    );
  }
}
