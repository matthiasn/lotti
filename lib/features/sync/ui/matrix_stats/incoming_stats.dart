import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/ui/matrix_stats/matrix_v2_metrics_panel.dart';
import 'package:lotti/features/sync/ui/matrix_stats/message_counts_view.dart';

class IncomingStats extends ConsumerStatefulWidget {
  const IncomingStats({super.key});

  @override
  ConsumerState<IncomingStats> createState() => _IncomingStatsState();
}

class _IncomingStatsState extends ConsumerState<IncomingStats> {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      key: PageStorageKey('matrixStatsScroll'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(child: MessageCountsView()),
          SizedBox(height: 16),
          RepaintBoundary(child: MatrixV2MetricsPanel()),
        ],
      ),
    );
  }
}
