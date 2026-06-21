import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/ui/widgets/event_summary_card.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';

/// The compact, photo-led representation of an event when it appears inside
/// another entry's linked list (e.g. a task's timeline). Resolves the event's
/// cover and metadata the same way the detail page does — so the card and the
/// detail never disagree — and taps through to the dedicated event page.
class LinkedEventCard extends ConsumerWidget {
  const LinkedEventCard({required this.event, super.key});

  final JournalEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = ref.watch(
      resolvedOutgoingLinkedEntriesProvider(event.meta.id),
    );
    final category = getIt<EntitiesCacheService>().getCategoryById(
      event.meta.categoryId,
    );
    final documentsDirectory = getIt<Directory>().path;

    final data = eventDetailDataFromEntities(
      event: event,
      linked: linked,
      now: DateTime.now(),
      categoryColor: colorFromCssHex(category?.color),
      categoryName: category?.name,
      fallbackTitle: context.messages.entryTypeLabelJournalEvent,
      imageProviderFor: (image) => FileImage(
        File(getFullImagePath(image, documentsDirectory: documentsDirectory)),
      ),
    );

    return EventSummaryCard(
      data: data.card,
      onTap: () => beamToNamed('/events/${event.meta.id}'),
    );
  }
}
