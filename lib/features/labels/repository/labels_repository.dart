import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/utils/labels_normalization.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/write_on_stored.dart';
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
/// soft-delete), visibility-aware definition streams, and assignment writes on
/// entry metadata ([addLabels] / [setLabels]). For tasks, assignment writes
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

  /// Streams all label definitions, re-fetching on label or private-toggle
  /// changes. Note: this is unfiltered; private filtering happens upstream in
  /// `labelsStreamProvider`.
  Stream<List<LabelDefinition>> watchLabels() {
    return notificationDrivenStream(
      notifications: _updateNotifications,
      notificationKeys: {labelsNotification, privateToggleNotification},
      fetcher: _journalDb.getAllLabelDefinitions,
    );
  }

  /// Streams a single label by [id], emitting `null` if it does not exist, and
  /// re-fetching on label or private-toggle changes.
  Stream<LabelDefinition?> watchLabel(String id) {
    return notificationDrivenItemStream(
      notifications: _updateNotifications,
      notificationKeys: {labelsNotification, privateToggleNotification},
      fetcher: () => _journalDb.getLabelDefinitionById(id),
    );
  }

  /// One-shot fetch of all label definitions (used for duplicate-name checks
  /// and tuple resolution).
  Future<List<LabelDefinition>> getAllLabels() {
    return _journalDb.getAllLabelDefinitions();
  }

  /// Creates and persists a new label with a generated UUID.
  ///
  /// Trims [name]/[description] and normalizes [applicableCategoryIds] (drops
  /// unknown categories, dedupes, sorts by name); an empty result is stored as
  /// `null`, making the label global. Returns the created definition.
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

  /// Updates [label] with any provided fields and persists the result.
  ///
  /// Each optional parameter is patch-semantics: `null` keeps the existing
  /// value. [description] additionally treats `''` as "clear" (stored as
  /// `null`). [applicableCategoryIds] when non-null is normalized and replaces
  /// the scope; an empty/normalized-empty list clears it (label becomes
  /// global). Bumps `updatedAt`. Returns the updated definition.
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

  /// Soft-deletes the label by stamping `deletedAt`/`updatedAt`; the row is
  /// retained for sync. No-ops if the label is missing, and swallows+logs
  /// errors rather than throwing.
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
  /// not to re-propose it. Does not modify the task's assigned labels. The
  /// suppression is a new version of the task, under a new clock, so it
  /// syncs; see [_writeOnStored].
  ///
  /// Returns `true` if the suppression was applied or already present,
  /// `false` on failure.
  Future<bool> suppressLabelOnTask({
    required String taskId,
    required String labelId,
  }) async {
    try {
      final entity = await _journalDb.journalEntityById(taskId);
      if (entity is! Task) return false;

      return await _writeOnStored(taskId, (stored) async {
        if (stored is! Task) return null;
        final currentSuppressed =
            stored.data.aiSuppressedLabelIds ?? const <String>{};
        if (currentSuppressed.contains(labelId)) return null; // Already done.
        return stored.copyWith(
          meta: await _persistenceLogic.updateMetadata(stored.meta),
          data: stored.data.copyWith(
            aiSuppressedLabelIds: _mergeSuppressed(
              current: currentSuppressed,
              add: {labelId},
            ),
          ),
        );
      });
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

  /// Adds [addedLabelIds] to an entry's metadata (union, no removals).
  ///
  /// For tasks, manually adding a label also unsuppresses it (removes it from
  /// `aiSuppressedLabelIds`), reversing a prior rejection. Returns `true` on
  /// success, `false` if the entry is missing or on error (logged), or `true`
  /// for an empty input. This is the persist path used by the assignment
  /// processor.
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
        return await _persistenceLogic.updateDbEntity(updatedEntity);
      }

      return await _persistenceLogic.updateDbEntity(
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

  /// Replaces an entry's full label set with [labelIds] (the manual editor's
  /// commit path).
  ///
  /// Dedupes, drops unknown/soft-deleted IDs (cache-first, DB fallback), and
  /// sorts by label name. For tasks, diffs against the previous set: removed
  /// labels are suppressed and (re-)added labels are unsuppressed in one update.
  /// The change is built on the stored entry and, when another version syncs
  /// in while it is written, built again on that one ([_writeOnStored]) —
  /// never forced over it. Returns whether the labels were written; `false`
  /// if the entry is missing or on error (logged).
  Future<bool?> setLabels({
    required String journalEntityId,
    required List<String> labelIds,
  }) async {
    try {
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

      return await _writeOnStored(
        journalEntityId,
        (stored) => _withLabels(stored, sorted),
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

  /// [stored] with its labels set to [sorted] under a new clock. For a task,
  /// removed labels are suppressed and (re-)added ones unsuppressed, against
  /// the labels [stored] carries.
  Future<JournalEntity> _withLabels(
    JournalEntity stored,
    List<String> sorted,
  ) async {
    final updatedMetadata = await _persistenceLogic.updateMetadata(
      stored.meta,
      labelIds: sorted,
      clearLabelIds: sorted.isEmpty,
    );
    final meta = updatedMetadata.copyWith(
      labelIds: sorted.isEmpty ? null : sorted,
    );
    if (stored is! Task) return stored.copyWith(meta: meta);

    final prevSet = (stored.meta.labelIds ?? const <String>[]).toSet();
    final nextSet = sorted.toSet();
    return stored.copyWith(
      meta: meta,
      data: stored.data.copyWith(
        aiSuppressedLabelIds: _mergeSuppressed(
          current: stored.data.aiSuppressedLabelIds ?? const <String>{},
          add: prevSet.difference(nextSet),
          remove: nextSet.difference(prevSet),
        ),
      ),
    );
  }

  /// Writes the version [build] makes of the stored entry [id] with
  /// [writeOnStored]: a version that synced in meanwhile is never
  /// overwritten, the change is built again on it (ADR 0083).
  Future<bool> _writeOnStored(
    String id,
    Future<JournalEntity?> Function(JournalEntity stored) build,
  ) => writeOnStored(
    journalDb: _journalDb,
    persistenceLogic: _persistenceLogic,
    id: id,
    build: build,
  );
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

/// Returns a copy of [metadata] with [addedLabelIds] unioned into its
/// `labelIds`, preserving existing order and skipping IDs already present.
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
