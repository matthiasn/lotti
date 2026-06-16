import 'package:flutter/material.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';

/// Red dot shown only while the task identified by [taskId] is the one
/// currently being time-tracked.
///
/// Listens to `TimeService` and compares the active recording's linked task
/// id against [taskId]; renders a small error-coloured [ColorIcon] (with the
/// given [padding]) when they match and an empty box otherwise.
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

    return StreamBuilder<String?>(
      initialData: timeService.linkedFrom?.meta.id,
      stream: timeService
          .getStream()
          .map((_) => timeService.linkedFrom?.meta.id)
          .distinct(),
      builder:
          (
            _,
            AsyncSnapshot<String?> snapshot,
          ) {
            if (snapshot.data != taskId) {
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

/// Standalone, always-visible red dot (an error-coloured [ColorIcon]) marking
/// active time recording, for callers that have already determined the task is
/// being tracked and don't need the `TimeService` check in [TimeRecordingIcon].
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
