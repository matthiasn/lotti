import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_header.dart';
import 'package:lotti/widgets/journal/entry_details/habit_summary.dart';
import 'package:lotti/widgets/journal/entry_details/health_summary.dart';
import 'package:lotti/widgets/journal/entry_details/measurement_summary.dart';
import 'package:lotti/widgets/journal/entry_details/survey_summary.dart';
import 'package:lotti/widgets/journal/entry_details/workout_summary.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/tags/tags_list_widget.dart';
import 'package:lotti/widgets/tasks/task_form.dart';

class EntryDetailWidget extends StatelessWidget {
  const EntryDetailWidget({
    required this.itemId,
    required this.popOnDelete,
    super.key,
    this.showTaskDetails = false,
    this.unlinkFn,
    this.parentTags,
  });

  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;
  final Future<void> Function()? unlinkFn;
  final Set<String>? parentTags;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
      stream: getIt<JournalDb>().watchEntityById(itemId),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null || item.meta.deletedAt != null) {
          return const SizedBox.shrink();
        }

        final isTask = item is Task;
        final isAudio = item is JournalAudio;

        if ((isTask || isAudio) && !showTaskDetails) {
          return JournalCard(item: item);
        }

        return BlocProvider<EntryCubit>(
          create: (BuildContext context) => EntryCubit(
            entryId: itemId,
            entry: item,
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  item.maybeMap(
                    journalImage: EntryImageWidget.new,
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const EntryDetailHeader(),
                  TagsListWidget(parentTags: parentTags),
                  item.maybeMap(
                    task: (_) => const SizedBox.shrink(),
                    quantitative: (_) => const SizedBox.shrink(),
                    workout: (_) => const SizedBox.shrink(),
                    orElse: () {
                      return EditorWidget(unlinkFn: unlinkFn);
                    },
                  ),
                  item.map(
                    journalAudio: (JournalAudio audio) {
                      return const AudioPlayerWidget();
                    },
                    workout: WorkoutSummary.new,
                    survey: SurveySummary.new,
                    quantitative: HealthSummary.new,
                    measurement: MeasurementSummary.new,
                    task: (Task task) {
                      return TaskForm(
                        data: task.data,
                        task: task,
                      );
                    },
                    habitCompletion: (habit) => HabitSummary(
                      habit,
                      paddingLeft: 10,
                      showIcon: true,
                      showText: false,
                    ),
                    journalEntry: (_) => const SizedBox.shrink(),
                    journalImage: (_) => const SizedBox.shrink(),
                  ),
                  const EntryDetailFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
