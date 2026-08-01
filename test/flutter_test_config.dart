import 'dart:async';

import 'package:tele_vault/src/core/config/app_runtime_environment.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppRuntimeEnvironment.configure(AppRuntimeMode.production);
  await testMain();
}
