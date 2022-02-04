import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class LinkedDuration extends StatelessWidget {
  final JournalDb db = getIt<JournalDb>();
  final TimeService _timeService = getIt<TimeService>();

  late final Stream<JournalEntity?> stream = db.watchEntityById(task.meta.id);

  final Task task;
  final double width;

  LinkedDuration({
    required this.task,
    required this.width,
    Key? key,
  }) : super(key: key);

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
                Map<String, Duration> durations = snapshot.data ?? {};
                JournalEntity liveTask = taskSnapshot.data ?? task;
                durations[liveTask.meta.id] = entryDuration(liveTask);
                JournalEntity? running = timeSnapshot.data;

                if (running != null && durations.containsKey(running.meta.id)) {
                  durations[running.meta.id] = entryDuration(running);
                }

                Duration progress = const Duration();
                for (Duration duration in durations.values) {
                  progress = progress + duration;
                }

                Duration total = task.data.estimate ?? const Duration();

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    width: width,
                    child: ProgressBar(
                      progress: progress,
                      total: total,
                      progressBarColor:
                          (progress >= total) ? Colors.red : Colors.green,
                      thumbColor: Colors.white,
                      barHeight: 8.0,
                      thumbRadius: 8.0,
                      onSeek: (newPosition) {},
                      timeLabelTextStyle: TextStyle(
                        fontFamily: 'Oswald',
                        color: AppColors.entryTextColor,
                        fontWeight: FontWeight.normal,
                        fontSize: 14.0,
                      ),
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
