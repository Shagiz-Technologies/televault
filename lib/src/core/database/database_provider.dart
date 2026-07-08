import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

// 1. Create the provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();

  // Ensure we close the DB when the app is killed/disposed (though rarely happens for global providers)
  ref.onDispose(() {
    db.close();
  });

  return db;
});
