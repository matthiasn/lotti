import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/duration_bottom_sheet.dart';

class EstimatedTimeWidget extends ConsumerWidget {
  const EstimatedTimeWidget({
    required this.task,
    required this.save,
    super.key,
  });

  final Task task;
  final Future<void> Function({Duration? estimate, bool stopRecording}) save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = task.data.estimate ?? Duration.zero;
    final formattedEstimate = formatDuration(estimate).substring(0, 5);

    Future<void> onTap() async {
      final duration = await showModalBottomSheet<Duration>(
        context: context,
        builder: (context) {
          return DurationBottomSheet(estimate);
        },
      );

      if (duration != null) {
        await save(estimate: duration);
      }
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.taskEstimateLabel,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(formattedEstimate, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}
