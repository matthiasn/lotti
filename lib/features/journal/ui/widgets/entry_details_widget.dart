import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_detail_footer.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_list_widget.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_wrapper.dart';
import 'package:lotti/widgets/events/event_form.dart';

class EntryDetailsWidget extends ConsumerWidget {
  const EntryDetailsWidget({
    required this.itemId,
    required this.popOnDelete,
    required this.showAiEntry,
    super.key,
    this.showTaskDetails = false,
    this.parentTags,
    this.linkedFrom,
    this.link,
  });

  final String itemId;
  final bool popOnDelete;
  final bool showTaskDetails;
  final bool showAiEntry;

  final JournalEntity? linkedFrom;
  final EntryLink? link;
  final Set<String>? parentTags;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null ||
        item.meta.deletedAt != null ||
        (item is AiResponseEntry && showAiEntry == false)) {
      return const SizedBox.shrink();
    }

    final isTask = item is Task;
    final isAudio = item is JournalAudio;

    if (isTask && !showTaskDetails) {
      return ModernJournalCard(
        item: item,
        showLinkedDuration: true,
      );
    }

    return Card(
      key: isAudio ? Key('$itemId-${item.meta.vectorClock}') : Key(itemId),
      margin: const EdgeInsets.only(left: 5, right: 5, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntryDetailsContent(
              itemId,
              linkedFrom: linkedFrom,
              parentTags: parentTags,
              link: link,
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
    this.linkedFrom,
    this.link,
    this.parentTags,
    super.key,
  });

  final String itemId;

  final JournalEntity? linkedFrom;
  final EntryLink? link;

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
          inLinkedEntries: linkedFrom != null,
          linkedFromId: linkedFrom?.id,
          link: link,
        ),
        TagsListWidget(entryId: itemId, parentTags: parentTags),
        item.maybeMap(
          journalImage: EntryImageWidget.new,
          orElse: () => const SizedBox.shrink(),
        ),
        item.maybeMap(
          //task: (_) => const SizedBox.shrink(),
          event: (_) => const SizedBox.shrink(),
          quantitative: (_) => const SizedBox.shrink(),
          workout: (_) => const SizedBox.shrink(),
          checklist: (_) => const SizedBox.shrink(),
          checklistItem: (_) => const SizedBox.shrink(),
          aiResponse: (_) => const SizedBox.shrink(),
          orElse: () {
            return EditorWidget(entryId: itemId);
          },
        ),
        item.map(
          journalAudio: AudioPlayerWidget.new,
          workout: WorkoutSummary.new,
          survey: SurveySummary.new,
          quantitative: HealthSummary.new,
          measurement: MeasurementSummary.new,
          task: (task) => const SizedBox.shrink(),
          event: EventForm.new,
          habitCompletion: (habit) => HabitSummary(
            habit,
            paddingLeft: 10,
            paddingBottom: 5,
            showIcon: true,
            showText: false,
          ),
          journalEntry: (_) => const SizedBox.shrink(),
          journalImage: (_) => const SizedBox.shrink(),
          aiResponse: (aiResponse) => AiResponseSummary(
            aiResponse,
            linkedFromId: linkedFrom?.id,
            fadeOut: true,
          ),
          checklist: (checklist) => ChecklistWrapper(
            entryId: checklist.meta.id,
            taskId: checklist.data.linkedTasks.first,
          ),
          checklistItem: (checklistItem) => ChecklistItemWrapper(
            checklistItem.id,
            checklistId: '',
            taskId: '',
          ),
        ),
        EntryDetailFooter(
          entryId: itemId,
          linkedFrom: linkedFrom,
          inLinkedEntries: linkedFrom != null,
        ),
      ],
    );
  }
}
