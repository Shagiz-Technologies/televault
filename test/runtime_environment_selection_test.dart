import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/app_runtime_environment.dart';
import 'package:tele_vault/src/core/config/runtime_environment_store.dart';
import 'package:tele_vault/src/features/reviewer_demo/services/reviewer_demo_cleanup_service.dart';

void main() {
  setUp(AppRuntimeEnvironment.resetForTesting);
  tearDown(() {
    AppRuntimeEnvironment.resetForTesting();
    AppRuntimeEnvironment.configure(AppRuntimeMode.production);
  });

  test('production is the default user choice', () {
    final bootstrapper = RuntimeEnvironmentBootstrapper(
      _MemoryRuntimeEnvironmentStore(),
    );

    expect(bootstrapper.defaultMode, AppRuntimeMode.production);
  });

  test('reviewer demo is selected without service initialization', () async {
    final events = <String>[];
    final store = _MemoryRuntimeEnvironmentStore(
      onWrite: (mode) {
        events.add('stored:${mode.wireName}');
      },
    );
    final bootstrapper = RuntimeEnvironmentBootstrapper(store);

    await bootstrapper.activate(
      AppRuntimeMode.reviewerDemo,
      initializeServices: () async {
        events.add('initialized:${AppRuntimeEnvironment.current.name}');
      },
    );

    expect(events, ['stored:reviewer_demo']);
    expect(AppRuntimeEnvironment.isReviewerDemo, isTrue);
  });

  test('returning to production clears only demo state', () async {
    AppRuntimeEnvironment.configure(AppRuntimeMode.reviewerDemo);
    final productionData = <String, String>{'session': 'keep'};
    final demoData = <String, String>{'session': 'remove'};
    final events = <String>[];
    final service = ReviewerDemoCleanupService(
      cancelDemoWork: () async => events.add('cancel-demo-work'),
      clearDemoSecrets: () async {
        events.add('clear-demo-secrets');
        demoData.clear();
      },
      deleteDemoFiles: () async => events.add('delete-demo-files'),
    );

    await service.clear();

    expect(demoData, isEmpty);
    expect(productionData, {'session': 'keep'});
    expect(events, [
      'cancel-demo-work',
      'clear-demo-secrets',
      'delete-demo-files',
    ]);
  });
}

class _MemoryRuntimeEnvironmentStore implements RuntimeEnvironmentStore {
  AppRuntimeMode? value;
  final void Function(AppRuntimeMode mode)? onWrite;

  _MemoryRuntimeEnvironmentStore({this.onWrite});

  @override
  Future<AppRuntimeMode?> read() async => value;

  @override
  Future<void> write(AppRuntimeMode mode) async {
    value = mode;
    onWrite?.call(mode);
  }
}
