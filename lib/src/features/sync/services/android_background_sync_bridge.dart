import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sync_status_service.dart';

class AndroidBackgroundSyncBridge {
  static const _channel = MethodChannel('et.shagiz.tele_vault/background_sync');
  Future<void> Function()? _syncWakeHandler;

  void setSyncWakeHandler(Future<void> Function() handler) {
    _syncWakeHandler = handler;
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(_handleNativeMethod);
  }

  void clearSyncWakeHandler() {
    _syncWakeHandler = null;
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(null);
  }

  Future<Object?> _handleNativeMethod(MethodCall call) async {
    if (call.method != 'wakeSync') {
      throw MissingPluginException('Unknown background sync method');
    }
    final handler = _syncWakeHandler;
    if (handler == null) return false;
    unawaited(
      handler().catchError((Object _, StackTrace _) {
        debugPrint('Native background sync wake failed.');
      }),
    );
    return true;
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  Future<void> start(SyncStatusSnapshot status, {String? pauseReason}) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'start',
      _payload(status, pauseReason: pauseReason),
    );
  }

  Future<void> update(SyncStatusSnapshot status, {String? pauseReason}) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'update',
      _payload(status, pauseReason: pauseReason),
    );
  }

  Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isRunning') ?? false;
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }

  Map<String, Object> _payload(
    SyncStatusSnapshot status, {
    String? pauseReason,
  }) {
    final percent = (status.activeUploadProgress * 100).round();
    final isPaused =
        pauseReason != null &&
        status.uploadingCount == 0 &&
        status.pendingCount > 0;
    final detailPrefix = isPaused ? '$pauseReason\n' : '';
    final title = status.uploadingCount > 0
        ? 'Backing up ${status.uploadingCount} file'
              '${status.uploadingCount == 1 ? '' : 's'}'
        : isPaused
        ? 'Backup paused'
        : status.pendingCount > 0
        ? '${status.pendingCount} file'
              '${status.pendingCount == 1 ? '' : 's'} waiting'
        : status.failedCount > 0
        ? '${status.failedCount} upload'
              '${status.failedCount == 1 ? '' : 's'} need attention'
        : 'Backup is up to date';
    final progressText = status.uploadingCount > 0 ? ' - $percent%' : '';

    return {
      'title': title,
      'text':
          '${status.completedCount}/${status.totalCount} complete'
          ' - ${status.failedCount} failed$progressText',
      'detail':
          '$detailPrefix${formatSyncBytes(status.transferredBytes)} of '
          '${formatSyncBytes(status.totalBytes)} backed up',
      'pending': status.pendingCount,
      'uploading': status.uploadingCount,
      'completed': status.completedCount,
      'failed': status.failedCount,
      'total': status.totalCount,
      'progress': (status.overallProgress * 1000).round(),
      'progressMax': 1000,
    };
  }
}
