import 'dart:collection';
import 'dart:convert';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class LabelAssignmentResult {
  LabelAssignmentResult({
    required this.assigned,
    required this.invalid,
    required this.skipped,
    this.rateLimited = false,
  });

  factory LabelAssignmentResult.rateLimited() => LabelAssignmentResult(
        assigned: const [],
        invalid: const [],
        skipped: const [],
        rateLimited: true,
      );

  final List<String> assigned;
  final List<String> invalid;
  final List<Map<String, String>> skipped;
  final bool rateLimited;

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
  ) =>
      jsonEncode({
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

class LabelAssignmentProcessor {
  LabelAssignmentProcessor({
    JournalDb? db,
    LabelsRepository? repository,
    LabelAssignmentRateLimiter? rateLimiter,
    LoggingService? logging,
    LabelValidator? validator,
  })  : _repository = repository ?? getIt<LabelsRepository>(),
        _rateLimiter = rateLimiter ?? getIt<LabelAssignmentRateLimiter>(),
        _logging = logging ?? getIt<LoggingService>(),
        _validator = validator ?? LabelValidator(db: db),
        _db = db;

  final LabelsRepository _repository;
  final LabelAssignmentRateLimiter _rateLimiter;
  final LoggingService _logging;
  final LabelValidator _validator;
  final JournalDb? _db;

  Future<LabelAssignmentResult> processAssignment({
    required String taskId,
    required List<String> proposedIds,
    required List<String> existingIds,
    bool shadowMode = false,
    // Optional task context to avoid redundant DB lookups
    String? categoryId,
  }) async {
    // Normalize proposed IDs (trim, drop empties)
    final normalized =
        proposedIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Track duplicates in the original proposal order
    final counts = <String, int>{};
    for (final id in normalized) {
      counts.update(id, (v) => v + 1, ifAbsent: () => 1);
    }
    final duplicateIds =
        counts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

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
          assigned: const [], invalid: const [], skipped: const []);
    }
    if (_rateLimiter.isRateLimited(taskId)) {
      _logging.captureEvent(
        'Rate limited label assignment for task $taskId',
        domain: 'labels_ai_assignment',
        subDomain: 'processor',
      );
      return LabelAssignmentResult.rateLimited();
    }

    final assigned = <String>[];
    final invalid = <String>[];
    final skipped = <Map<String, String>>[];
    final sw = Stopwatch()..start();
    // Determine category for category-scoped validation (Phase 1)
    var effectiveCategoryId = categoryId;
    if (effectiveCategoryId == null) {
      try {
        final db = _db ?? getIt<JournalDb>();
        final entity = await db.journalEntityById(taskId);
        effectiveCategoryId = entity?.meta.categoryId;
      } catch (e, st) {
        // fall back to treating only global labels as valid and log for diagnostics
        _logging.captureException(
          'label_assignment.category_lookup_failed: $e',
          domain: 'labels_ai_assignment',
          subDomain: 'processor',
          stackTrace: st,
        );
        effectiveCategoryId = null;
      }
    }
    final validation = await _validator.validateForCategory(
      requested,
      categoryId: effectiveCategoryId,
    );
    assigned.addAll(validation.valid);
    // Classify invalids: out_of_scope vs unknown/deleted
    var outOfScopeCount = 0;
    for (final id in validation.invalid) {
      try {
        final def =
            await (_db ?? getIt<JournalDb>()).getLabelDefinitionById(id);
        if (def != null && def.deletedAt == null) {
          // Exists but not in scope → skipped with reason
          outOfScopeCount += 1;
          skipped.add({'id': id, 'reason': 'out_of_scope'});
        } else {
          invalid.add(id);
        }
      } catch (_) {
        // On lookup error, keep it as invalid to avoid accidental assignment
        invalid.add(id);
      }
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
      skipReasons.entries
          .map((e) => <String, String>{'id': e.key, 'reason': e.value}),
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
        'already_assigned': alreadyAssigned.length,
        'over_cap': overCap.length,
        'duplicate': duplicateIds.length,
      },
      'validationMs': sw.elapsedMilliseconds,
      'phase': 1,
    });
    _logging.captureEvent(
      telemetry,
      domain: 'labels_ai_assignment',
      subDomain: 'processor',
    );

    if (!shadowMode && assigned.isNotEmpty) {
      await _repository.addLabels(
        journalEntityId: taskId,
        addedLabelIds: assigned,
      );
      _rateLimiter.recordAssignment(taskId);
      // Publish event for UI (toast + undo) when event bus is available
      try {
        if (getIt.isRegistered<LabelAssignmentEventService>()) {
          getIt<LabelAssignmentEventService>().publish(
            LabelAssignmentEvent(taskId: taskId, assignedIds: [...assigned]),
          );
        }
      } catch (_) {
        // ignore publish errors in processor path
      }
    }

    return LabelAssignmentResult(
      assigned: assigned,
      invalid: invalid,
      skipped: skipped,
    );
  }
}
