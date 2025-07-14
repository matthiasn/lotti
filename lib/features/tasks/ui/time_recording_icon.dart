import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';

class TimeRecordingIcon extends StatelessWidget {
  const TimeRecordingIcon({
    required this.taskId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String taskId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final timeService = getIt<TimeService>();

    return StreamBuilder(
      stream: timeService.getStream(),
      builder: (
        _,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        if (timeService.linkedFrom?.id != taskId) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: padding,
          child: ColorIcon(
            context.colorScheme.error,
            size: 12,
          ),
        );
      },
    );
  }
}

class TimeRecordingIndicatorDot extends StatelessWidget {
  const TimeRecordingIndicatorDot({
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return ColorIcon(
      context.colorScheme.error,
      size: 12,
    );
  }
}
