import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class LinkedDuration extends StatelessWidget {
  LinkedDuration({
    required this.task,
    super.key,
  });

  final JournalDb db = getIt<JournalDb>();
  final TimeService _timeService = getIt<TimeService>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(task.meta.id);
  final Task task;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: db.watchEntityById(task.meta.id),
      builder: (_, AsyncSnapshot<JournalEntity?> taskSnapshot) {
        return StreamBuilder(
          stream: db.watchLinkedTotalDuration(linkedFrom: task.meta.id),
          builder: (_, AsyncSnapshot<Map<String, Duration>> snapshot) {
            return StreamBuilder(
              stream: _timeService.getStream(),
              builder: (_, AsyncSnapshot<JournalEntity?> timeSnapshot) {
                final durations = snapshot.data ?? <String, Duration>{};
                final liveEntity = taskSnapshot.data ?? task;
                final liveTask = liveEntity as Task;
                durations[liveTask.meta.id] = entryDuration(liveTask);
                final running = timeSnapshot.data;

                if (running != null && durations.containsKey(running.meta.id)) {
                  durations[running.meta.id] = entryDuration(running);
                }

                var progress = Duration.zero;
                for (final duration in durations.values) {
                  progress = progress + duration;
                }

                final estimate = liveTask.data.estimate ?? Duration.zero;

                if (liveTask.data.estimate == Duration.zero) {
                  return const SizedBox.shrink();
                }

                final durationStyle = monospaceTextStyleSmall().copyWith(
                  color: (progress > estimate)
                      ? styleConfig().alarm
                      : styleConfig().secondaryTextColor,
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          minHeight: 4,
                          value:
                              min(progress.inSeconds / estimate.inSeconds, 1),
                          color: (progress > estimate)
                              ? styleConfig().alarm
                              : styleConfig().primaryColor,
                          backgroundColor:
                              styleConfig().secondaryTextColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(progress),
                              style: durationStyle,
                            ),
                            Text(
                              formatDuration(estimate),
                              style: durationStyle,
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
