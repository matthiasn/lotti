import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';

class LinkedDuration extends StatelessWidget {
  final JournalDb db = getIt<JournalDb>();
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
        stream: db.watchLinkedTotalDuration(linkedFrom: task.meta.id),
        builder: (_, AsyncSnapshot<Duration> snapshot) {
          Duration progress = snapshot.data ?? const Duration();
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
        });
  }
}
