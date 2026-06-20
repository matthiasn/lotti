import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

/// Route-level page for a single event's detail view.
///
/// Resolves the [JournalEvent] and its outgoing linked entries, maps them into
/// an [EventDetailView] via [eventDetailDataFromEntities], and wires the view's
/// inline-edit callbacks to [EntryController] mutations and the shared
/// pickers/create flows — so editing an event never leaves this page. AI summary
/// regeneration and explicit cover selection are follow-ups.
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntry = ref.watch(entryControllerProvider(id: eventId));

    // A terminal load error shows an error glyph rather than an indefinite
    // spinner; a still-resolving (or genuinely non-event) entry stays on the
    // loading shell.
    if (asyncEntry.hasError) {
      return Scaffold(
        backgroundColor: dsPageSurface(context),
        body: Center(
          child: Icon(
            Icons.error_outline_rounded,
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
    final category = getIt<EntitiesCacheService>().getCategoryById(
      entry.meta.categoryId,
    );
    final documentsDirectory = getIt<Directory>().path;
    final controller = ref.read(entryControllerProvider(id: eventId).notifier);

    final data = eventDetailDataFromEntities(
      event: entry,
      linked: linked,
      now: DateTime.now(),
      categoryColor: colorFromCssHex(category?.color),
      categoryName: category?.name,
      fallbackTitle: context.messages.entryTypeLabelJournalEvent,
      imageProviderFor: (image) => FileImage(
        File(getFullImagePath(image, documentsDirectory: documentsDirectory)),
      ),
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
            icon: Icons.warning_rounded,
            label: context.messages.journalDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );
      if (result == deleteKey) {
        await controller.delete(beamBack: true);
      }
    }

    // Opens the shared create-entry menu scoped to this event, so a new note /
    // photo / audio / task is linked back to it (and the first linked photo
    // becomes the cover automatically). Used for both timeline and cover adds.
    void addLinkedEntry() => CreateEntryModal.show(
      context: context,
      linkedFromId: eventId,
      categoryId: entry.meta.categoryId,
    );

    return EventDetailView(
      data: data,
      onBack: () => Navigator.of(context).maybePop(),
      onRenameTitle: controller.updateEventTitle,
      onTapCategory: pickCategory,
      onTapStatus: pickStatus,
      onSetRating: controller.updateRating,
      onAddCover: addLinkedEntry,
      onDelete: confirmDelete,
      onAddToTimeline: addLinkedEntry,
      onAddTask: () => createTask(
        linkedId: eventId,
        categoryId: entry.meta.categoryId,
      ),
      onOpenTimelineEntry: (entryId) => beamToNamed('/journal/$entryId'),
    );
  }
}
