import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_error.dart';
import 'package:tele_vault/src/core/services/telegram_reliability_service.dart';
import 'package:tele_vault/src/features/backup/services/auto_metadata_backup_service.dart';
import 'package:tele_vault/src/features/backup/services/metadata_backup_service.dart';

import 'support/fake_telegram_gateway.dart';

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

  test('metadata upload uses the shared typed flood-wait path', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = FakeTelegramGateway();
    final reliability = TelegramReliabilityService(
      db,
      gateway,
      jitter: () => Duration.zero,
      autoInitialize: false,
    );
    await reliability.initialize();
    final exporter = _FakeMetadataBackupService();
    final service = AutoMetadataBackupService(
      db,
      gateway,
      exporter,
      reliability,
    );
    addTearDown(() async {
      await service.dispose();
      await reliability.dispose();
      await gateway.dispose();
      await db.close();
    });
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'metadata_default_channel_chat_id',
            value: '9001',
          ),
        );
    gateway.handler = (request) {
      if (request['@type'] == 'getChat') {
        return {'@type': 'chat', 'id': request['chat_id']};
      }
      if (request['@type'] == 'sendMessage') {
        return {
          '@type': 'error',
          'code': 429,
          'message': 'FLOOD_PREMIUM_WAIT_120',
        };
      }
      throw UnimplementedError('Unexpected request: ${request['@type']}');
    };

    await expectLater(
      service.backupNow(reason: 'test'),
      throwsA(
        isA<TelegramError>()
            .having(
              (error) => error.category,
              'category',
              TelegramErrorCategory.exactWait,
            )
            .having(
              (error) => error.isPremiumFloodWait,
              'premium wait',
              isTrue,
            ),
      ),
    );

    expect(reliability.currentState.isBlockedAt(DateTime.now()), isTrue);
    expect(gateway.requestCount('preliminaryUploadFile'), 0);
    final send = gateway.requests.singleWhere(
      (request) => request['@type'] == 'sendMessage',
    );
    final content = send['input_message_content'] as Map<String, dynamic>;
    final document = content['document'] as Map<String, dynamic>;
    expect(document['@type'], 'inputFileLocal');
  });
}

class _FakeMetadataBackupService implements MetadataBackupService {
  @override
  Future<io.File> exportAccountBoundSnapshot() async {
    final directory = await io.Directory.systemTemp.createTemp(
      'televault_metadata_test_',
    );
    final file = io.File('${directory.path}/snapshot.tvmeta');
    await file.writeAsBytes([1, 2, 3]);
    return file;
  }

  @override
  Future<io.File> exportEncryptedSnapshot({required String passphrase}) {
    throw UnimplementedError();
  }

  @override
  Future<void> importAccountBoundSnapshot(io.File snapshot) {
    throw UnimplementedError();
  }

  @override
  Future<void> importEncryptedSnapshot(
    io.File snapshot, {
    required String passphrase,
  }) {
    throw UnimplementedError();
  }
}
