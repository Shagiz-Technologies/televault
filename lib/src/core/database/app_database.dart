import 'dart:io' as io;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

// Import the generated code (this file doesn't exist yet, we will generate it next)
part 'app_database.g.dart';

@DriftDatabase(tables: [Buckets, Files, Labels, AppSettings])
class AppDatabase extends _$AppDatabase {
  // We tell the database where to store the file
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createPerformanceIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // We added the 'assetId' column in version 2
        await m.addColumn(files, files.assetId);
      }
      if (from < 3) {
        await m.addColumn(files, files.retryCount);
        await m.addColumn(files, files.lastError);
        await m.addColumn(files, files.nextRetryAt);
        await m.addColumn(files, files.lastAttemptAt);
      }
      if (from < 4) {
        await m.addColumn(files, files.isEncrypted);
        await m.addColumn(files, files.encryptionVersion);
        await m.addColumn(files, files.ivB64);
      }
      if (from < 5) {
        await m.addColumn(files, files.deletedLocallyAt);
      }
      if (from < 6) {
        await m.addColumn(buckets, buckets.allowedMediaTypes);
        await m.createTable(labels);
      }
      if (from < 7) {
        await m.addColumn(files, files.labelId);
      }
      await _createPerformanceIndexes();
    },
  );

  Future<void> _createPerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_files_status_date_added ON files (status, date_added)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_files_bucket_status ON files (bucket_id, status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_files_asset_bucket ON files (asset_id, bucket_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_files_is_vaulted_status ON files (is_vaulted, status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_files_label_status ON files (label_id, status)',
    );
  }
}

// Helper function to open the connection securely
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Put the database file, called db.sqlite, in the documents folder
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = io.File(p.join(dbFolder.path, 'tele_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
