import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

enum SyncAlbumMode { all, include, exclude }

enum SyncUploadFormat { originalFile, compressedMedia }

const int defaultSyncMaxFileSizeMb = 1900;
const int telegramFreeMaxFileSizeMb = 1900;
const int telegramPremiumMaxFileSizeMb = 4096;

class SyncPreferences {
  final bool autoBackupEnabled;
  final bool includePhotos;
  final bool includeVideos;
  final bool wifiOnly;
  final bool chargingOnly;
  final SyncAlbumMode albumMode;
  final Set<String> albumIds;
  final int maxFileSizeMb;
  final SyncUploadFormat uploadFormat;
  final bool diagnosticsEnabled;

  const SyncPreferences({
    this.autoBackupEnabled = true,
    this.includePhotos = true,
    this.includeVideos = true,
    this.wifiOnly = false,
    this.chargingOnly = false,
    this.albumMode = SyncAlbumMode.all,
    this.albumIds = const {},
    this.maxFileSizeMb = defaultSyncMaxFileSizeMb,
    this.uploadFormat = SyncUploadFormat.originalFile,
    this.diagnosticsEnabled = false,
  });

  SyncPreferences copyWith({
    bool? autoBackupEnabled,
    bool? includePhotos,
    bool? includeVideos,
    bool? wifiOnly,
    bool? chargingOnly,
    SyncAlbumMode? albumMode,
    Set<String>? albumIds,
    int? maxFileSizeMb,
    SyncUploadFormat? uploadFormat,
    bool? diagnosticsEnabled,
  }) {
    return SyncPreferences(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      includePhotos: includePhotos ?? this.includePhotos,
      includeVideos: includeVideos ?? this.includeVideos,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      chargingOnly: chargingOnly ?? this.chargingOnly,
      albumMode: albumMode ?? this.albumMode,
      albumIds: albumIds ?? this.albumIds,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      uploadFormat: uploadFormat ?? this.uploadFormat,
      diagnosticsEnabled: diagnosticsEnabled ?? this.diagnosticsEnabled,
    );
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(databaseProvider));
});

class SettingsService {
  final AppDatabase _db;

  SettingsService(this._db);

  static const keyAutoBackup = 'auto_backup';
  static const keySyncIncludePhotos = 'sync_include_photos';
  static const keySyncIncludeVideos = 'sync_include_videos';
  static const keySyncWifiOnly = 'sync_wifi_only';
  static const keySyncChargingOnly = 'sync_charging_only';
  static const keySyncAlbumMode = 'sync_album_mode';
  static const keySyncAlbumIds = 'sync_album_ids';
  static const keySyncMaxFileSizeMb = 'sync_max_file_size_mb';
  static const keySyncUploadFormat = 'sync_upload_format';
  static const keyDiagnosticsEnabled = 'diagnostics_enabled';
  static const keyUiTextScale = 'ui_text_scale';
  static const bucketSettingPrefix = 'bucket';

  static const _syncPreferenceKeys = [
    keyAutoBackup,
    keySyncIncludePhotos,
    keySyncIncludeVideos,
    keySyncWifiOnly,
    keySyncChargingOnly,
    keySyncAlbumMode,
    keySyncAlbumIds,
    keySyncMaxFileSizeMb,
    keySyncUploadFormat,
    keyDiagnosticsEnabled,
  ];

  Future<bool> isAutoBackupEnabled({int? bucketId}) async {
    final preferences = await getSyncPreferences(bucketId: bucketId);
    return preferences.autoBackupEnabled;
  }

  Future<void> setAutoBackup(bool enabled, {int? bucketId}) async {
    final preferences = await getSyncPreferences(bucketId: bucketId);
    await saveSyncPreferences(
      preferences.copyWith(autoBackupEnabled: enabled),
      bucketId: bucketId,
    );
  }

