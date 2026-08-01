import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/features/vault/services/vault_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await VaultService.cleanupDefaultTemporaryFiles();
  } on Object {
    // Vault operations also clean their own partial files before use.
  }

  runZonedGuarded(
    () {
      runApp(const ProviderScope(child: TeleVaultApp()));
    },
    (_, _) {
      debugPrint('Unhandled application error.');
    },
  );
}
