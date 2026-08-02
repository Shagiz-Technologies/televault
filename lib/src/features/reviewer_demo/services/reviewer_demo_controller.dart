import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_runtime_environment.dart';
import '../../../core/database/app_database.dart' as database;
import '../../vault/services/vault_recovery_service.dart';
import '../../vault/services/vault_service.dart';
import 'reviewer_demo_cleanup_service.dart';
import 'reviewer_demo_gateway.dart';

enum ReviewerDemoUploadState { pending, uploading, synced, failed }

class ReviewerDemoMedia {
  final int id;
  final String name;
  final String album;
  final int sizeBytes;
  final bool isVideo;
  final bool isVaulted;
  final ReviewerDemoUploadState state;

  const ReviewerDemoMedia({
    required this.id,
    required this.name,
    required this.album,
    required this.sizeBytes,
    required this.isVideo,
    required this.isVaulted,
    required this.state,
  });
}

class ReviewerDemoBucket {
  final int id;
  final String name;
  final String mediaTypes;
  final bool isActive;

  const ReviewerDemoBucket({
    required this.id,
    required this.name,
    required this.mediaTypes,
    required this.isActive,
  });
}

class ReviewerDemoController extends ChangeNotifier {
  final database.AppDatabase _database;
  final ReviewerDemoGateway gateway;
  final VaultRecoveryService _recoveryService;
  late final VaultService _vaultService;
  final ReviewerDemoCleanupService _cleanupService;

  List<ReviewerDemoMedia> media = const [];
  List<ReviewerDemoBucket> buckets = const [];
  bool initialized = false;
  bool busy = false;
  bool wifiAvailable = true;
  bool recoveryKeyConfirmed = false;
  bool revealRecoveryKey = false;
  bool vaultEncryptionComplete = false;
  double activeUploadProgress = 0;
  String? pauseReason;
  String? notice;
  DateTime? metadataBackedUpAt;
  String? _recoveryKey;
  int _simulationGeneration = 0;
  bool _closed = false;

  ReviewerDemoController({
    database.AppDatabase? appDatabase,
    ReviewerDemoGateway? gateway,
    VaultRecoveryService? recoveryService,
    VaultService? vaultService,
    ReviewerDemoCleanupService? cleanupService,
  }) : _database = appDatabase ?? database.AppDatabase(),
       gateway = gateway ?? ReviewerDemoGateway(),
       _recoveryService = recoveryService ?? VaultRecoveryService(),
       _cleanupService = cleanupService ?? ReviewerDemoCleanupService() {
    _vaultService =
        vaultService ?? VaultService(recoveryKeyProvider: _recoveryService);
  }

  String get recoveryKeyDisplay {
    final key = _recoveryKey;
    if (key == null) return 'Not created';
    if (revealRecoveryKey) return key;
    final suffix = key.length > 8 ? key.substring(key.length - 8) : key;
    return 'TVRK1-••••-••••-$suffix';
  }

  int get pendingCount => media
      .where((item) => item.state == ReviewerDemoUploadState.pending)
      .length;
  int get uploadingCount => media
      .where((item) => item.state == ReviewerDemoUploadState.uploading)
      .length;
  int get syncedCount => media
      .where((item) => item.state == ReviewerDemoUploadState.synced)
      .length;
  int get failedCount => media
      .where((item) => item.state == ReviewerDemoUploadState.failed)
      .length;

  Future<void> initialize() async {
    if (!AppRuntimeEnvironment.isReviewerDemo) {
      throw StateError('Reviewer Demo controller cannot open production data.');
    }
    await _seedIfNeeded();
    await _reload();
    recoveryKeyConfirmed = await _recoveryService.isRecoveryKeyConfirmed();
    initialized = true;
    notifyListeners();
  }

