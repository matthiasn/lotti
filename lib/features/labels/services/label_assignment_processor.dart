import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Outcome of a single [LabelAssignmentProcessor.processAssignment] run.
///
/// Partitions the proposed IDs into three buckets: [assigned] (persisted),
/// [invalid] (unknown or soft-deleted definitions), and [skipped] — each a
/// `{id, reason}` map where reason is one of `out_of_scope`, `suppressed`,
/// `already_assigned`, `over_cap`, `duplicate`, or `suppression_unknown` (the
/// task could not be read as a task, so nothing was assigned). [toStructuredJson]
/// renders this for return to the model.
class LabelAssignmentResult {
  LabelAssignmentResult({
    required this.assigned,
    required this.invalid,
    required this.skipped,
  });

  final List<String> assigned;
  final List<String> invalid;
  final List<Map<String, String>> skipped;

  /// Returns a structured JSON summary suitable for returning to the model.
  ///
  /// Example input and output:
  ///
  /// Input (requested): ["bug", "backend", "unknown"]
  /// Output JSON (string):
  /// {
  ///   "function": "assign_task_labels",
  ///   "request": {"labelIds": ["bug", "backend", "unknown"]},
  ///   "result": {
  ///     "assigned": ["bug", "backend"],
  ///     "invalid": ["unknown"],
  ///     "skipped": []
  ///   },
  ///   "message": "Assigned 2 label(s); 1 invalid; 0 skipped"
  /// }
  String toStructuredJson(
    List<String> requested,
  ) => jsonEncode({
    'function': 'assign_task_labels',
    'request': {'labelIds': requested},
    'result': {
      'assigned': assigned,
      'invalid': invalid,
      'skipped': skipped,
    },
    'message':
        'Assigned ${assigned.length} label(s); ${invalid.length} invalid; ${skipped.length} skipped',
  });
}

/// Applies an AI/agent label proposal to a task with defense-in-depth guards.
///
/// The pipeline normalizes and dedupes proposed IDs, caps the set at
/// [kMaxLabelsPerAssignment], skips already-assigned IDs, and validates each
/// remaining ID via [LabelValidator] (must exist, not be deleted, be in
/// category scope, and not be suppressed for the task). Pre-existing labels do
/// not block new assignments — a suggested label is applied regardless of how
/// many labels the task already carries. Survivors are persisted add-only
/// through
/// [LabelsRepository.addLabels]; the outcome is summarized via
/// [LabelAssignmentResult.toStructuredJson] for return to the model.
class LabelAssignmentProcessor {
  LabelAssignmentProcessor({
    JournalDb? db,
    LabelsRepository? repository,
    DomainLogger? logging,
    LabelValidator? validator,
  }) : _repository = repository ?? getIt<LabelsRepository>(),
       _logging = logging ?? getIt<DomainLogger>(),
       _validator = validator ?? LabelValidator(db: db),
       _db = db;

  final LabelsRepository _repository;
  final DomainLogger _logging;
  final LabelValidator _validator;
  final JournalDb? _db;

