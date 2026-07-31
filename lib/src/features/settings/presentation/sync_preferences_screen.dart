import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/database/app_database.dart' show Bucket;
import '../../../core/presentation/responsive_layout.dart';
import '../../../core/services/telegram_reliability_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../buckets/services/bucket_service.dart';
import '../../library/repositories/gallery_repository.dart';
import '../../settings/services/settings_service.dart';
import '../../sync/services/sync_service.dart';

class SyncPreferencesScreen extends ConsumerStatefulWidget {
  const SyncPreferencesScreen({super.key});

  @override
  ConsumerState<SyncPreferencesScreen> createState() =>
      _SyncPreferencesScreenState();
}

class _SyncPreferencesScreenState extends ConsumerState<SyncPreferencesScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _isTelegramPremium = false;
  SyncPreferences _prefs = const SyncPreferences();
  List<AssetPathEntity> _albums = const [];
  Bucket? _activeBucket;
  StreamSubscription<TelegramReliabilityState>? _telegramStateSub;

  @override
  void initState() {
    super.initState();
    _telegramStateSub = ref
        .read(telegramReliabilityServiceProvider)
        .states
        .listen((state) {
          if (!mounted) return;
          setState(() {
            _isTelegramPremium = state.isPremium;
            if (_prefs.maxFileSizeMb > state.effectiveUploadLimitMb) {
              _prefs = _prefs.copyWith(
                maxFileSizeMb: state.effectiveUploadLimitMb,
              );
            }
          });
        });
    _load();
  }

  @override
  void dispose() {
    _telegramStateSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    final gallery = ref.read(galleryRepositoryProvider);
    final activeBucket = await ref
        .read(bucketServiceProvider)
        .getActiveBucket();
    final prefsFuture = settings.getSyncPreferences(bucketId: activeBucket?.id);
    final albumsFuture = gallery.getAlbums();
    final premiumFuture = _loadTelegramPremiumStatus();
    final prefs = await prefsFuture;
    final albums = await albumsFuture;
    final isTelegramPremium = await premiumFuture;
    final normalizedPrefs =
        !isTelegramPremium && prefs.maxFileSizeMb > telegramFreeMaxFileSizeMb
        ? prefs.copyWith(maxFileSizeMb: defaultSyncMaxFileSizeMb)
        : prefs;
    if (!mounted) return;
    setState(() {
      _prefs = normalizedPrefs;
      _albums = albums;
      _activeBucket = activeBucket;
      _isTelegramPremium = isTelegramPremium;
      _loading = false;
    });
  }

  Future<bool> _loadTelegramPremiumStatus() async {
    final reliability = ref.read(telegramReliabilityServiceProvider);
    await reliability.refreshAccountCapabilities();
    return reliability.isPremium;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (!_isTelegramPremium &&
          _prefs.maxFileSizeMb > telegramFreeMaxFileSizeMb) {
        _prefs = _prefs.copyWith(maxFileSizeMb: defaultSyncMaxFileSizeMb);
        _showPremiumLimitInfo();
      }
      await ref
          .read(settingsServiceProvider)
          .saveSyncPreferences(_prefs, bucketId: _activeBucket?.id);
      if (_prefs.autoBackupEnabled) {
        await ref.read(syncServiceProvider).syncNow(ignoreConstraints: false);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync preferences saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Sync Preferences')),
      body: ListView(
        padding: AppResponsive.pagePaddingWithBottomSafe(
          context,
          horizontal: 16,
          top: 16,
          bottomExtra: 18,
        ),
        children: [
          if (_activeBucket != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_outlined, color: AppTheme.primary),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeBucket!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'These preferences apply only to this bucket.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
          ],
          _sectionTitle('Core'),
          SwitchListTile(
            value: _prefs.autoBackupEnabled,
            onChanged: (value) => setState(
              () => _prefs = _prefs.copyWith(autoBackupEnabled: value),
            ),
            title: const Text('Auto Backup'),
            subtitle: const Text('Scan and upload automatically'),
          ),
          SwitchListTile(
            value: _prefs.includePhotos,
            onChanged: (value) =>
                setState(() => _prefs = _prefs.copyWith(includePhotos: value)),
            title: const Text('Include Photos'),
          ),
          SwitchListTile(
            value: _prefs.includeVideos,
            onChanged: (value) =>
                setState(() => _prefs = _prefs.copyWith(includeVideos: value)),
            title: const Text('Include Videos'),
          ),
          const Gap(8),
          _sectionTitleWithInfo('Upload Format', _showUploadFormatInfo),
          _buildUploadFormatSelector(),
          const Gap(8),
          _sectionTitle('Network & Power'),
          SwitchListTile(
            value: _prefs.wifiOnly,
            onChanged: (value) =>
                setState(() => _prefs = _prefs.copyWith(wifiOnly: value)),
            title: const Text('Wi-Fi Only'),
            subtitle: const Text('Preference stored for sync policy'),
          ),
          SwitchListTile(
            value: _prefs.chargingOnly,
            onChanged: (value) =>
                setState(() => _prefs = _prefs.copyWith(chargingOnly: value)),
            title: const Text('Charging Only'),
            subtitle: const Text('Preference stored for sync policy'),
          ),
          const Gap(8),
          _sectionTitle('Albums'),
          _buildAlbumModeSelector(),
          if (_prefs.albumMode != SyncAlbumMode.all) ...[
            const Gap(10),
            ..._albums.map((album) {
              final selected = _prefs.albumIds.contains(album.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (value) {
                  final next = Set<String>.from(_prefs.albumIds);
                  if (value == true) {
                    next.add(album.id);
                  } else {
                    next.remove(album.id);
                  }
                  setState(() => _prefs = _prefs.copyWith(albumIds: next));
                },
                title: Text(album.name),
                dense: true,
              );
            }),
          ],
          const Gap(8),
          _sectionTitle('Limits'),
          _buildMaxFileSizeSelector(),
          const Gap(8),
          _sectionTitle('Diagnostics'),
          SwitchListTile(
            value: _prefs.diagnosticsEnabled,
            onChanged: (value) => setState(
              () => _prefs = _prefs.copyWith(diagnosticsEnabled: value),
            ),
            title: const Text('Enable Diagnostics'),
            subtitle: const Text('Operational telemetry only'),
          ),
          const Gap(16),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Preferences'),
          ),
          const Gap(8),
        ],
      ),
    );
  }

  Widget _buildAlbumModeSelector() {
    return InkWell(
      onTap: _showAlbumModeSheet,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Album Filter Mode',
          suffixIcon: Icon(Icons.expand_more_rounded),
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_album_outlined, size: 18),
            const Gap(10),
            Text(
              _albumModeLabel(_prefs.albumMode),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxFileSizeSelector() {
    return InkWell(
      onTap: _showMaxFileSizeSheet,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Max File Size',
          helperText: _isTelegramPremium
              ? 'Telegram Premium upload limit is available.'
              : '4 GB uploads require Telegram Premium.',
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 18),
            const Gap(10),
            Text(
              _maxFileSizeLabel(_prefs.maxFileSizeMb),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFormatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _uploadFormatTile(
            format: SyncUploadFormat.originalFile,
            icon: Icons.insert_drive_file_outlined,
            title: const Text('Original files'),
            subtitle: const Text(
              'Best for backups. Keeps the original photo/video quality.',
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          _uploadFormatTile(
            format: SyncUploadFormat.compressedMedia,
            icon: Icons.photo_size_select_small_outlined,
            title: const Text('Compressed photos/videos'),
            subtitle: const Text(
              'Saves space and may upload faster, but original quality can be reduced.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadFormatTile({
    required SyncUploadFormat format,
    required IconData icon,
    required Widget title,
    required Widget subtitle,
  }) {
    final selected = _prefs.uploadFormat == format;
    return ListTile(
      onTap: () =>
          setState(() => _prefs = _prefs.copyWith(uploadFormat: format)),
      leading: Icon(
        selected ? Icons.check_circle_rounded : icon,
        color: selected ? const Color(0xFF5BE37D) : Colors.white70,
      ),
      title: title,
      subtitle: subtitle,
    );
  }

  Future<void> _showMaxFileSizeSheet() async {
    final options = const [
      _MaxFileSizeOption(256, '256 MB', 'Small photos and short videos'),
      _MaxFileSizeOption(512, '512 MB', 'Balanced mobile backup limit'),
      _MaxFileSizeOption(1024, '1 GB', 'Large videos'),
      _MaxFileSizeOption(
        defaultSyncMaxFileSizeMb,
        '< 2 GB',
        'Default for non-Premium Telegram accounts',
      ),
      _MaxFileSizeOption(
        telegramPremiumMaxFileSizeMb,
        '< 4 GB',
        '3.9 GB operational cap for Telegram Premium accounts',
        premiumOnly: true,
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.of(sheetContext).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Max File Size',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Gap(4),
                  Text(
                    'Files above this size will stay out of the backup queue.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 13,
                    ),
                  ),
                  const Gap(12),
                  ...options.map((option) {
                    final locked = option.premiumOnly && !_isTelegramPremium;
                    final selected = _prefs.maxFileSizeMb == option.value;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        locked
                            ? Icons.lock_outline_rounded
                            : selected
                            ? Icons.check_circle_rounded
                            : Icons.cloud_queue_outlined,
                        color: locked
                            ? Colors.white38
                            : selected
                            ? const Color(0xFF5BE37D)
                            : Colors.white70,
                      ),
                      title: Text(
                        option.label,
                        style: TextStyle(
                          color: locked ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        option.description,
                        style: TextStyle(
                          color: locked
                              ? Colors.white.withValues(alpha: 0.34)
                              : Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                      trailing: locked
                          ? const Text(
                              'Premium',
                              style: TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (locked) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _showPremiumLimitInfo();
                          });
                          return;
                        }
                        setState(
                          () => _prefs = _prefs.copyWith(
                            maxFileSizeMb: option.value,
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAlbumModeSheet() async {
    final options = SyncAlbumMode.values;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.of(sheetContext).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Album Filter Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Gap(4),
                Text(
                  'Choose which albums TeleVault should include in backups.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                  ),
                ),
                const Gap(12),
                ...options.map((mode) {
                  final selected = _prefs.albumMode == mode;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.photo_album_outlined,
                      color: selected
                          ? const Color(0xFF5BE37D)
                          : Colors.white70,
                    ),
                    title: Text(
                      _albumModeLabel(mode),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _albumModeDescription(mode),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      setState(() => _prefs = _prefs.copyWith(albumMode: mode));
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showUploadFormatInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.of(sheetContext).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Format',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Gap(10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('Original files'),
                  subtitle: Text(
                    'Recommended for backups. Telegram receives each item as a file, preserving the original quality and metadata as much as possible.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_size_select_small_outlined),
                  title: const Text('Compressed photos/videos'),
                  subtitle: Text(
                    'Telegram may process media for viewing and streaming. This can reduce the original quality, but may upload faster and use less space.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPremiumLimitInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Files up to 3.9 GB require Telegram Premium. Free accounts use a 1.9 GB operational cap.',
        ),
      ),
    );
  }

  String _maxFileSizeLabel(int value) {
    if (value == defaultSyncMaxFileSizeMb) return '< 2 GB';
    if (value >= 1024 && value % 1024 == 0) {
      return '${value ~/ 1024} GB';
    }
    if (value > 1024) {
      return '${(value / 1024).toStringAsFixed(1)} GB';
    }
    return '$value MB';
  }

  String _albumModeLabel(SyncAlbumMode mode) {
    return switch (mode) {
      SyncAlbumMode.all => 'All Albums',
      SyncAlbumMode.include => 'Include Selected',
      SyncAlbumMode.exclude => 'Exclude Selected',
    };
  }

  String _albumModeDescription(SyncAlbumMode mode) {
    return switch (mode) {
      SyncAlbumMode.all => 'Back up every photo and video album.',
      SyncAlbumMode.include => 'Back up only albums you select below.',
      SyncAlbumMode.exclude => 'Back up everything except selected albums.',
    };
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionTitleWithInfo(String title, VoidCallback onInfo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'Upload format info',
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MaxFileSizeOption {
  final int value;
  final String label;
  final String description;
  final bool premiumOnly;

  const _MaxFileSizeOption(
    this.value,
    this.label,
    this.description, {
    this.premiumOnly = false,
  });
}
