import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/app_runtime_environment.dart';
import 'package:tele_vault/src/core/database/app_database.dart';
import 'package:tele_vault/src/core/services/telegram_service.dart';
import 'package:tele_vault/src/features/reviewer_demo/presentation/reviewer_demo_app.dart';
import 'package:tele_vault/src/features/reviewer_demo/services/reviewer_demo_cleanup_service.dart';
import 'package:tele_vault/src/features/reviewer_demo/services/reviewer_demo_controller.dart';
import 'package:tele_vault/src/features/reviewer_demo/services/reviewer_demo_gateway.dart';
import 'package:tele_vault/src/features/reviewer_demo/services/reviewer_demo_system_bridge.dart';
import 'package:tele_vault/src/features/vault/services/vault_recovery_service.dart';

void main() {
  setUp(() {
    AppRuntimeEnvironment.resetForTesting();
    AppRuntimeEnvironment.configure(AppRuntimeMode.reviewerDemo);
  });

  tearDown(AppRuntimeEnvironment.resetForTesting);

  test('reviewer demo does not initialize TDLib', () async {
    final telegram = TelegramService();

    expect(telegram.isAvailable, isFalse);
    expect(telegram.unavailableReason, contains('disabled'));
    await telegram.dispose();
  });

  test(
    'fake gateway labels operations simulated and blocks network calls',
    () async {
      final gateway = ReviewerDemoGateway();

      final result = await gateway.simulateUpload();
      expect(result.simulated, isTrue);
      expect(result.operationId, startsWith('reviewer-demo-'));
      expect(
        gateway.request({'@type': 'getMe'}),
        throwsA(isA<UnsupportedError>()),
      );
      await gateway.dispose();
    },
  );

  test('sample queue exposes all states and Wi-Fi loss is resumable', () async {
    final fixture = _DemoFixture();
    await fixture.controller.initialize();

    expect(fixture.controller.pendingCount, greaterThan(0));
    expect(fixture.controller.uploadingCount, greaterThan(0));
    expect(fixture.controller.syncedCount, greaterThan(0));
    expect(fixture.controller.failedCount, greaterThan(0));

    await fixture.controller.setWifiAvailable(false);

    expect(fixture.controller.uploadingCount, 0);
    expect(fixture.controller.pendingCount, greaterThan(1));
    expect(fixture.controller.pauseReason, contains('returned to pending'));
    expect(fixture.controller.busy, isFalse);
    await fixture.close();
  });

  test(
    'active Wi-Fi interruption clears busy and can resume to completion',
    () async {
      final fixture = _DemoFixture();
      await fixture.controller.initialize();
      final syncedBefore = fixture.controller.syncedCount;

      final interruptedUpload = fixture.controller.startSimulatedBackup();
      await _waitUntil(
        () =>
            fixture.controller.busy &&
            fixture.controller.activeUploadProgress > 0,
      );

      await fixture.controller.setWifiAvailable(false);
      await interruptedUpload;

      expect(fixture.controller.busy, isFalse);
      expect(fixture.controller.uploadingCount, 0);
      expect(fixture.controller.pendingCount, greaterThan(0));
      expect(fixture.controller.pauseReason, contains('returned to pending'));
      expect(fixture.systemBridge.starts, 1);
      expect(fixture.systemBridge.updates, greaterThan(0));
      expect(fixture.systemBridge.stops, greaterThanOrEqualTo(1));

      await fixture.controller.setWifiAvailable(true);
      await fixture.controller.startSimulatedBackup();

      expect(fixture.controller.busy, isFalse);
      expect(fixture.controller.syncedCount, syncedBefore + 1);
      expect(fixture.controller.uploadingCount, 0);
      expect(fixture.systemBridge.starts, 2);
      expect(fixture.systemBridge.stops, greaterThanOrEqualTo(2));
      await fixture.close();
    },
  );

  testWidgets('reviewer UI persistently identifies all uploads as simulated', (
    tester,
  ) async {
    final fixture = _DemoFixture();
    await tester.pumpWidget(
      ReviewerDemoApp(controller: fixture.controller, onExitDemo: () async {}),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('REVIEWER DEMO — NO DATA IS SENT TO TELEGRAM'),
      findsOneWidget,
    );
    expect(find.textContaining('simulated'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for Reviewer Demo state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _DemoFixture {
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  final _MemorySecretStore secrets = _MemorySecretStore();
  final _RecordingDemoSystemBridge systemBridge = _RecordingDemoSystemBridge();
  late final ReviewerDemoController controller;

  _DemoFixture() {
    controller = ReviewerDemoController(
      appDatabase: database,
      recoveryService: VaultRecoveryService(
        store: secrets,
        randomBytes: (length) =>
            Uint8List.fromList(List<int>.generate(length, (index) => index)),
      ),
      cleanupService: ReviewerDemoCleanupService(
        cancelDemoWork: () async {},
        clearDemoSecrets: () async => secrets.values.clear(),
        deleteDemoFiles: () async {},
      ),
      systemBridge: systemBridge,
    );
  }

  Future<void> close() => controller.clearAndClose();
}

class _RecordingDemoSystemBridge implements ReviewerDemoSystemBridge {
  int permissionRequests = 0;
  int starts = 0;
  int updates = 0;
  int stops = 0;
  final List<String> cancelledNamespaces = [];

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<void> start({
    required int pending,
    required int uploading,
    required int completed,
    required int failed,
    required int total,
    required double progress,
  }) async {
    starts += 1;
  }

  @override
  Future<void> update({
    required int pending,
    required int uploading,
    required int completed,
    required int failed,
    required int total,
    required double progress,
  }) async {
    updates += 1;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  @override
  Future<void> cancelPersistentWork(String namespace) async {
    cancelledNamespaces.add(namespace);
  }
}

class _MemorySecretStore implements VaultSecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
