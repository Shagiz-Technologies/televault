import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/features/backup/services/metadata_backup_service.dart';

void main() {
  group('MetadataSettingPolicy', () {
    test('allows global and bucket scoped sync preference keys', () {
      expect(MetadataSettingPolicy.isSafeSettingKey('auto_backup'), isTrue);
      expect(
        MetadataSettingPolicy.isSafeSettingKey('sync_upload_format'),
        isTrue,
      );
      expect(
        MetadataSettingPolicy.isSafeSettingKey('bucket.2.auto_backup'),
        isTrue,
      );
      expect(
        MetadataSettingPolicy.isSafeSettingKey('bucket.3.sync_album_ids'),
        isTrue,
      );
    });

    test('rejects secret or malformed settings keys', () {
      expect(MetadataSettingPolicy.isSafeSettingKey('vault_pin_hash'), isFalse);
      expect(
        MetadataSettingPolicy.isSafeSettingKey('app_lock_secret'),
        isFalse,
      );
      expect(
        MetadataSettingPolicy.isSafeSettingKey('bucket.2.vault_pin_hash'),
        isFalse,
      );
      expect(
        MetadataSettingPolicy.isSafeSettingKey('bucket.two.auto_backup'),
        isFalse,
      );
    });

    test('remaps bucket scoped settings during import', () {
      final bucketIdMap = {2: 12};

      expect(
        MetadataSettingPolicy.normalizeImportedSettingKey(
          'bucket.2.sync_upload_format',
          bucketIdMap,
        ),
        'bucket.12.sync_upload_format',
      );
      expect(
        MetadataSettingPolicy.normalizeImportedSettingKey(
          'sync_max_file_size_mb',
          bucketIdMap,
        ),
        'sync_max_file_size_mb',
      );
      expect(
        MetadataSettingPolicy.normalizeImportedSettingKey(
          'bucket.3.sync_upload_format',
          bucketIdMap,
        ),
        isNull,
      );
      expect(
        MetadataSettingPolicy.normalizeImportedSettingKey(
          'bucket.2.vault_pin_hash',
          bucketIdMap,
        ),
        isNull,
      );
    });
  });
}
