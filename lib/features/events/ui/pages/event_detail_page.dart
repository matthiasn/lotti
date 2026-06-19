import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';

/// Route-level page for a single event's detail view.
///
/// Resolves the [JournalEvent] and its outgoing linked entries and maps them
/// into an [EventDetailView] via [eventDetailDataFromEntities]. Editing and
/// adding to the timeline reuse the existing entry-detail surface; AI summary
/// regeneration is a follow-up.
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

    return EventDetailView(
      data: data,
      onBack: () => Navigator.of(context).maybePop(),
      onEdit: () => beamToNamed('/journal/${entry.meta.id}'),
      onAddToTimeline: () => beamToNamed('/journal/${entry.meta.id}'),
      onAddTask: () => beamToNamed('/journal/${entry.meta.id}'),
      onOpenTimelineEntry: (entryId) => beamToNamed('/journal/$entryId'),
    );
  }
}
