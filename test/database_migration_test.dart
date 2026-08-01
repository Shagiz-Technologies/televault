import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tele_vault/src/core/database/app_database.dart';

void main() {
  test('schema v7 migrates through v11 without data loss', () async {
    final directory = await io.Directory.systemTemp.createTemp(
      'televault_schema_v7_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = io.File('${directory.path}/tele_vault.sqlite');
    final sqlite = sqlite3.open(file.path);
    sqlite.execute('''
      CREATE TABLE files (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        local_path TEXT NOT NULL,
        asset_id TEXT,
        folder_name TEXT NOT NULL,
        file_hash TEXT,
        size INTEGER NOT NULL,
        bucket_id INTEGER NOT NULL,
        telegram_message_id INTEGER,
        telegram_file_id INTEGER,
        status INTEGER NOT NULL DEFAULT 0,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        next_retry_at INTEGER,
        last_attempt_at INTEGER,
        is_vaulted INTEGER NOT NULL DEFAULT 0,
        is_encrypted INTEGER NOT NULL DEFAULT 0,
        encryption_version INTEGER,
        iv_b64 TEXT,
        deleted_locally_at INTEGER,
        label_id INTEGER,
        date_added INTEGER NOT NULL,
        UNIQUE (local_path, bucket_id)
      );
    ''');
    sqlite.execute(
      "INSERT INTO files (local_path, folder_name, size, bucket_id, status, date_added) "
      "VALUES ('demo.jpg.enc', 'Demo', 42, 7, 5, 0);",
    );
    sqlite.execute(
      'UPDATE files SET is_vaulted = 1, is_encrypted = 1, '
      'encryption_version = 2;',
    );
    sqlite.execute('PRAGMA user_version = 7;');
    sqlite.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db.customSelect('''
      SELECT telegram_error_code, telegram_error_category,
             telegram_retry_after, last_telegram_operation,
             user_action_required, vault_format_version,
             encrypted_size, vault_integrity_status,
             vault_migration_status, key_wrapping_version,
             last_verified_at, local_path_resolved,
             remote_state_verified, local_media_access_state
      FROM files
    ''').get();
    final accountTables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'telegram_account_states'",
        )
        .get();

    expect(rows, hasLength(1));
    expect(rows.single.read<int>('user_action_required'), 0);
    expect(rows.single.read<int?>('vault_format_version'), 2);
    expect(rows.single.read<int?>('encrypted_size'), 42);
    expect(rows.single.read<String>('vault_integrity_status'), 'unknown');
    expect(rows.single.read<String>('vault_migration_status'), 'pending');
    expect(rows.single.read<int>('local_path_resolved'), 1);
    expect(rows.single.read<int>('remote_state_verified'), 1);
    expect(rows.single.read<String>('local_media_access_state'), 'available');
    expect(accountTables, hasLength(1));
  });
}
