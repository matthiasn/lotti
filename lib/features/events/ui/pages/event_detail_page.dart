import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/ui/widgets/event_ai_summary_card.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_picker.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/create/entry_creation_service.dart';
import 'package:lotti/features/journal/ui/widgets/entry_action_bar.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_ui/material_ui.dart';

/// Route-level page for a single event's detail view.
///
/// Resolves the [JournalEvent] and its outgoing linked entries, maps them into
/// an [EventDetailView] via [eventDetailDataFromEntities], and wires the view's
/// inline-edit callbacks to [EntryController] mutations and the shared
/// pickers — so editing an event never leaves this page. Adding to the event
/// happens from the [EntryActionBar] docked along the bottom edge, the same
/// bar an entry's page ends in: a task linked to the event, a voice note, or
/// the Add sheet for everything else. The mobile shell unmounts its launcher
/// on `/events/<uuid>` so that bar docks flush with the home indicator.
///
/// Toasts raised on the page — the delete-failed line, anything the recap or
/// change-set cards show — are scoped to a nested [ScaffoldMessenger] so they
/// float above the bar rather than at the window's bottom edge, which the bar
/// would cover.
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntry = ref.watch(entryControllerProvider(eventId));

    // A terminal load error shows an error glyph rather than an indefinite
    // spinner; a still-resolving (or genuinely non-event) entry stays on the
    // loading shell.
    if (asyncEntry.hasError) {
      return Scaffold(
        backgroundColor: dsPageSurface(context),
        body: Center(
          child: Icon(
            LottiIcons.error,
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    final entry = asyncEntry.value?.entry;
    if (entry is! JournalEvent) {
      return Scaffold(
        backgroundColor: dsPageSurface(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final linked = ref.watch(resolvedOutgoingLinkedEntriesProvider(eventId));

    // Every provider the page depends on is watched above, in its own build.
    // The Builder exists only to hand the resolved view — and the toasts its
    // callbacks raise — a context beneath the nested messenger.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) =>
            _resolvedView(context, ref, entry: entry, linked: linked),
      ),
    );
  }

  Widget _resolvedView(
    BuildContext context,
    WidgetRef ref, {
    required JournalEvent entry,
    required List<JournalEntity> linked,
  }) {
    final category = getIt<EntitiesCacheService>().getCategoryById(
      entry.meta.categoryId,
    );
    final documentsDirectory = getIt<Directory>().path;
    final controller = ref.read(entryControllerProvider(eventId).notifier);

    final data = eventDetailDataFromEntities(
      event: entry,
      linked: linked,
      now: DateTime.now(),
      locale: Localizations.localeOf(context).toString(),
      categoryColor: colorFromCssHex(category?.color),
      categoryName: category?.name,
      fallbackTitle: context.messages.entryTypeLabelJournalEvent,
      formatTime: (moment) => TimeOfDay.fromDateTime(moment).format(context),
      imageProviderFor: (image) => FileImage(
        File(getFullImagePath(image, documentsDirectory: documentsDirectory)),
      ),
      imagePathFor: (image) =>
          getFullImagePath(image, documentsDirectory: documentsDirectory),
      // A voice memo on an event's timeline now plays where it sits, instead
      // of only naming its duration. The app-wide player means starting one
      // beat stops any other.
      audioPlayerFor: AudioPlayerWidget.new,
    );

    Future<void> pickCategory() async {
      final result = await showCategoryPicker(
        context: context,
        title: context.messages.habitCategoryLabel,
        currentCategoryId: entry.meta.categoryId,
      );
      if (result is CategoryPicked) {
        await controller.updateCategoryId(result.category.id);
      } else if (result.isExplicitClear) {
        await controller.updateCategoryId(null);
      }
    }

    Future<void> pickStatus() async {
      final status = await showEventStatusPicker(
        context: context,
        current: entry.data.status,
      );
      if (status != null) await controller.updateEventStatus(status);
    }

    Future<void> confirmDelete() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: context.messages.journalDeleteQuestion,
        actions: [
          ModalSheetAction(
            icon: LottiIcons.warning,
            label: context.messages.journalDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );
      if (result == deleteKey) {
        final deleted = await controller.delete(beamBack: true);
        // Not deleted: the event is still there, and the user is told so.
        if (!deleted && context.mounted) {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.journalDeleteFailed,
          );
        }
      }
    }

    // Opens the shared create-entry menu scoped to this event, so a new photo
    // is linked back to it and — the first linked photo — becomes the cover
    // automatically. Only the cover affordances use it: everything else the
    // event collects is added from the action bar along the bottom edge.
    // Through the same service as that bar's plus, so the two cannot drift.
    void addLinkedEntry() => ref
        .read(entryCreationServiceProvider)
        .showCreateEntryModal(
          context,
          linkedFromId: eventId,
          categoryId: entry.meta.categoryId,
        );

    // The event's linked photos, any of which can become the cover. Only wired
    // up (via onChangeCover) once a cover exists, which implies at least one
    // linked photo — so the picker always has something to choose from.
    final linkedImages = linked.whereType<JournalImage>().toList();

    // Opens a sheet to pick a different linked photo as the cover (or add a new
    // one).
    void changeCover() {
      showEventCoverPicker(
        context: context,
        currentCoverId: entry.data.coverArtId,
        choices: [
          for (final image in linkedImages)
            EventCoverChoice(
              id: image.meta.id,
              image: FileImage(
                File(
                  getFullImagePath(
                    image,
                    documentsDirectory: documentsDirectory,
                  ),
                ),
              ),
            ),
        ],
        onSelect: controller.updateEventCover,
        onAddPhoto: addLinkedEntry,
      );
    }

    return EventDetailView(
      data: data,
      aiSummaryCard: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EventAiSummaryCard(eventId: eventId, fallbackSummary: data.summary),
          // Renders nothing until the agent proposes a follow-up the user can
          // accept or reject.
          ChangeSetSummaryCard.event(eventId: eventId),
        ],
      ),
      onBack: () => Navigator.of(context).maybePop(),
      onRenameTitle: controller.updateEventTitle,
      onTapCategory: pickCategory,
      onTapStatus: pickStatus,
      onTapDateTime: () =>
          EntryDateTimeMultiPageModal.show(context: context, entry: entry),
      onSetRating: controller.updateRating,
      onAddCover: addLinkedEntry,
      onChangeCover: data.card.coverImage == null ? null : changeCover,
      onSetCover: controller.updateEventCover,
      onDelete: confirmDelete,
      // Preserve the parent event in the route so the standalone entry menu
      // can offer the existing confirmed unlink action for this exact link.
      onOpenTimelineEntry: (entryId) => beamToNamed(
        Uri(
          path: '/journal/$entryId',
          queryParameters: {'linkedFromId': eventId},
        ).toString(),
      ),
      onOpenTask: (taskId) => beamToNamed('/tasks/$taskId'),
      // The one place the event grows from: a task linked to it, a voice
      // memo, or the Add sheet for the rest — the same bar an entry's page
      // ends in, so what was learnt there carries over.
      bottomBar: EntryActionBar(entry: entry),
    );
  }
}
