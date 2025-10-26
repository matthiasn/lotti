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
  }) async {
    final now = DateTime.now();
    final label = LabelDefinition(
      id: _uuid.v4(),
      name: name.trim(),
      color: color,
      description: description?.trim(),
      sortOrder: sortOrder,
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
  }) async {
    final updated = label.copyWith(
      name: name?.trim() ?? label.name,
      color: color ?? label.color,
      description: description?.trim(),
      sortOrder: sortOrder ?? label.sortOrder,
      private: private ?? label.private,
      updatedAt: DateTime.now(),
    );

    await _persistenceLogic.upsertEntityDefinition(updated);
    return updated;
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

      return _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: updatedMetadata.copyWith(
            labelIds: sorted.isEmpty ? null : sorted,
          ),
        ),
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
