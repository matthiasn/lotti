import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_header.dart';
import 'package:lotti/widgets/journal/entry_details/health_summary.dart';
import 'package:lotti/widgets/journal/entry_details/measurement_summary.dart';
import 'package:lotti/widgets/journal/entry_details/survey_summary.dart';
import 'package:lotti/widgets/journal/entry_details/workout_summary.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:lotti/widgets/journal/tags/tags_list_widget.dart';
import 'package:lotti/widgets/tasks/task_form.dart';

class EntryDetailWidget extends StatefulWidget {
  const EntryDetailWidget({
    super.key,
    required this.itemId,
    required this.popOnDelete,
    this.showTaskDetails = false,
  });

  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;

  @override
  State<EntryDetailWidget> createState() => _EntryDetailWidgetState();
}

class _EntryDetailWidgetState extends State<EntryDetailWidget> {
  final JournalDb _db = getIt<JournalDb>();
  late final Stream<JournalEntity?> _stream =
      _db.watchEntityById(widget.itemId);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
      stream: _stream,
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

        if ((isTask || isAudio) && !widget.showTaskDetails) {
          return JournalCard(item: item);
        }

        return BlocProvider<EntryCubit>(
          create: (BuildContext context) => EntryCubit(
            entryId: widget.itemId,
            entry: item,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 3,
                  blurRadius: 5,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: ColoredBox(
                color: styleConfig().cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EntryDetailHeader(),
                    TagsListWidget(),
                    item.maybeMap(
                      journalImage: EntryImageWidget.new,
                      orElse: () => const SizedBox.shrink(),
                    ),
                    item.maybeMap(
                      task: (_) => const SizedBox.shrink(),
                      quantitative: (_) => const SizedBox.shrink(),
                      workout: (_) => const SizedBox.shrink(),
                      orElse: () {
                        return const EditorWidget();
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: item.map(
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
                        habitCompletion: (_) => const SizedBox.shrink(),
                        journalEntry: (_) => const SizedBox.shrink(),
                        journalImage: (_) => const SizedBox.shrink(),
                      ),
                    ),
                    const EntryDetailFooter(),
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
