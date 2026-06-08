import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';

const _fallbackActualCategory = DayAgentCategory(
  id: 'uncategorized',
  name: '',
  colorHex: '8E8E8E',
);

// ignore: specify_nonobvious_property_types
final dailyOsActualTimeUpdateProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) {
    final notifications = ref.watch(maybeUpdateNotificationsProvider);
    if (notifications == null) return const Stream<Set<String>>.empty();
    return actualTimelineUpdateBatches(notifications.updateStream);
  },
);

@visibleForTesting
Stream<Set<String>> actualTimelineUpdateBatches(Stream<Set<String>> updates) {
  return updates.where((affectedIds) => affectedIds.isNotEmpty);
}

// ignore: specify_nonobvious_property_types
final dailyOsActualTimeBlocksProvider = FutureProvider.autoDispose
    .family<List<TimeBlock>, DateTime>((ref, date) async {
      ref.watch(dailyOsActualTimeUpdateProvider);
      final db = ref.watch(journalDbProvider);
      final dayStart = date.dayAtMidnight;
      final dayEnd = dayStart.add(const Duration(days: 1));
      final entries = await db.sortedCalendarEntries(
        rangeStart: dayStart,
        rangeEnd: dayEnd,
      );
      final links = await db.basicLinksForEntryIds(
        entries.map((entry) => entry.meta.id).toSet(),
      );
      return actualTimeBlocksForEntries(
        entries: entries,
        links: links,
        linkedFromById: await _linkedFromById(db, links),
        categoryById: _categoryById,
      );
    });

Future<Map<String, JournalEntity>> _linkedFromById(
  JournalDb db,
  List<EntryLink> links,
) async {
  final linkedFromIds = links.map((link) => link.fromId).toSet();
  if (linkedFromIds.isEmpty) return const {};
  final linked = await db.getJournalEntitiesForIdsUnordered(linkedFromIds);
  return {for (final entity in linked) entity.meta.id: entity};
}

CategoryDefinition? _categoryById(String id) {
  if (!getIt.isRegistered<EntitiesCacheService>()) return null;
  return getIt<EntitiesCacheService>().getCategoryById(id);
}

@visibleForTesting
List<TimeBlock> actualTimeBlocksForEntries({
  required List<JournalEntity> entries,
  required List<EntryLink> links,
  required Map<String, JournalEntity> linkedFromById,
  required CategoryDefinition? Function(String id) categoryById,
}) {
  final entryIdToLinkedFromIds = <String, Set<String>>{};
  for (final link in links) {
    if (link.deletedAt != null) continue;
    entryIdToLinkedFromIds
        .putIfAbsent(link.toId, () => <String>{})
        .add(link.fromId);
  }

  final out = <TimeBlock>[];
  for (final entry in entries) {
    if (entry.meta.deletedAt != null) continue;
    final duration = entryDuration(entry);
    if (duration <= Duration.zero) continue;

    final linkedFrom = _resolveLinkedFrom(
      linkedFromIds: entryIdToLinkedFromIds[entry.meta.id],
      linkedFromById: linkedFromById,
    );
    final categoryId = linkedFrom?.meta.categoryId ?? entry.meta.categoryId;
    final category = _projectCategory(categoryId, categoryById);
    final title = _actualBlockTitle(
      entry: entry,
      linkedFrom: linkedFrom,
      category: category,
    );

    out.add(
      TimeBlock(
        id: '$actualTimeBlockIdPrefix${entry.meta.id}',
        title: title,
        start: entry.meta.dateFrom,
        end: entry.meta.dateTo,
        type: TimeBlockType.manual,
        state: TimeBlockState.completed,
        category: category,
        taskId: linkedFrom is Task ? linkedFrom.meta.id : null,
      ),
    );
  }

  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Test-only seam for [_resolveLinkedFrom] — the pure linked-from picker.
@visibleForTesting
JournalEntity? debugResolveLinkedFrom({
  required Set<String>? linkedFromIds,
  required Map<String, JournalEntity> linkedFromById,
}) => _resolveLinkedFrom(
  linkedFromIds: linkedFromIds,
  linkedFromById: linkedFromById,
);

/// Test-only seam for [_projectCategory] — the pure category/color
/// normalizer.
@visibleForTesting
DayAgentCategory debugProjectCategory(
  String? categoryId,
  CategoryDefinition? Function(String id) categoryById,
) => _projectCategory(categoryId, categoryById);

/// The fallback category used when no category is resolvable.
@visibleForTesting
DayAgentCategory get debugFallbackActualCategory => _fallbackActualCategory;

JournalEntity? _resolveLinkedFrom({
  required Set<String>? linkedFromIds,
  required Map<String, JournalEntity> linkedFromById,
}) {
  if (linkedFromIds == null) return null;

  JournalEntity? fallbackNonRating;
  for (final linkedFromId in linkedFromIds) {
    final linkedFrom = linkedFromById[linkedFromId];
    if (linkedFrom == null || linkedFrom.meta.deletedAt != null) continue;
    if (linkedFrom is Task) return linkedFrom;
    if (linkedFrom is RatingEntry) continue;
    fallbackNonRating ??= linkedFrom;
  }
  return fallbackNonRating;
}

DayAgentCategory _projectCategory(
  String? categoryId,
  CategoryDefinition? Function(String id) categoryById,
) {
  if (categoryId == null || categoryId.isEmpty) return _fallbackActualCategory;
  final category = categoryById(categoryId);
  final rawColor = (category?.color ?? _fallbackActualCategory.colorHex)
      .replaceFirst('#', '');
  final normalizedColor = rawColor.length >= 6
      ? rawColor.substring(0, 6)
      : _fallbackActualCategory.colorHex;
  return DayAgentCategory(
    id: categoryId,
    name: category?.name ?? categoryId,
    colorHex: normalizedColor,
  );
}

String _actualBlockTitle({
  required JournalEntity entry,
  required JournalEntity? linkedFrom,
  required DayAgentCategory category,
}) {
  if (linkedFrom is Task) {
    final taskTitle = linkedFrom.data.title.trim();
    if (taskTitle.isNotEmpty) return taskTitle;
  }

  final entryText = entry.entryText?.plainText.trim();
  if (entryText != null && entryText.isNotEmpty) {
    return entryText.split('\n').first.trim();
  }

  if (category.name.isNotEmpty) return category.name;
  return entry.meta.id;
}
