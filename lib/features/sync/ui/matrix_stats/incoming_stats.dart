import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/matrix_stats/matrix_metrics_panel.dart';
import 'package:lotti/features/sync/ui/matrix_stats/message_counts_view.dart';

class IncomingStats extends ConsumerStatefulWidget {
  const IncomingStats({super.key});

  @override
  ConsumerState<IncomingStats> createState() => _IncomingStatsState();
}

class _IncomingStatsState extends ConsumerState<IncomingStats> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SingleChildScrollView(
      key: const PageStorageKey('matrixStatsScroll'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RepaintBoundary(child: MessageCountsView()),
          SizedBox(height: tokens.spacing.step5),
          const RepaintBoundary(child: MatrixSyncMetricsPanel()),
        ],
      ),
    );
  }
}
