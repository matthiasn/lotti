import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/utils/labels_normalization.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:uuid/uuid.dart';

final labelsRepositoryProvider = Provider<LabelsRepository>((ref) {
  return LabelsRepository(
    getIt<PersistenceLogic>(),
    getIt<JournalDb>(),
    getIt<EntitiesCacheService>(),
    getIt<DomainLogger>(),
    getIt<UpdateNotifications>(),
  );
});

/// Write boundary for the labels feature.
///
/// Owns label-definition CRUD (with category-scope normalization and
/// soft-delete), visibility-aware definition streams, usage counts from the
/// `labeled` lookup table, and assignment writes on entry metadata
/// ([addLabels] / [removeLabel] / [setLabels]). For tasks, assignment writes
/// also maintain the per-task AI suppression set (`aiSuppressedLabelIds`) so
/// rejected suggestions are not re-proposed. See the feature README for the
/// suppression coupling rules.
class LabelsRepository {
  LabelsRepository(
    this._persistenceLogic,
    this._journalDb,
    this._entitiesCacheService,
    this._domainLogger,
    this._updateNotifications,
  );

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final EntitiesCacheService _entitiesCacheService;
  final DomainLogger _domainLogger;
  final UpdateNotifications _updateNotifications;
  final _uuid = const Uuid();

  Stream<List<LabelDefinition>> watchLabels() {
    return notificationDrivenStream(
      notifications: _updateNotifications,
      notificationKeys: {labelsNotification, privateToggleNotification},
      fetcher: _journalDb.getAllLabelDefinitions,
    );
  }

  Stream<LabelDefinition?> watchLabel(String id) {
    return notificationDrivenItemStream(
      notifications: _updateNotifications,
      notificationKeys: {labelsNotification, privateToggleNotification},
      fetcher: () => _journalDb.getLabelDefinitionById(id),
    );
  }

  Future<List<LabelDefinition>> getAllLabels() {
    return _journalDb.getAllLabelDefinitions();
  }

  /// Build label tuples [{id, name}] for the given label IDs
  Future<List<Map<String, String>>> buildLabelTuples(List<String> ids) async {
    if (ids.isEmpty) return <Map<String, String>>[];
    final all = await getAllLabels();
    final byId = {for (final def in all) def.id: def};
    return ids.map((id) {
      final def = byId[id];
      return {'id': id, 'name': def?.name ?? id};
    }).toList();
  }

  /// Get label usage counts for all labels
  Future<Map<String, int>> getLabelUsageCounts() {
    return _journalDb.getLabelUsageCounts();
  }

  Future<LabelDefinition> createLabel({
    required String name,
    required String color,
    String? description,
    int? sortOrder,
    bool? private,
    List<String>? applicableCategoryIds,
  }) async {
    final now = DateTime.now();
    // Validate and normalize applicableCategoryIds
    final normalizedCategoryIds = _normalizeCategoryIds(applicableCategoryIds);
    final label = LabelDefinition(
      id: _uuid.v4(),
      name: name.trim(),
      color: color,
      description: description?.trim(),
      sortOrder: sortOrder,
      applicableCategoryIds: normalizedCategoryIds.isEmpty
          ? null
          : normalizedCategoryIds,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
      private: private,
    );

    await _persistenceLogic.upsertEntityDefinition(label);
    return label;
  }

  Future<LabelDefinition> updateLabel(
    LabelDefinition label, {
    String? name,
    String? color,
    String? description,
    int? sortOrder,
    bool? private,
    List<String>? applicableCategoryIds,
  }) async {
    // Validate and normalize applicableCategoryIds if provided; when null, keep existing
    final normalizedCategoryIds = applicableCategoryIds == null
        ? label.applicableCategoryIds
        : _normalizeCategoryIds(applicableCategoryIds);
    // Description semantics:
    //  - null  => leave unchanged
    //  - ''    => clear (persist as null)
    //  - value => trimmed value
    String? effectiveDescription;
    if (description == null) {
      effectiveDescription = label.description;
    } else {
      final trimmed = description.trim();
      effectiveDescription = trimmed.isEmpty ? null : trimmed;
    }

    final updated = label.copyWith(
      name: name?.trim() ?? label.name,
      color: color ?? label.color,
      // Preserve existing when null (not provided); clear when empty string
      description: effectiveDescription,
      sortOrder: sortOrder ?? label.sortOrder,
      private: private ?? label.private,
      applicableCategoryIds:
          (normalizedCategoryIds == null || normalizedCategoryIds.isEmpty)
          ? null
          : normalizedCategoryIds,
      updatedAt: DateTime.now(),
    );

    await _persistenceLogic.upsertEntityDefinition(updated);
    return updated;
  }

