import 'dart:async';

import 'package:flutter/material.dart';

import 'src/core/presentation/runtime_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(
    () {
      runApp(const TeleVaultRuntimeBootstrap());
    },
    (_, _) {
      debugPrint('Unhandled application error.');
    },
  );
}
