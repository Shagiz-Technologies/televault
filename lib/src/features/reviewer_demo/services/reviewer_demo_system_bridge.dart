import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/config/app_runtime_environment.dart';

abstract interface class ReviewerDemoSystemBridge {
  Future<bool> requestNotificationPermission();

  Future<void> start({
    required int pending,
    required int uploading,
    required int completed,
    required int failed,
    required int total,
    required double progress,
  });

  Future<void> update({
    required int pending,
    required int uploading,
    required int completed,
    required int failed,
    required int total,
    required double progress,
  });

  Future<void> stop();

  Future<void> cancelPersistentWork(String namespace);
}

class PlatformReviewerDemoSystemBridge implements ReviewerDemoSystemBridge {
  static const _channel = MethodChannel('et.shagiz.tele_vault/background_sync');

  const PlatformReviewerDemoSystemBridge();

  @override
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
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
    if (!Platform.isAndroid) return;
    await requestNotificationPermission();
    await _channel.invokeMethod<void>(
      'start',
      _payload(
        pending: pending,
        uploading: uploading,
        completed: completed,
        failed: failed,
        total: total,
        progress: progress,
      ),
    );
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
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'update',
      _payload(
        pending: pending,
        uploading: uploading,
        completed: completed,
        failed: failed,
        total: total,
        progress: progress,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> cancelPersistentWork(String namespace) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('cancelPersistentWork', {
      'namespace': namespace,
    });
  }

  Map<String, Object> _payload({
    required int pending,
    required int uploading,
    required int completed,
    required int failed,
    required int total,
    required double progress,
  }) {
    final normalizedProgress = progress.clamp(0.0, 1.0);
    final percent = (normalizedProgress * 100).round();
    return {
      'namespace': AppRuntimeEnvironment.workerNamespace,
      'title': 'Reviewer Demo — simulated',
      'text': 'No data sent to Telegram',
      'detail': '$percent% simulated progress',
      'pending': pending,
      'uploading': uploading,
      'completed': completed,
      'failed': failed,
      'total': total,
      'progress': (normalizedProgress * 1000).round(),
      'progressMax': 1000,
    };
  }
}
