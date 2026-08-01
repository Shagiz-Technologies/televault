import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final _sourceUri = Uri.parse(
    'https://github.com/Shagiz-Technologies/televault',
  );
  static final _licenseUri = Uri.parse(
    'https://github.com/Shagiz-Technologies/televault/blob/main/LICENSE',
  );

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('About TeleVault')),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: ResponsivePage(
          maxWidth: 520,
          centerVertically: false,
          padding: AppResponsive.pagePaddingWithBottomSafe(
            context,
            horizontal: 20,
            top: 8,
            bottomExtra: 22,
          ),
          child: Column(
            children: [
              const Gap(5),
              const TeleVaultLogoMark(size: 128, shadow: true),
              const Gap(15),
              Text(
                'TeleVault',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const Gap(2),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data?.version ?? '1.0.0',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
              const Gap(24),
              const _AboutValue(
                icon: Icons.cloud_outlined,
                color: AppTheme.primary,
                title: 'Built for your own cloud',
                text:
                    'You stay in control of your media. '
                    'We simply help you back it up.',
              ),
              const Gap(15),
              const _AboutValue(
                icon: Icons.eco_outlined,
                color: AppTheme.success,
                title: 'Independent by design',
                text:
                    'No TeleVault media server. No data warehouse. '
                    'No AI learning what you ate for lunch.',
              ),
              const Gap(15),
              const _AboutValue(
                icon: Icons.code_rounded,
                color: AppTheme.warning,
                title: 'Open source',
                text:
                    'Transparent, auditable, and made for the community '
                    'under the MIT License.',
              ),
              const Gap(22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(context, _sourceUri),
                      icon: const Icon(Icons.code_rounded),
                      label: const Text('View source'),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(context, _licenseUri),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('MIT License'),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              const TeleVaultCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    TeleVaultIconBadge(
                      icon: Icons.favorite_border_rounded,
                      color: AppTheme.inkMuted,
                      size: 46,
                    ),
                    Gap(13),
                    Expanded(
                      child: Text(
                        'Independent and not affiliated with, endorsed by, '
                        'or sponsored by Telegram.',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(34),
              Text(
                '© $year Shagiz Technologies',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppTheme.inkMuted),
              ),
              const Gap(5),
              Text(
                'ማሔር ሻላል ሓዥ ባዝ',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 8,
                  color: AppTheme.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open the link')));
    }
  }
}

class _AboutValue extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _AboutValue({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeleVaultIconBadge(
          icon: icon,
          color: color,
          backgroundColor: Colors.transparent,
          size: 48,
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Gap(3),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink,
                  height: 1.42,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
