import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(
    () {
      runApp(const ProviderScope(child: TeleVaultApp()));
    },
    (error, stack) {
      debugPrint('Global error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}
