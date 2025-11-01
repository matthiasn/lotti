import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:uuid/uuid.dart';

final labelsRepositoryProvider = Provider<LabelsRepository>((ref) {
  return LabelsRepository(
    getIt<PersistenceLogic>(),
    getIt<JournalDb>(),
    getIt<EntitiesCacheService>(),
    getIt<LoggingService>(),
  );
});

class LabelsRepository {
  LabelsRepository(
    this._persistenceLogic,
    this._journalDb,
    this._entitiesCacheService,
    this._loggingService,
  );

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final EntitiesCacheService _entitiesCacheService;
  final LoggingService _loggingService;
  final _uuid = const Uuid();

  Stream<List<LabelDefinition>> watchLabels() {
    return _journalDb.watchLabelDefinitions();
  }

  Stream<LabelDefinition?> watchLabel(String id) {
    return _journalDb.watchLabelDefinitionById(id);
  }

  Future<List<LabelDefinition>> getAllLabels() {
    return _journalDb.getAllLabelDefinitions();
  }

  LabelDefinition? getLabelById(String? id) {
    return _entitiesCacheService.getLabelById(id);
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
      applicableCategoryIds:
          normalizedCategoryIds.isEmpty ? null : normalizedCategoryIds,
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
    final updated = label.copyWith(
      name: name?.trim() ?? label.name,
      color: color ?? label.color,
      // Preserve existing description when not explicitly provided
      description: description == null ? label.description : description.trim(),
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
    if (categoryIds == null) return const <String>[];
    // Trim incoming IDs and drop empties before validation/dedup
    final unique = LinkedHashSet<String>.from(
      categoryIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
    );

    final valid = <String>[];
    final nameById = <String, String>{};
    for (final id in unique) {
      final category = _entitiesCacheService.getCategoryById(id);
      if (category != null) {
        valid.add(id);
        nameById[id] = category.name.toLowerCase();
      }
    }

    valid.sort((a, b) => (nameById[a] ?? a).compareTo(nameById[b] ?? b));
    return valid;
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
      _loggingService.captureException(
        error,
        domain: 'labels_repository',
        subDomain: 'deleteLabel',
        stackTrace: stackTrace,
      );
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

      return _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(meta: updatedMetadata),
      );
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'labels_repository',
        subDomain: 'addLabels',
        stackTrace: stackTrace,
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

      return _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(meta: updatedMetadata),
      );
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'labels_repository',
        subDomain: 'removeLabel',
        stackTrace: stackTrace,
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

      final sorted = [...resolved]..sort(
          (a, b) => (nameLookup[a] ?? a).compareTo(nameLookup[b] ?? b),
        );

      final updatedMetadata = await _persistenceLogic.updateMetadata(
        journalEntity.meta,
        labelIds: sorted,
        clearLabelIds: sorted.isEmpty,
      );

      final updatedEntity = journalEntity.copyWith(
        meta: updatedMetadata.copyWith(
          labelIds: sorted.isEmpty ? null : sorted,
        ),
      );

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
      _loggingService.captureException(
        error,
        domain: 'labels_repository',
        subDomain: 'setLabels',
        stackTrace: stackTrace,
      );
      return false;
    }
  }
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
