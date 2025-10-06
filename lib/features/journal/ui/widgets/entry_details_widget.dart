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
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/events/event_form.dart';

class EntryDetailsWidget extends ConsumerWidget {
  const EntryDetailsWidget({
    required this.itemId,
    required this.showAiEntry,
    super.key,
    this.showTaskDetails = false,
    this.parentTags,
    this.linkedFrom,
    this.link,
  });

  final String itemId;
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
        (item is AiResponseEntry && !showAiEntry)) {
      return const SizedBox.shrink();
    }

    final isTask = item is Task;
    final isAudio = item is JournalAudio;

    if (isTask && !showTaskDetails) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
        child: ModernJournalCard(
          item: item,
          showLinkedDuration: true,
          removeHorizontalMargin: true,
        ),
      );
    }

    return ModernBaseCard(
      key: isAudio ? Key('$itemId-${item.meta.vectorClock}') : Key(itemId),
      margin: const EdgeInsets.only(
        left: AppTheme.spacingXSmall,
        right: AppTheme.spacingXSmall,
        bottom: AppTheme.spacingMedium,
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.cardPaddingCompact),
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

    final shouldHideEditor = switch (item) {
      JournalEvent() ||
      QuantitativeEntry() ||
      WorkoutEntry() ||
      Checklist() ||
      ChecklistItem() ||
      AiResponseEntry() => true,
      _ => false,
    };

    final detailSection = switch (item) {
      JournalAudio() => AudioPlayerWidget(item),
      WorkoutEntry() => WorkoutSummary(item),
      SurveyEntry() => SurveySummary(item),
      QuantitativeEntry() => HealthSummary(item),
      MeasurementEntry() => MeasurementSummary(item),
      JournalEvent() => EventForm(item),
      HabitCompletionEntry() => HabitSummary(
          item,
          paddingLeft: 10,
          paddingBottom: 5,
          showIcon: true,
          showText: false,
        ),
      AiResponseEntry() => AiResponseSummary(
          item,
          linkedFromId: linkedFrom?.id,
          fadeOut: true,
        ),
      Checklist() => ChecklistWrapper(
          entryId: item.meta.id,
          taskId: item.data.linkedTasks.first,
        ),
      ChecklistItem() => ChecklistItemWrapper(
          item.id,
          checklistId: '',
          taskId: '',
        ),
      _ => null,
    };

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
        if (item is JournalImage) EntryImageWidget(item),
        if (!shouldHideEditor) EditorWidget(entryId: itemId),
        if (detailSection != null) detailSection,
        EntryDetailFooter(
          entryId: itemId,
          linkedFrom: linkedFrom,
          inLinkedEntries: linkedFrom != null,
        ),
      ],
    );
  }
}
