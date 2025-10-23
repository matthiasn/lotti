import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';

class TimeRecordingIndicator extends ConsumerWidget {
  const TimeRecordingIndicator({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeService = getIt<TimeService>();

    return StreamBuilder(
      stream: timeService.getStream(),
      builder: (
        _,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final current = snapshot.data;

        if (current == null) {
          return const SizedBox.shrink();
        }

        final durationString = formatDuration(entryDuration(current));
        final backgroundColor = context.colorScheme.surface;

        const borderRadius = BorderRadius.only(
          topRight: Radius.circular(inputBorderRadius),
          topLeft: Radius.circular(inputBorderRadius),
        );

        final borderSide = BorderSide(
          color: context.colorScheme.error.withAlpha(128),
        );

        return GestureDetector(
          onTap: () {
            final linkedFrom = timeService.linkedFrom;
            if (linkedFrom != null) {
              if (linkedFrom is Task) {
                // Publish focus intent for task-linked timers
                publishTaskFocus(
                  taskId: linkedFrom.meta.id,
                  entryId: current.meta.id,
                  ref: ref,
                );
                beamToNamed('/tasks/${linkedFrom.meta.id}');
              } else {
                // Journal-linked timer - no focus intent needed
                beamToNamed('/journal/${linkedFrom.meta.id}');
              }
            } else {
              // Timer not linked to task - navigate to journal entry
              beamToNamed('/journal/${current.meta.id}');
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              elevation: 5,
              borderRadius: borderRadius,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: backgroundColor,
                  border: Border(
                    top: borderSide,
                    right: borderSide,
                    left: borderSide,
                  ),
                ),
                height: AudioRecordingIndicatorConstants.indicatorHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const TimeRecordingIndicatorDot(),
                    const SizedBox(width: 5),
                    Padding(
                      padding: AudioRecordingIndicatorConstants.textPadding,
                      child: Text(
                        durationString,
                        style: monoTabularStyle(
                          fontSize: fontSizeMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
