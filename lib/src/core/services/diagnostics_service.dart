import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

final diagnosticsServiceProvider = Provider<DiagnosticsService>((ref) {
  return DiagnosticsService(ref.watch(databaseProvider));
});

class DiagnosticsService {
  static const enabledKey = 'diagnostics_enabled';
  static const uploadSuccessKey = 'diag_upload_success';
  static const uploadFailureKey = 'diag_upload_failure';
  static const retryCountKey = 'diag_retry_count';
  static const authFailureKey = 'diag_auth_failure';
  static const syncManualRunKey = 'diag_sync_manual_runs';

  final _supportedKeys = const {
    uploadSuccessKey,
    uploadFailureKey,
    retryCountKey,
    authFailureKey,
    syncManualRunKey,
  };

  final AppDatabase _db;

  DiagnosticsService(this._db);

  Future<void> increment(String metricKey, {int by = 1}) async {
    if (!_supportedKeys.contains(metricKey) || by <= 0) return;
    if (!await _isEnabled()) return;

    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(metricKey))).getSingleOrNull();
    final current = int.tryParse(row?.value ?? '0') ?? 0;
    final next = current + by;
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: metricKey, value: '$next'),
        );
  }

  Stream<Map<String, int>> watchMetrics() {
    return (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(_supportedKeys.toList()))).watch().map((rows) {
      final map = <String, int>{for (final key in _supportedKeys) key: 0};
      for (final row in rows) {
        map[row.key] = int.tryParse(row.value) ?? 0;
      }
      return map;
    });
  }

  Future<Map<String, int>> getMetrics() async {
    final rows = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(_supportedKeys.toList()))).get();
    final map = <String, int>{for (final key in _supportedKeys) key: 0};
    for (final row in rows) {
      map[row.key] = int.tryParse(row.value) ?? 0;
    }
    return map;
  }

  Future<void> resetMetrics() async {
    await (_db.delete(
      _db.appSettings,
    )..where((t) => t.key.isIn(_supportedKeys.toList()))).go();
  }

  Future<bool> _isEnabled() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(enabledKey))).getSingleOrNull();
    return (row?.value ?? 'false') == 'true';
  }
}
