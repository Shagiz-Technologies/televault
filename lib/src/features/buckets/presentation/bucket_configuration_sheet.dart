import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/services/settings_service.dart';
import '../services/bucket_service.dart';

class BucketCreationConfiguration {
  final Set<BucketMediaType> allowedTypes;
  final SyncPreferences preferences;

  const BucketCreationConfiguration({
    required this.allowedTypes,
    required this.preferences,
  });
}

Future<BucketCreationConfiguration?> showBucketConfigurationSheet({
  required BuildContext context,
  required String bucketName,
  required SyncPreferences initialPreferences,
  required List<AssetPathEntity> albums,
  required bool isTelegramPremium,
}) {
  return showModalBottomSheet<BucketCreationConfiguration>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surface,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _BucketConfigurationSheet(
        bucketName: bucketName,
        initialPreferences: initialPreferences,
        albums: albums,
        isTelegramPremium: isTelegramPremium,
      ),
    ),
  );
}

class _BucketConfigurationSheet extends StatefulWidget {
  final String bucketName;
  final SyncPreferences initialPreferences;
  final List<AssetPathEntity> albums;
  final bool isTelegramPremium;

  const _BucketConfigurationSheet({
    required this.bucketName,
    required this.initialPreferences,
    required this.albums,
    required this.isTelegramPremium,
  });

  @override
  State<_BucketConfigurationSheet> createState() =>
      _BucketConfigurationSheetState();
}

