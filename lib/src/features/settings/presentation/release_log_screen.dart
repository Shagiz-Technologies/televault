import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/presentation/tele_vault_ui.dart';
import '../../../core/presentation/televault_logo_mark.dart';
import '../../../core/theme/app_theme.dart';

class ReleaseLogScreen extends StatefulWidget {
  const ReleaseLogScreen({super.key});

  @override
  State<ReleaseLogScreen> createState() => _ReleaseLogScreenState();
}

class _ReleaseLogScreenState extends State<ReleaseLogScreen> {
  late final PageController _controller;
  int _page = 0;

  static const _releases = [
    _ReleaseEntry(
      version: '1.0',
      label: 'Gallery first',
      badge: 'NEW',
      summary: 'A cleaner start for your memories.',
      colors: [Color(0xFFDDF2FF), Color(0xFFF7FCFF)],
      features: [
        _ReleaseFeature(
          icon: Icons.schedule_rounded,
          color: AppTheme.primary,
          title: 'Real-time backup status',
          text: 'Know exactly what is happening.',
        ),
        _ReleaseFeature(
          icon: Icons.shield_outlined,
          color: AppTheme.success,
          title: 'Private Vault',
          text: 'Vault media is encrypted in your own cloud.',
        ),
        _ReleaseFeature(
          icon: Icons.label_outline_rounded,
          color: AppTheme.warning,
          title: 'Labels and filters',
          text: 'Find what matters, faster.',
        ),
        _ReleaseFeature(
          icon: Icons.lock_reset_rounded,
          color: AppTheme.error,
          title: 'Safer metadata recovery',
          text: 'Restore your map with confidence.',
        ),
      ],
    ),
    _ReleaseEntry(
      version: '0.9',
      label: 'Stability first',
      badge: 'RC',
      summary: 'Correct uploads, safer locks, fewer surprises.',
      colors: [Color(0xFFE1F8F0), Color(0xFFF8FEFB)],
      features: [
        _ReleaseFeature(
          icon: Icons.verified_outlined,
          color: AppTheme.success,
          title: 'Confirmed uploads',
          text: 'Files complete only after Telegram confirms them.',
        ),
        _ReleaseFeature(
          icon: Icons.refresh_rounded,
          color: AppTheme.primary,
          title: 'Retry and resume',
          text: 'Temporary failures no longer end the queue.',
        ),
        _ReleaseFeature(
          icon: Icons.phonelink_lock_rounded,
          color: AppTheme.warning,
          title: 'Stronger app lock',
          text: 'Phone security and TeleVault credentials.',
        ),
        _ReleaseFeature(
          icon: Icons.swap_horiz_rounded,
          color: AppTheme.error,
          title: 'Safe bucket switching',
          text: 'Pending metadata is preserved.',
        ),
      ],
    ),
    _ReleaseEntry(
      version: '0.1',
      label: 'The prototype',
      badge: 'ORIGIN',
      summary: 'The first working TeleVault backup loop.',
      colors: [Color(0xFFFFF0DA), Color(0xFFFFFCF7)],
      features: [
        _ReleaseFeature(
          icon: Icons.send_outlined,
          color: AppTheme.primary,
          title: 'Telegram connection',
          text: 'Sign in through TDLib.',
        ),
        _ReleaseFeature(
          icon: Icons.cloud_outlined,
          color: AppTheme.success,
          title: 'Private buckets',
          text: 'Create channels for your media.',
        ),
        _ReleaseFeature(
          icon: Icons.storage_outlined,
          color: AppTheme.warning,
          title: 'Local metadata',
          text: 'Track files with a Drift database.',
        ),
        _ReleaseFeature(
          icon: Icons.photo_library_outlined,
          color: AppTheme.error,
          title: 'Gallery foundation',
          text: 'Library, albums, and media selection.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What's new")),
      body: TeleVaultPage(
        safeTop: false,
        safeBottom: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                padEnds: true,
                itemCount: _releases.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _ReleaseCard(release: _releases[index]),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                13,
                16,
                AppResponsive.bottomSafeGap(context, extra: 13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _releases.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: index == _page ? 9 : 7,
                    height: index == _page ? 9 : 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _page
                          ? AppTheme.primary
                          : AppTheme.outline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final _ReleaseEntry release;

  const _ReleaseCard({required this.release});

  @override
  Widget build(BuildContext context) {
    return TeleVaultCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(22),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ReleaseArtwork(colors: release.colors),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    release.badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Gap(8),
                Text(
                  'Version ${release.version} · ${release.label}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Gap(4),
                Text(
                  release.summary,
                  style: const TextStyle(
                    color: AppTheme.inkMuted,
                    fontSize: 12,
                  ),
                ),
                const Gap(17),
                ...release.features.map(
                  (feature) => _ReleaseFeatureRow(feature: feature),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseArtwork extends StatelessWidget {
  final List<Color> colors;

  const _ReleaseArtwork({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: -25,
            bottom: -48,
            child: Icon(
              Icons.cloud_rounded,
              size: 150,
              color: Color(0xB3FFFFFF),
            ),
          ),
          const Positioned(
            right: -18,
            top: 4,
            child: Icon(
              Icons.cloud_rounded,
              size: 118,
              color: Color(0x8FFFFFFF),
            ),
          ),
          const TeleVaultLogoMark(size: 112, shadow: true),
          _FloatingMediaIcon(
            alignment: const Alignment(-0.72, -0.35),
            icon: Icons.photo_outlined,
            color: AppTheme.primary,
            angle: -0.14,
          ),
          _FloatingMediaIcon(
            alignment: const Alignment(0.74, -0.10),
            icon: Icons.movie_outlined,
            color: AppTheme.warning,
            angle: 0.12,
          ),
          _FloatingMediaIcon(
            alignment: const Alignment(0.58, 0.67),
            icon: Icons.music_note_rounded,
            color: AppTheme.primaryDeep,
            angle: 0.16,
          ),
          const Positioned(
            top: 21,
            child: Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 55,
              shadows: [
                Shadow(
                  color: Color(0x3314212B),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingMediaIcon extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final Color color;
  final double angle;

  const _FloatingMediaIcon({
    required this.alignment,
    required this.icon,
    required this.color,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F14212B),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 27),
        ),
      ),
    );
  }
}

class _ReleaseFeatureRow extends StatelessWidget {
  final _ReleaseFeature feature;

  const _ReleaseFeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(feature.icon, color: feature.color, size: 29),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(2),
                Text(
                  feature.text,
                  style: const TextStyle(
                    color: AppTheme.inkMuted,
                    fontSize: 10,
                  ),
                ),
              ],
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
  final String badge;
  final String summary;
  final List<Color> colors;
  final List<_ReleaseFeature> features;

  const _ReleaseEntry({
    required this.version,
    required this.label,
    required this.badge,
    required this.summary,
    required this.colors,
    required this.features,
  });
}

class _ReleaseFeature {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _ReleaseFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });
}
