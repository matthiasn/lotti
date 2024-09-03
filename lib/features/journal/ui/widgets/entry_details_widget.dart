import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_detail_footer.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_detail_header.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_list_widget.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/events/event_form.dart';

class EntryDetailWidget extends ConsumerWidget {
  const EntryDetailWidget({
    required this.itemId,
    required this.popOnDelete,
    super.key,
    this.showTaskDetails = false,
    this.unlinkFn,
    this.parentTags,
    this.linkedFrom,
  });

  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;
  final Future<void> Function()? unlinkFn;
  final JournalEntity? linkedFrom;
  final Set<String>? parentTags;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    final isTask = item is Task;
    final isAudio = item is JournalAudio;

    if (isTask && !showTaskDetails) {
      return JournalCard(
        item: item,
        showLinkedDuration: true,
      );
    }

    return Card(
      key: isAudio ? Key('$itemId-${item.meta.vectorClock}') : Key(itemId),
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item.maybeMap(
              journalImage: EntryImageWidget.new,
              orElse: () => const SizedBox.shrink(),
            ),
            EntryDetailsContent(
              itemId,
              unlinkFn: unlinkFn,
              linkedFrom: linkedFrom,
              parentTags: parentTags,
            ),
          ],
        ),
      ),
    );
  }
}

class EntryDetailsContent extends ConsumerWidget {
  const EntryDetailsContent(
    this.itemId, {
    this.unlinkFn,
    this.linkedFrom,
    this.parentTags,
    super.key,
  });

  final String itemId;
  final Future<void> Function()? unlinkFn;
  final JournalEntity? linkedFrom;
  final Set<String>? parentTags;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    /*  final isFocused = entryState?.isFocused ?? false;
    if (isFocused && isMobile) {
      Future.microtask(() {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutQuint,
        );
      });
    }*/

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryDetailHeader(
          entryId: itemId,
          inLinkedEntries: unlinkFn != null,
          linkedFromId: linkedFrom?.meta.id,
          unlinkFn: unlinkFn,
        ),
        TagsListWidget(entryId: itemId, parentTags: parentTags),
        item.maybeMap(
          task: (_) => const SizedBox.shrink(),
          event: (_) => const SizedBox.shrink(),
          quantitative: (_) => const SizedBox.shrink(),
          workout: (_) => const SizedBox.shrink(),
          orElse: () {
            return EditorWidget(
              entryId: itemId,
              unlinkFn: unlinkFn,
            );
          },
        ),
        item.map(
          journalAudio: AudioPlayerWidget.new,
          workout: WorkoutSummary.new,
          survey: SurveySummary.new,
          quantitative: HealthSummary.new,
          measurement: MeasurementSummary.new,
          task: (task) => TaskForm(
            task,
            key: Key(task.meta.id),
          ),
          event: EventForm.new,
          habitCompletion: (habit) => HabitSummary(
            habit,
            paddingLeft: 10,
            showIcon: true,
            showText: false,
          ),
          journalEntry: (_) => const SizedBox.shrink(),
          journalImage: (_) => const SizedBox.shrink(),
          checklist: (_) => const SizedBox.shrink(),
          checklistItem: (_) => const SizedBox.shrink(),
        ),
        EntryDetailFooter(
          entryId: itemId,
          linkedFrom: linkedFrom,
        ),
      ],
    );
  }
}