class _BucketConfigurationSheetState extends State<_BucketConfigurationSheet> {
  late SyncPreferences _preferences;
  late Set<BucketMediaType> _allowedTypes;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
    _allowedTypes = {
      if (_preferences.includePhotos) BucketMediaType.photo,
      if (_preferences.includeVideos) BucketMediaType.video,
    };
    if (_allowedTypes.isEmpty) {
      _allowedTypes = {BucketMediaType.photo, BucketMediaType.video};
    }
  }

  @override
  Widget build(BuildContext context) {
    final noSelectedAlbums =
        _preferences.albumMode == SyncAlbumMode.include &&
        _preferences.albumIds.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'New backup space',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('2 of 2'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(
                      widget.bucketName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(3),
                    const Text(
                      'Choose what this bucket backs up and when it runs.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _sectionTitle('Media'),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mediaChip(
                    type: BucketMediaType.photo,
                    label: 'Photos',
                    icon: Icons.photo_outlined,
                  ),
                  _mediaChip(
                    type: BucketMediaType.video,
                    label: 'Videos',
                    icon: Icons.videocam_outlined,
                  ),
                  const _UnavailableTypeChip(label: 'Documents'),
                  const _UnavailableTypeChip(label: 'Apps'),
                  const _UnavailableTypeChip(label: 'Others'),
                ],
              ),
              const Gap(18),
              _sectionTitle('Automatic backup'),
              const Gap(8),
              _surface(
                SwitchListTile.adaptive(
                  value: _preferences.autoBackupEnabled,
                  onChanged: (value) => setState(
                    () => _preferences = _preferences.copyWith(
                      autoBackupEnabled: value,
                    ),
                  ),
                  secondary: const Icon(Icons.autorenew_rounded),
                  title: const Text('Auto-sync this bucket'),
                  subtitle: const Text(
                    'Scan and upload in the background when allowed.',
                  ),
                ),
              ),
              const Gap(18),
              _sectionTitle('Upload format'),
              const Gap(8),
              _surface(
                Column(
                  children: [
                    _selectionTile(
                      selected:
                          _preferences.uploadFormat ==
                          SyncUploadFormat.originalFile,
                      icon: Icons.insert_drive_file_outlined,
                      title: 'Original files',
                      subtitle: 'Preserves the original quality and metadata.',
                      onTap: () => setState(
                        () => _preferences = _preferences.copyWith(
                          uploadFormat: SyncUploadFormat.originalFile,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _selectionTile(
                      selected:
                          _preferences.uploadFormat ==
                          SyncUploadFormat.compressedMedia,
                      icon: Icons.photo_size_select_small_outlined,
                      title: 'Compressed media',
                      subtitle:
                          'May upload faster, but quality can be reduced.',
                      onTap: () => setState(
                        () => _preferences = _preferences.copyWith(
                          uploadFormat: SyncUploadFormat.compressedMedia,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(18),
              _sectionTitle('Network and power'),
              const Gap(8),
              _surface(
                Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _preferences.wifiOnly,
                      onChanged: (value) => setState(
                        () => _preferences = _preferences.copyWith(
                          wifiOnly: value,
                        ),
                      ),
                      secondary: const Icon(Icons.wifi_rounded),
                      title: const Text('Wi-Fi only'),
                    ),
                    SwitchListTile.adaptive(
                      value: _preferences.chargingOnly,
                      onChanged: (value) => setState(
                        () => _preferences = _preferences.copyWith(
                          chargingOnly: value,
                        ),
                      ),
                      secondary: const Icon(Icons.battery_charging_full),
                      title: const Text('Only while charging'),
                    ),
                  ],
                ),
              ),
              const Gap(18),
              _sectionTitle('Album scope'),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SyncAlbumMode.values.map((mode) {
                  return ChoiceChip(
                    label: Text(_albumModeLabel(mode)),
                    selected: _preferences.albumMode == mode,
                    onSelected: (_) => setState(
                      () =>
                          _preferences = _preferences.copyWith(albumMode: mode),
                    ),
                  );
                }).toList(),
              ),
              if (_preferences.albumMode != SyncAlbumMode.all) ...[
                const Gap(10),
                if (widget.albums.isEmpty)
                  const Text(
                    'No albums are currently available.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  )
                else
                  _surface(
                    Column(
                      children: widget.albums.map((album) {
                        final selected = _preferences.albumIds.contains(
                          album.id,
                        );
                        return CheckboxListTile(
                          dense: true,
                          value: selected,
                          title: Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (value) {
                            final ids = Set<String>.from(_preferences.albumIds);
                            if (value == true) {
                              ids.add(album.id);
                            } else {
                              ids.remove(album.id);
                            }
                            setState(
                              () => _preferences = _preferences.copyWith(
                                albumIds: ids,
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                if (noSelectedAlbums)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Select at least one album to auto-sync media.',
                      style: TextStyle(color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
              ],
              const Gap(18),
              _sectionTitle('Maximum file size'),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sizeChip(100, '100 MB'),
                  _sizeChip(500, '500 MB'),
                  _sizeChip(1024, '1 GB'),
                  _sizeChip(defaultSyncMaxFileSizeMb, '< 2 GB'),
                  _sizeChip(
                    telegramPremiumMaxFileSizeMb,
                    '4 GB',
                    premiumOnly: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: noSelectedAlbums ? null : _submit,
                icon: const Icon(Icons.cloud_done_outlined),
                label: const Text('Create bucket'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mediaChip({
    required BucketMediaType type,
    required String label,
    required IconData icon,
  }) {
    final selected = _allowedTypes.contains(type);
    return FilterChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        final next = Set<BucketMediaType>.from(_allowedTypes);
        if (value) {
          next.add(type);
        } else if (next.length > 1) {
          next.remove(type);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one media type')),
          );
          return;
        }
        setState(() => _allowedTypes = next);
      },
    );
  }

  Widget _sizeChip(int value, String label, {bool premiumOnly = false}) {
    final locked = premiumOnly && !widget.isTelegramPremium;
    return ChoiceChip(
      avatar: locked ? const Icon(Icons.lock_outline, size: 16) : null,
      label: Text(label),
      selected: _preferences.maxFileSizeMb == value,
      onSelected: (_) {
        if (locked) {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Telegram Premium required'),
              content: const Text(
                'Telegram allows files up to 4 GB for Premium accounts. '
                'TeleVault keeps the limit below 2 GB for other accounts.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
          return;
        }
        setState(
          () => _preferences = _preferences.copyWith(maxFileSizeMb: value),
        );
      },
    );
  }

  Widget _selectionTile({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.check_circle_rounded : icon,
        color: selected ? AppTheme.success : AppTheme.inkMuted,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _surface(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }

  String _albumModeLabel(SyncAlbumMode mode) {
    return switch (mode) {
      SyncAlbumMode.all => 'All albums',
      SyncAlbumMode.include => 'Only selected',
      SyncAlbumMode.exclude => 'Except selected',
    };
  }

  void _submit() {
    final preferences = _preferences.copyWith(
      includePhotos: _allowedTypes.contains(BucketMediaType.photo),
      includeVideos: _allowedTypes.contains(BucketMediaType.video),
    );
    Navigator.of(context).pop(
      BucketCreationConfiguration(
        allowedTypes: Set.unmodifiable(_allowedTypes),
        preferences: preferences,
      ),
    );
  }
}

class _UnavailableTypeChip extends StatelessWidget {
  final String label;

  const _UnavailableTypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.lock_clock_outlined, size: 16),
      label: Text(label),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This media type will be available in a future release.',
            ),
          ),
        );
      },
    );
  }
}
