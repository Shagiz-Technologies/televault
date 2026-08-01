import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/app_runtime_environment.dart';
import 'package:tele_vault/src/core/config/runtime_environment_store.dart';
import 'package:tele_vault/src/core/services/review_environment_exit_service.dart';

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

  test('review mode is selected before service initialization', () async {
    final events = <String>[];
    final store = _MemoryRuntimeEnvironmentStore(
      onWrite: (mode) {
        events.add('stored:${mode.wireName}');
      },
    );
    final bootstrapper = RuntimeEnvironmentBootstrapper(store);

    await bootstrapper.activate(
      AppRuntimeMode.playReview,
      initializeServices: () async {
        events.add('initialized:${AppRuntimeEnvironment.current.name}');
      },
    );

    expect(events, ['stored:play_review', 'initialized:play_review']);
    expect(AppRuntimeEnvironment.isPlayStoreReview, isTrue);
  });

  test('returning to production clears only review state', () async {
    AppRuntimeEnvironment.configure(AppRuntimeMode.playReview);
    final productionData = <String, String>{'session': 'keep'};
    final reviewData = <String, String>{'session': 'remove'};
    final events = <String>[];
    final service = ReviewEnvironmentExitService(
      cleanupReviewEnvironment: () async {
        events.add('cleanup:${AppRuntimeEnvironment.current.name}');
        reviewData.clear();
      },
      disposeTelegram: () async => events.add('dispose-review'),
      activateProduction: () async {
        AppRuntimeEnvironment.resetAfterRuntimeShutdown();
        AppRuntimeEnvironment.configure(AppRuntimeMode.production);
        events.add('activate:${AppRuntimeEnvironment.current.name}');
      },
    );

    await service.returnToProduction();

    expect(reviewData, isEmpty);
    expect(productionData, {'session': 'keep'});
    expect(events, [
      'cleanup:play_review',
      'dispose-review',
      'activate:production',
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
