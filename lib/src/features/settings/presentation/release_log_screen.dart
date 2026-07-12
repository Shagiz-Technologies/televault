import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';

class ReleaseLogScreen extends StatefulWidget {
  const ReleaseLogScreen({super.key});

  @override
  State<ReleaseLogScreen> createState() => _ReleaseLogScreenState();
}

class _ReleaseLogScreenState extends State<ReleaseLogScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _releases = [
    _ReleaseEntry(
      version: '1.0.0',
      label: 'Production Foundation',
      date: '2026',
      summary:
          'The first production-focused TeleVault release: Android-first media backup, bucket controls, vault security, metadata recovery, and a cleaner gallery-like experience.',
      highlights: [
        _FeatureGroup(
          title: 'Backup',
          icon: Icons.cloud_upload_outlined,
          items: [
            'Telegram private channel buckets for photos and videos',
            'Oldest-to-newest upload ordering',
            'Visible backup status indicators in the library',
            'Auto Backup toggle and bucket-specific sync preferences',
          ],
        ),
        _FeatureGroup(
          title: 'Metadata Recovery',
          icon: Icons.settings_backup_restore_rounded,
          items: [
            'Dedicated TeleVault metadata channel',
            'Automatic metadata refresh after successful uploads',
            'Safe Uninstall metadata backup without waiting for every pending file',
            'Account-bound metadata restore after Telegram login',
          ],
        ),
        _FeatureGroup(
          title: 'Vault & Privacy',
          icon: Icons.lock_outline_rounded,
          items: [
            'Vault protection with TeleVault credentials or phone security',
            'Vault-only media encryption path',
            'App lock with phone security support',
            'Privacy-minimal local diagnostics',
          ],
        ),
        _FeatureGroup(
          title: 'Library Experience',
          icon: Icons.photo_library_outlined,
          items: [
            'Google Photos-like library-first navigation',
            'Albums, Vault, and Settings tabs',
            'Media labels with colors and compact badges',
            'Image viewer actions and selection improvements',
          ],
        ),
      ],
    ),
    _ReleaseEntry(
      version: '0.9.x',
      label: 'Stability Tranches',
      date: '2026',
      summary:
          'Hardening work before the first release candidate: upload correctness, app lock fixes, bucket safety, and Play Store preparation.',
      highlights: [
        _FeatureGroup(
          title: 'Reliability',
          icon: Icons.verified_outlined,
          items: [
            'Wait for Telegram confirmation before marking files synced',
            'Retry and resume behavior for failed uploads',
            'Safer bucket switching without deleting pending metadata',
            'Startup and splash-screen loop fixes',
          ],
        ),
        _FeatureGroup(
          title: 'Security',
          icon: Icons.security_outlined,
          items: [
            'Hashed app/vault credentials',
            'Lockout behavior for repeated failed unlock attempts',
            'Sensitive local files excluded from open-source release',
            'Telegram account-bound metadata packages',
          ],
        ),
        _FeatureGroup(
          title: 'Release Prep',
          icon: Icons.rocket_launch_outlined,
          items: [
            'Android namespace moved to et.shagiz.tele_vault',
            'README, LICENSE, privacy and security docs',
            'GitHub CI and sanitized public repository setup',
            'Play Store release artifact preparation',
          ],
        ),
      ],
    ),
    _ReleaseEntry(
      version: '0.1.x',
      label: 'Prototype',
      date: '2026',
      summary:
          'The original TeleVault concept: authenticate with Telegram, create a bucket, scan local media, and build the first gallery/backup loop.',
      highlights: [
        _FeatureGroup(
          title: 'Core App',
          icon: Icons.foundation_outlined,
          items: [
            'Telegram login and TDLib setup',
            'Private bucket creation',
            'Local Drift database for media metadata',
            'Initial gallery, albums, settings, and upload queue',
          ],
        ),
        _FeatureGroup(
          title: 'Early Features',
          icon: Icons.auto_awesome_outlined,
          items: [
            'Basic vault flag and PIN gate',
            'Media selection actions',
            'Simple activity/status views',
            'Early metadata export/import experiments',
          ],
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = _releases[_page];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Release Log')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _ReleaseHeader(
              page: _page,
              total: _releases.length,
              release: release,
              onPrevious: _page == 0
                  ? null
                  : () => _controller.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
              onNext: _page == _releases.length - 1
                  ? null
                  : () => _controller.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _releases.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                return _ReleasePage(release: _releases[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseHeader extends StatelessWidget {
  final int page;
  final int total;
  final _ReleaseEntry release;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _ReleaseHeader({
    required this.page,
    required this.total,
    required this.release,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous release',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Release ${page + 1} of $total',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Gap(4),
                Text(
                  '${release.version} · ${release.label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next release',
          ),
        ],
      ),
    );
  }
}

class _ReleasePage extends StatelessWidget {
  final _ReleaseEntry release;

  const _ReleasePage({required this.release});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppResponsive.bottomSafeGap(context, extra: 18),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A84FF), Color(0xFF1C1C1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                release.version,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Gap(4),
              Text(
                '${release.label} · ${release.date}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(12),
              Text(
                release.summary,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const Gap(14),
        ...release.highlights.map((group) => _FeatureGroupCard(group: group)),
      ],
    );
  }
}

class _FeatureGroupCard extends StatelessWidget {
  final _FeatureGroup group;

  const _FeatureGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, color: AppTheme.primary),
              const Gap(10),
              Text(
                group.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Gap(10),
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5BE37D),
                      size: 14,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseEntry {
  final String version;
  final String label;
  final String date;
  final String summary;
  final List<_FeatureGroup> highlights;

  const _ReleaseEntry({
    required this.version,
    required this.label,
    required this.date,
    required this.summary,
    required this.highlights,
  });
}

class _FeatureGroup {
  final String title;
  final IconData icon;
  final List<String> items;

  const _FeatureGroup({
    required this.title,
    required this.icon,
    required this.items,
  });
}