  /// Normalize and validate category IDs: remove unknowns, de-duplicate, and
  /// sort by category name (case-insensitive) for stable diffs.
  List<String> _normalizeCategoryIds(List<String>? categoryIds) {
    return normalizeLabelCategoryIds(
      categoryIds,
      lookupCategory: _entitiesCacheService.getCategoryById,
    );
  }

  Future<void> deleteLabel(String id) async {
    try {
      final existing = await _journalDb.getLabelDefinitionById(id);
      if (existing == null) {
        return;
      }

      final deleted = existing.copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _persistenceLogic.upsertEntityDefinition(deleted);
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.labels,
        error,
        stackTrace: stackTrace,
        subDomain: 'deleteLabel',
      );
    }
  }

  /// Programmatically adds a label ID to the task's `aiSuppressedLabelIds`.
  ///
  /// Used when a user rejects an agent-proposed label so the agent learns
  /// not to re-propose it. Does not modify the task's assigned labels.
  ///
  /// Returns `true` if the suppression was applied, `false` on failure.
  Future<bool> suppressLabelOnTask({
    required String taskId,
    required String labelId,
  }) async {
    try {
      final entity = await _journalDb.journalEntityById(taskId);
      if (entity is! Task) return false;

      final currentSuppressed =
          entity.data.aiSuppressedLabelIds ?? const <String>{};
      if (currentSuppressed.contains(labelId)) return true; // Already done.

      final nextSuppressed = _mergeSuppressed(
        current: currentSuppressed,
        add: {labelId},
      );
      final updated = entity.copyWith(
        data: entity.data.copyWith(
          aiSuppressedLabelIds: nextSuppressed,
        ),
      );
      final applied = await _persistenceLogic.updateDbEntity(updated);
      if (applied ?? false) return true;

      // Write conflict — re-read and retry with override, matching the
      // mergeable-update pattern used by setLabels().
      final latest = await _journalDb.journalEntityById(taskId);
      if (latest is! Task) return false;

      final latestSuppressed =
          latest.data.aiSuppressedLabelIds ?? const <String>{};
      if (latestSuppressed.contains(labelId)) return true;

      final retried = latest.copyWith(
        data: latest.data.copyWith(
          aiSuppressedLabelIds: _mergeSuppressed(
            current: latestSuppressed,
            add: {labelId},
          ),
        ),
      );
      return await _persistenceLogic.updateDbEntity(
            retried,
            overrideComparison: true,
          ) ??
          false;
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.labels,
        error,
        stackTrace: stackTrace,
        subDomain: 'suppressLabelOnTask',
      );
      return false;
    }
  }

  Future<bool?> addLabels({
    required String journalEntityId,
    required List<String> addedLabelIds,
  }) async {
    if (addedLabelIds.isEmpty) {
      return true;
    }

    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final updatedMetadata = await _persistenceLogic.updateMetadata(
        addLabelsToMeta(journalEntity.meta, addedLabelIds),
      );

      // Manual add implicitly unsuppresses corresponding labels on tasks
      if (journalEntity is Task) {
        final currentSuppressed =
            journalEntity.data.aiSuppressedLabelIds ?? const <String>{};
        final nextSuppressed = _mergeSuppressed(
          current: currentSuppressed,
          remove: addedLabelIds.toSet(),
        );
        final updatedEntity = journalEntity.copyWith(
          meta: updatedMetadata,
          data: journalEntity.data.copyWith(
            aiSuppressedLabelIds: nextSuppressed,
          ),
        );
        return _persistenceLogic.updateDbEntity(updatedEntity);
      }

      return _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(meta: updatedMetadata),
      );
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.labels,
        error,
        stackTrace: stackTrace,
        subDomain: 'addLabels',
      );
      return false;
    }
  }

  Future<bool?> removeLabel({
    required String journalEntityId,
    required String labelId,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      final updatedMetadata = await _persistenceLogic.updateMetadata(
        removeLabelFromMeta(journalEntity.meta, labelId),
      );

      // Removing a label adds it to the task's suppression set
      if (journalEntity is Task) {
        final currentSuppressed =
            journalEntity.data.aiSuppressedLabelIds ?? const <String>{};
        final nextSuppressed = _mergeSuppressed(
          current: currentSuppressed,
          add: {labelId},
        );
        final updatedEntity = journalEntity.copyWith(
          meta: updatedMetadata,
          data: journalEntity.data.copyWith(
            aiSuppressedLabelIds: nextSuppressed,
          ),
        );
        return _persistenceLogic.updateDbEntity(updatedEntity);
      }

      return _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(meta: updatedMetadata),
      );
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.labels,
        error,
        stackTrace: stackTrace,
        subDomain: 'removeLabel',
      );
      return false;
    }
  }

  Future<bool?> setLabels({
    required String journalEntityId,
    required List<String> labelIds,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);
      if (journalEntity == null) {
        return false;
      }

      final normalized = LinkedHashSet<String>.from(
        labelIds.where((id) => id.isNotEmpty),
      );
      final resolved = <String>[];
      final nameLookup = <String, String>{};

      for (final id in normalized) {
        final cached = _entitiesCacheService.getLabelById(id);
        if (cached != null) {
          resolved.add(id);
          nameLookup[id] = cached.name.toLowerCase();
          continue;
        }

        final dbLabel = await _journalDb.getLabelDefinitionById(id);
        if (dbLabel != null && dbLabel.deletedAt == null) {
          resolved.add(id);
          nameLookup[id] = dbLabel.name.toLowerCase();
        }
      }

      final sorted = [...resolved]
        ..sort(
          (a, b) => (nameLookup[a] ?? a).compareTo(nameLookup[b] ?? b),
        );

      final updatedMetadata = await _persistenceLogic.updateMetadata(
        journalEntity.meta,
        labelIds: sorted,
        clearLabelIds: sorted.isEmpty,
      );

      JournalEntity updatedEntity;
      if (journalEntity is Task) {
        final prev = journalEntity.meta.labelIds ?? const <String>[];
        final prevSet = prev.toSet();
        final nextSet = sorted.toSet();
        final removed = prevSet.difference(nextSet);
        final added = nextSet.difference(prevSet);

        final currentSuppressed =
            journalEntity.data.aiSuppressedLabelIds ?? const <String>{};
        final nextSuppressed = _mergeSuppressed(
          current: currentSuppressed,
          add: removed,
          remove: added,
        );

        updatedEntity = journalEntity.copyWith(
          meta: updatedMetadata.copyWith(
            labelIds: sorted.isEmpty ? null : sorted,
          ),
          data: journalEntity.data.copyWith(
            aiSuppressedLabelIds: nextSuppressed,
          ),
        );
      } else {
        updatedEntity = journalEntity.copyWith(
          meta: updatedMetadata.copyWith(
            labelIds: sorted.isEmpty ? null : sorted,
          ),
        );
      }

      // First attempt: normal update (keeps test/mocks simple and fast)
      final applied = await _persistenceLogic.updateDbEntity(updatedEntity);
      if (applied ?? false) return applied;

      // Fallback: allow override when vector clocks are concurrent.
      // Safe for labels since the labeled table merges the set.
      return _persistenceLogic.updateDbEntity(
        updatedEntity,
        overrideComparison: true,
      );
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.labels,
        error,
        stackTrace: stackTrace,
        subDomain: 'setLabels',
      );
      return false;
    }
  }
}

Set<String>? _mergeSuppressed({
  Set<String>? current,
  Set<String> add = const <String>{},
  Set<String> remove = const <String>{},
}) {
  final next = <String>{...(current ?? const <String>{})}
    ..addAll(add)
    ..removeAll(remove);
  return next.isEmpty ? null : next;
}

Metadata addLabelsToMeta(
  Metadata metadata,
  List<String> addedLabelIds,
) {
  final existing = metadata.labelIds ?? <String>[];
  final next = [...existing];

  for (final labelId in addedLabelIds) {
    if (!next.contains(labelId)) {
      next.add(labelId);
    }
  }

  return metadata.copyWith(labelIds: next);
}

Metadata removeLabelFromMeta(
  Metadata metadata,
  String labelId,
) {
  final next = metadata.labelIds?.where((id) => id != labelId).toList();

  if (next == null || next.isEmpty) {
    return metadata.copyWith(labelIds: null);
  }

  return metadata.copyWith(labelIds: next);
}
