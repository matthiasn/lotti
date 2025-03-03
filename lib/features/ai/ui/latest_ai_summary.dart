import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/themes/theme.dart';

class LatestAiSummary extends ConsumerWidget {
  const LatestAiSummary({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestSummary = ref
        .watch(
          latestSummaryControllerProvider(id: itemId),
        )
        .valueOrNull;

    if (latestSummary == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          'AI Summary',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colorScheme.outline,
              ),
        ),
        const SizedBox(height: 10),
        EntryDetailsWidget(
          itemId: latestSummary.id,
          popOnDelete: false,
        ),
      ],
    );
  }
}
