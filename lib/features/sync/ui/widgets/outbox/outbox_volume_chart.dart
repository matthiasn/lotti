import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';

/// Displays a bar chart of daily outbox sync volume (in KB) over the last
/// 30 days.
class OutboxVolumeChart extends ConsumerWidget {
  const OutboxVolumeChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVolume = ref.watch(outboxDailyVolumeProvider);

    return asyncVolume.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stackTrace) {
        getIt<LoggingService>().captureException(
          error,
          domain: 'OutboxVolumeChart',
          stackTrace: stackTrace,
        );
        return Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Text(
            context.messages.commonError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      },
      data: (observations) {
        if (observations.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final rangeEnd = DateTime(now.year, now.month, now.day + 1);
        final rangeStart = rangeEnd.subtract(const Duration(days: 30));
        final primaryColor = Theme.of(context).colorScheme.primary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppTheme.spacingLarge,
                bottom: AppTheme.spacingSmall,
              ),
              child: Text(
                context.messages.outboxMonitorVolumeChartTitle,
                style: context.textTheme.titleSmall,
              ),
            ),
            SizedBox(
              height: 200,
              child: TimeSeriesBarChart(
                data: observations,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                colorByValue: (_) => primaryColor,
                unit: 'KB',
              ),
            ),
          ],
        );
      },
    );
  }
}