  Future<double> getUiTextScale() async {
    final entry = await _get(keyUiTextScale);
    final parsed = double.tryParse(entry ?? '');
    return (parsed ?? 1.0).clamp(0.85, 1.4);
  }

  Stream<double> watchUiTextScale() {
    return (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(keyUiTextScale))).watch().map((rows) {
      if (rows.isEmpty) return 1.0;
      final parsed = double.tryParse(rows.first.value);
      return (parsed ?? 1.0).clamp(0.85, 1.4);
    });
  }

  Future<void> setUiTextScale(double value) async {
    await _upsert(keyUiTextScale, value.clamp(0.85, 1.4).toString());
  }

  Future<SyncPreferences> getSyncPreferences({int? bucketId}) async {
    final globalMap = await _readSettingsMap(_syncPreferenceKeys);
    if (bucketId == null) {
      return _fromMap(globalMap);
    }

    final scopedMap = await _readBucketSettingsMap(bucketId);
    if (scopedMap.isNotEmpty) {
      return _fromMap({...globalMap, ...scopedMap});
    }

    final mainBucketId = await getMainBucketId();
    if (mainBucketId == null || mainBucketId == bucketId) {
      return _fromMap(globalMap);
    }

    final mainScopedMap = await _readBucketSettingsMap(mainBucketId);
    final mainPreferences = _fromMap({...globalMap, ...mainScopedMap});
    return mainPreferences.copyWith(autoBackupEnabled: false);
  }

  Stream<SyncPreferences> watchSyncPreferences({int? bucketId}) {
    final keys = bucketId == null
        ? _syncPreferenceKeys
        : [
            ..._syncPreferenceKeys,
            ..._syncPreferenceKeys.map((key) => _scopedKey(key, bucketId)),
          ];
    return (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(keys))).watch().asyncMap((rows) async {
      final map = <String, String>{for (final row in rows) row.key: row.value};
      if (bucketId == null) {
        return _fromMap(map);
      }
      final globalMap = <String, String>{
        for (final key in _syncPreferenceKeys)
          if (map.containsKey(key)) key: map[key]!,
      };
      final scopedMap = <String, String>{
        for (final key in _syncPreferenceKeys)
          if (map.containsKey(_scopedKey(key, bucketId)))
            key: map[_scopedKey(key, bucketId)]!,
      };
      if (scopedMap.isNotEmpty) {
        return _fromMap({...globalMap, ...scopedMap});
      }
      return getSyncPreferences(bucketId: bucketId);
    });
  }

  Future<void> saveSyncPreferences(
    SyncPreferences preferences, {
    int? bucketId,
  }) async {
    final writeGlobal = bucketId == null || bucketId == await getMainBucketId();
    await _db.transaction(() async {
      await _writeSyncPreferences(preferences, bucketId: bucketId);
      if (writeGlobal && bucketId != null) {
        await _writeSyncPreferences(preferences);
      }
    });
  }

  Future<void> seedBucketSyncPreferences(
    int bucketId,
    SyncPreferences preferences,
  ) async {
    await saveSyncPreferences(preferences, bucketId: bucketId);
  }

  Future<int?> getMainBucketId() async {
    final bucket =
        await (_db.select(_db.buckets)
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return bucket?.id;
  }

  SyncPreferences _fromMap(Map<String, String> map) {
    final albumModeName = map[keySyncAlbumMode] ?? SyncAlbumMode.all.name;
    final albumMode = SyncAlbumMode.values.firstWhere(
      (mode) => mode.name == albumModeName,
      orElse: () => SyncAlbumMode.all,
    );

    final albumIdsRaw = map[keySyncAlbumIds];
    final albumIds = <String>{};
    if (albumIdsRaw != null && albumIdsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(albumIdsRaw) as List<dynamic>;
        albumIds.addAll(decoded.whereType<String>());
      } catch (_) {}
    }

    final maxFileSizeMb = _normalizeMaxFileSizeMb(
      int.tryParse(map[keySyncMaxFileSizeMb] ?? ''),
    );
    final uploadFormatName =
        map[keySyncUploadFormat] ?? SyncUploadFormat.originalFile.name;
    final uploadFormat = SyncUploadFormat.values.firstWhere(
      (format) => format.name == uploadFormatName,
      orElse: () => SyncUploadFormat.originalFile,
    );

    return SyncPreferences(
      autoBackupEnabled: (map[keyAutoBackup] ?? 'true') == 'true',
      includePhotos: (map[keySyncIncludePhotos] ?? 'true') == 'true',
      includeVideos: (map[keySyncIncludeVideos] ?? 'true') == 'true',
      wifiOnly: (map[keySyncWifiOnly] ?? 'false') == 'true',
      chargingOnly: (map[keySyncChargingOnly] ?? 'false') == 'true',
      albumMode: albumMode,
      albumIds: albumIds,
      maxFileSizeMb: maxFileSizeMb,
      uploadFormat: uploadFormat,
      diagnosticsEnabled: (map[keyDiagnosticsEnabled] ?? 'false') == 'true',
    );
  }

  int _normalizeMaxFileSizeMb(int? value) {
    if (value == null || value == 2048) {
      return defaultSyncMaxFileSizeMb;
    }
    return value.clamp(32, telegramPremiumMaxFileSizeMb).toInt();
  }

  Future<void> _writeSyncPreferences(
    SyncPreferences preferences, {
    int? bucketId,
  }) async {
    await _upsert(
      _keyForScope(keyAutoBackup, bucketId),
      preferences.autoBackupEnabled.toString(),
    );
    await _upsert(
      _keyForScope(keySyncIncludePhotos, bucketId),
      preferences.includePhotos.toString(),
    );
    await _upsert(
      _keyForScope(keySyncIncludeVideos, bucketId),
      preferences.includeVideos.toString(),
    );
    await _upsert(
      _keyForScope(keySyncWifiOnly, bucketId),
      preferences.wifiOnly.toString(),
    );
    await _upsert(
      _keyForScope(keySyncChargingOnly, bucketId),
      preferences.chargingOnly.toString(),
    );
    await _upsert(
      _keyForScope(keySyncAlbumMode, bucketId),
      preferences.albumMode.name,
    );
    await _upsert(
      _keyForScope(keySyncAlbumIds, bucketId),
      jsonEncode(preferences.albumIds.toList()),
    );
    await _upsert(
      _keyForScope(keySyncMaxFileSizeMb, bucketId),
      preferences.maxFileSizeMb.toString(),
    );
    await _upsert(
      _keyForScope(keySyncUploadFormat, bucketId),
      preferences.uploadFormat.name,
    );
    await _upsert(
      _keyForScope(keyDiagnosticsEnabled, bucketId),
      preferences.diagnosticsEnabled.toString(),
    );
  }

  Future<Map<String, String>> _readSettingsMap(List<String> keys) async {
    final rows = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(keys))).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<Map<String, String>> _readBucketSettingsMap(int bucketId) async {
    final scopedKeys = _syncPreferenceKeys
        .map((key) => _scopedKey(key, bucketId))
        .toList();
    final rows = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(scopedKeys))).get();
    return {for (final row in rows) _unscopedKey(row.key, bucketId): row.value};
  }

  String _keyForScope(String key, int? bucketId) {
    if (bucketId == null) return key;
    return _scopedKey(key, bucketId);
  }

  String _scopedKey(String key, int bucketId) {
    return '$bucketSettingPrefix.$bucketId.$key';
  }

  String _unscopedKey(String key, int bucketId) {
    final prefix = '$bucketSettingPrefix.$bucketId.';
    return key.startsWith(prefix) ? key.substring(prefix.length) : key;
  }

  Future<void> _upsert(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(key: Value(key), value: Value(value)),
        );
  }

  Future<String?> _get(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
