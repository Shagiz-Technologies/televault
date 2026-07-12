import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final compactHeight = MediaQuery.sizeOf(context).height < 720;
    final logoSize = compactHeight ? 68.0 : 76.0;
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom + 56;

    return Scaffold(
      appBar: AppBar(title: const Text('About TeleVault')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSafePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TeleVaultLogoMark(size: logoSize, shadow: false),
                  ),
                  const Gap(12),
                  const Text(
                    'TeleVault',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Gap(6),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  const Gap(10),
                  const Text(
                    'Telegram-powered media backup and vault for people who want their gallery to stay theirs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            _buildInfoCard(
              children: [
                _buildInfoRow(
                  icon: Icons.business_outlined,
                  label: 'Developer',
                  value: 'Shagiz Technologies',
                ),
                const Divider(height: 20, color: Colors.white10),
                _buildInfoRow(
                  icon: Icons.code_rounded,
                  label: 'License',
                  value: 'MIT Open Source',
                ),
                const Divider(height: 20, color: Colors.white10),
                _buildInfoRow(
                  icon: Icons.send_outlined,
                  label: 'Affiliation',
                  value: 'Independent from Telegram',
                ),
              ],
            ),
            const Gap(16),
            _buildBodyCard(
              icon: Icons.cloud_done_outlined,
              title: 'What it does',
              text:
                  'TeleVault turns your private Telegram channels into a personal backup shelf for photos and videos. It keeps the experience simple: open the library, protect what matters, and let the app handle the backup queue.',
            ),
            const Gap(12),
            _buildBodyCard(
              icon: Icons.savings_outlined,
              title: 'Why privacy is easier here',
              text:
                  'We are too broke to run a giant data warehouse, and that is good news for your privacy. Your media stays in your Telegram space. We do not keep a copy, sell a copy, or train an AI model to recognize your lunch, receipts, or blurry screenshots.',
            ),
            const Gap(28),
            Text(
              '\u00A9 $year Copyright',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const Gap(4),
            Text(
              '\u121B\u1214\u122D \u123B\u120B\u120D \u1213\u12E5 \u1263\u12DD',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 9,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildBodyCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const Gap(10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Gap(3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