  /// Runs the guarded assignment pipeline for [taskId] over [proposedIds],
  /// returning which IDs were assigned, invalid, or skipped (with reasons).
  ///
  /// [existingIds] are the task's current labels, used only to skip
  /// already-assigned IDs — they do not count against the per-call cap. Pass
  /// [categoryId] to avoid a redundant DB lookup. The remaining parameters are
  /// parser telemetry forwarded into structured logs, not control flow.
  Future<LabelAssignmentResult> processAssignment({
    required String taskId,
    required List<String> proposedIds,
    required List<String> existingIds,
    // Optional task context to avoid redundant DB lookups
    String? categoryId,
    // Optional Phase 2 parser metrics for telemetry
    int droppedLow = 0,
    bool legacyUsed = false,
    Map<String, int>? confidenceBreakdown,
    int? totalCandidates,
  }) async {
    // Normalize proposed IDs (trim, drop empties)
    final normalized = proposedIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Track duplicates in the original proposal order
    final counts = <String, int>{};
    for (final id in normalized) {
      counts.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
    final duplicateIds = counts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toSet();

    // Preserve order, dedupe, and cap by max-per-call
    final dedupedOrder = LinkedHashSet<String>.from(normalized).toList();
    final overCap = dedupedOrder.length > kMaxLabelsPerAssignment
        ? dedupedOrder.sublist(kMaxLabelsPerAssignment)
        : const <String>[];
    final base = dedupedOrder.take(kMaxLabelsPerAssignment).toList();

    // Skip labels already assigned on the task
    final existingSet = existingIds.toSet();
    final alreadyAssigned = base.where(existingSet.contains).toList();

    // Final requested set to validate and (optionally) persist
    final requested = base.where((id) => !existingSet.contains(id)).toList();
    if (requested.isEmpty) {
      return LabelAssignmentResult(
        assigned: const [],
        invalid: const [],
        skipped: const [],
      );
    }
    final assigned = <String>[];
    final invalid = <String>[];
    final skipped = <Map<String, String>>[];
    final sw = Stopwatch()..start();
    // The task, read fresh, for its category (unless the caller passed one)
    // and its suppressed set. Callers filter on an earlier read, but this one
    // is load-bearing: a label the user removed is suppressed, and a confirmed
    // proposal applied late — the same item confirmed on another device before
    // they synced — must not bring it back (ADR 0097). If the read fails, or
    // does not yield a task (deleted since the caller read it), which labels
    // the user removed is unknown, so nothing is assigned.
    LabelAssignmentResult suppressionUnknown(String reason, [StackTrace? st]) {
      _logging.error(
        LogDomain.labels,
        'label_assignment.task_lookup_failed: $reason',
        stackTrace: st,
        subDomain: 'processor',
      );
      return LabelAssignmentResult(
        assigned: const [],
        invalid: const [],
        skipped: [
          for (final id in requested)
            {'id': id, 'reason': 'suppression_unknown'},
        ],
      );
    }

    final JournalEntity? entity;
    try {
      entity = await (_db ?? getIt<JournalDb>()).journalEntityById(taskId);
    } catch (e, st) {
      return suppressionUnknown('$e', st);
    }
    if (entity is! Task) {
      return suppressionUnknown(
        entity == null ? 'task not found' : 'not a task: ${entity.runtimeType}',
      );
    }
    final effectiveCategoryId = categoryId ?? entity.meta.categoryId;
    final suppressedSet = entity.data.aiSuppressedLabelIds ?? const <String>{};

    final validation = await _validator.validateForTask(
      requested,
      categoryId: effectiveCategoryId,
      suppressedIds: suppressedSet,
    );
    assigned.addAll(validation.valid);
    // Classify invalids: out_of_scope vs unknown/deleted (batch fetch to reduce lookups)
    var outOfScopeCount = 0;
    if (validation.invalid.isNotEmpty) {
      try {
        final db = _db ?? getIt<JournalDb>();
        final allDefs = await db.getAllLabelDefinitions();
        final byId = {for (final d in allDefs) d.id: d};
        for (final id in validation.invalid) {
          final def = byId[id];
          if (def != null && def.deletedAt == null) {
            outOfScopeCount += 1;
            skipped.add({'id': id, 'reason': 'out_of_scope'});
          } else {
            invalid.add(id);
          }
        }
      } catch (e, st) {
        // On lookup error, keep all as invalid and log for diagnostics
        invalid.addAll(validation.invalid);
        _logging.error(
          LogDomain.labels,
          'label_assignment.invalid_classification_failed: $e',
          stackTrace: st,
          subDomain: 'processor',
        );
      }
    }

    // Add suppressed (defense-in-depth) to skipped reasons
    if (validation.suppressed.isNotEmpty) {
      skipped.addAll(
        validation.suppressed.map(
          (id) => <String, String>{'id': id, 'reason': 'suppressed'},
        ),
      );
    }

    // Populate skipped with structured reasons. Priority:
    // 1) already_assigned, 2) over_cap, 3) duplicate
    final skipReasons = <String, String>{};
    for (final id in alreadyAssigned) {
      skipReasons[id] = 'already_assigned';
    }
    for (final id in overCap) {
      skipReasons.putIfAbsent(id, () => 'over_cap');
    }
    for (final id in duplicateIds) {
      skipReasons.putIfAbsent(id, () => 'duplicate');
    }
    skipped.addAll(
      skipReasons.entries.map(
        (e) => <String, String>{'id': e.key, 'reason': e.value},
      ),
    );
    sw.stop();

    // Telemetry payload (Phase 1 schema)
    final telemetry = jsonEncode({
      'taskId': taskId,
      'attempted': requested.length,
      'assigned': assigned.length,
      'invalid': invalid.length,
      'skipped': {
        'out_of_scope': outOfScopeCount,
        'suppressed': validation.suppressed.length,
        'already_assigned': alreadyAssigned.length,
        'over_cap': overCap.length,
        'duplicate': duplicateIds.length,
      },
      'validationMs': sw.elapsedMilliseconds,
      // Phase 2 metrics
      'dropped_low': droppedLow,
      'legacy_capped':
          legacyUsed && (totalCandidates != null && totalCandidates > 3),
      'confidenceBreakdown': ?confidenceBreakdown,
      'phase': 2,
    });
    _logging.log(
      LogDomain.labels,
      telemetry,
      subDomain: 'processor',
    );

    if (assigned.isNotEmpty) {
      await _repository.addLabels(
        journalEntityId: taskId,
        addedLabelIds: assigned,
      );
    }

    return LabelAssignmentResult(
      assigned: assigned,
      invalid: invalid,
      skipped: skipped,
    );
  }
}