  Future<void> createBucket(String name, Set<String> mediaTypes) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || busy) return;
    busy = true;
    notifyListeners();
    try {
      await _database
          .into(_database.buckets)
          .insert(
            database.BucketsCompanion.insert(
              chatId: BigInt.from(-(900000 + buckets.length)),
              name: trimmed,
              allowedMediaTypes: Value((mediaTypes.toList()..sort()).join(',')),
              isActive: const Value(false),
            ),
          );
      await _reload();
      notice = 'Demo bucket created locally. No Telegram channel was created.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setWifiAvailable(bool available) async {
    wifiAvailable = available;
    if (!available) {
      _simulationGeneration += 1;
      pauseReason = 'Wi-Fi unavailable — simulated upload returned to pending.';
      activeUploadProgress = 0;
      await (_database.update(
        _database.files,
      )..where((table) => table.status.equals(1))).write(
        const database.FilesCompanion(
          status: Value(0),
          lastError: Value('Reviewer Demo: waiting for Wi-Fi'),
        ),
      );
      await _reload();
    } else {
      pauseReason = null;
      notice = 'Demo Wi-Fi restored. Select Resume simulated backup.';
    }
    notifyListeners();
  }

  Future<void> startSimulatedBackup() async {
    if (busy) return;
    if (!wifiAvailable) {
      pauseReason = 'Wi-Fi unavailable — nothing was sent.';
      notifyListeners();
      return;
    }
    final candidate = media.where(
      (item) =>
          item.state == ReviewerDemoUploadState.uploading ||
          item.state == ReviewerDemoUploadState.pending,
    );
    if (candidate.isEmpty) {
      notice = 'No simulated uploads are waiting.';
      notifyListeners();
      return;
    }

    final item = candidate.first;
    final generation = ++_simulationGeneration;
    busy = true;
    pauseReason = null;
    notice = 'Simulated upload started. No data is sent to Telegram.';
    await _updateStatus(item.id, ReviewerDemoUploadState.uploading);
    activeUploadProgress = 0;
    notifyListeners();

    try {
      for (var step = 1; step <= 10; step += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (_closed || generation != _simulationGeneration) return;
        if (!wifiAvailable) {
          await _updateStatus(item.id, ReviewerDemoUploadState.pending);
          activeUploadProgress = 0;
          pauseReason =
              'Wi-Fi unavailable — simulated upload returned to pending.';
          return;
        }
        activeUploadProgress = step / 10;
        notifyListeners();
      }
      final result = await gateway.simulateUpload();
      if (!result.simulated) {
        throw StateError('Reviewer Demo gateway returned a non-demo result.');
      }
      await _updateStatus(item.id, ReviewerDemoUploadState.synced);
      activeUploadProgress = 1;
      notice = 'Simulated upload complete. No Telegram message was created.';
    } finally {
      if (generation == _simulationGeneration) busy = false;
      notifyListeners();
    }
  }

  Future<void> retryFailed() async {
    await (_database.update(
      _database.files,
    )..where((table) => table.status.equals(3))).write(
      const database.FilesCompanion(status: Value(0), lastError: Value(null)),
    );
    await _reload();
    notice = 'Failed demo items returned to the simulated queue.';
    notifyListeners();
  }

  Future<void> simulateMetadataBackup() async {
    metadataBackedUpAt = DateTime.now();
    notice = 'Simulated metadata snapshot updated locally.';
    notifyListeners();
  }

  Future<void> prepareRecoveryKey() async {
    busy = true;
    notifyListeners();
    try {
      _recoveryKey = await _recoveryService.ensureRecoveryKey();
      revealRecoveryKey = true;
      notice = 'Demo Recovery Key created in isolated secure storage.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void setRecoveryKeyVisible(bool visible) {
    revealRecoveryKey = visible;
    notifyListeners();
  }

  Future<void> confirmRecoveryKey() async {
    final key = _recoveryKey;
    if (key == null) return;
    await _recoveryService.confirmRecoveryKey(key);
    recoveryKeyConfirmed = true;
    revealRecoveryKey = false;
    notice = 'Demo Recovery Key confirmed.';
    notifyListeners();
  }

  Future<void> encryptDemoMedia() async {
    if (!recoveryKeyConfirmed || busy) return;
    busy = true;
    notifyListeners();
    io.File? source;
    try {
      final temporary = await getTemporaryDirectory();
      final directory = io.Directory(
        path.join(
          temporary.path,
          AppRuntimeEnvironment.cacheDirectory('reviewer_demo_media'),
        ),
      );
      await directory.create(recursive: true);
      source = io.File(path.join(directory.path, 'sample-photo.demo'));
      await source.writeAsBytes(
        Uint8List.fromList(List<int>.generate(8192, (index) => index % 251)),
        flush: true,
      );
      await _vaultService.encryptFile(
        source,
        mimeType: 'application/x-televault-reviewer-demo',
      );
      vaultEncryptionComplete = true;
      notice = 'Demo media encrypted locally. Nothing was uploaded.';
    } finally {
      final sourceFile = source;
      if (sourceFile != null && await sourceFile.exists()) {
        await sourceFile.delete();
      }
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clearAndClose() async {
    if (_closed) return;
    _closed = true;
    _simulationGeneration += 1;
    await gateway.dispose();
    await _database.close();
    await _cleanupService.clear();
  }

  Future<void> _seedIfNeeded() async {
    final existingBuckets = await _database.select(_database.buckets).get();
    if (existingBuckets.isNotEmpty) return;
    final photosBucket = await _database
        .into(_database.buckets)
        .insert(
          database.BucketsCompanion.insert(
            chatId: BigInt.from(-900001),
            name: 'Demo Photos',
            allowedMediaTypes: const Value('photo'),
            isActive: const Value(true),
          ),
        );
    final videosBucket = await _database
        .into(_database.buckets)
        .insert(
          database.BucketsCompanion.insert(
            chatId: BigInt.from(-900002),
            name: 'Demo Videos',
            allowedMediaTypes: const Value('video'),
          ),
        );
    final samples = [
      ('sunrise.demo.jpg', 'Camera', 3400000, photosBucket, 2, false),
      ('weekend.demo.jpg', 'Favorites', 2800000, photosBucket, 1, false),
      ('notes.demo.jpg', 'Screenshots', 1100000, photosBucket, 0, false),
      ('garden.demo.jpg', 'Camera', 4200000, photosBucket, 3, false),
      ('walk.demo.mp4', 'Videos', 18400000, videosBucket, 2, true),
      ('private.demo.jpg', 'Vault', 2400000, photosBucket, 2, false),
    ];
    for (var index = 0; index < samples.length; index += 1) {
      final sample = samples[index];
      await _database
          .into(_database.files)
          .insert(
            database.FilesCompanion.insert(
              localPath: 'reviewer-demo://${sample.$1}',
              localPathResolved: const Value(false),
              assetId: Value('reviewer-demo-$index'),
              folderName: sample.$2,
              size: sample.$3,
              bucketId: sample.$4,
              status: Value(sample.$5),
              isVaulted: Value(index == samples.length - 1),
              isEncrypted: Value(index == samples.length - 1),
              lastError: sample.$5 == 3
                  ? const Value('Simulated connection interruption')
                  : const Value(null),
            ),
          );
    }
    await _database
        .into(_database.appSettings)
        .insert(
          database.AppSettingsCompanion.insert(
            key: 'reviewer_demo_seed_version',
            value: '1',
          ),
        );
  }

  Future<void> _updateStatus(int id, ReviewerDemoUploadState state) async {
    await (_database.update(_database.files)
          ..where((table) => table.id.equals(id)))
        .write(database.FilesCompanion(status: Value(state.index)));
    await _reload();
  }

  Future<void> _reload() async {
    final bucketRows = await _database.select(_database.buckets).get();
    final fileRows = await _database.select(_database.files).get();
    buckets = bucketRows
        .map(
          (row) => ReviewerDemoBucket(
            id: row.id,
            name: row.name,
            mediaTypes: row.allowedMediaTypes,
            isActive: row.isActive,
          ),
        )
        .toList(growable: false);
    media = fileRows
        .map(
          (row) => ReviewerDemoMedia(
            id: row.id,
            name: row.localPath.replaceFirst('reviewer-demo://', ''),
            album: row.folderName,
            sizeBytes: row.size,
            isVideo: row.localPath.endsWith('.mp4'),
            isVaulted: row.isVaulted,
            state:
                ReviewerDemoUploadState.values[row.status.clamp(0, 3).toInt()],
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _simulationGeneration += 1;
    if (!_closed) {
      _closed = true;
      unawaited(gateway.dispose());
      unawaited(_database.close());
    }
    super.dispose();
  }
}
