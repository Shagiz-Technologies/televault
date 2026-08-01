import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/presentation/responsive_layout.dart';
import '../../../core/services/diagnostics_service.dart';
import '../../../core/theme/app_theme.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(diagnosticsServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(title: const Text('Diagnostics')),
      body: StreamBuilder<Map<String, int>>(
        stream: diagnostics.watchMetrics(),
        builder: (context, snapshot) {
          final metrics =
              snapshot.data ??
              const {
                DiagnosticsService.uploadSuccessKey: 0,
                DiagnosticsService.uploadFailureKey: 0,
                DiagnosticsService.retryCountKey: 0,
                DiagnosticsService.authFailureKey: 0,
                DiagnosticsService.syncManualRunKey: 0,
              };

          return ListView(
            padding: AppResponsive.pagePaddingWithBottomSafe(
              context,
              horizontal: 16,
              top: 16,
              bottomExtra: 18,
            ),
            children: [
              const Text(
                'Operational counters only. No media content is collected.',
                style: TextStyle(color: AppTheme.inkMuted),
              ),
              const Gap(16),
              _metricTile(
                'Uploads Succeeded',
                metrics[DiagnosticsService.uploadSuccessKey] ?? 0,
                Colors.green,
              ),
              const Gap(8),
              _metricTile(
                'Uploads Failed',
                metrics[DiagnosticsService.uploadFailureKey] ?? 0,
                Colors.redAccent,
              ),
              const Gap(8),
              _metricTile(
                'Retry Attempts',
                metrics[DiagnosticsService.retryCountKey] ?? 0,
                Colors.orange,
              ),
              const Gap(8),
              _metricTile(
                'Auth Failures',
                metrics[DiagnosticsService.authFailureKey] ?? 0,
                Colors.amber,
              ),
              const Gap(8),
              _metricTile(
                'Manual Sync Runs',
                metrics[DiagnosticsService.syncManualRunKey] ?? 0,
                AppTheme.primary,
              ),
              const Gap(28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await diagnostics.resetMetrics();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostics counters reset'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Reset Counters'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricTile(String title, int value, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: accent.withValues(alpha: 0.2),
          child: Icon(Icons.analytics_outlined, size: 16, color: accent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.bold, color: accent),
        ),
      ),
    );
  }
}
