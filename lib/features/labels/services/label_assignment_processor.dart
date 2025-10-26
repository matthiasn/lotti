import 'dart:collection';
import 'dart:convert';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
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
  })  : _db = db ?? getIt<JournalDb>(),
        _repository = repository ?? getIt<LabelsRepository>(),
        _rateLimiter = rateLimiter ?? getIt<LabelAssignmentRateLimiter>(),
        _logging = logging ?? getIt<LoggingService>();

  final JournalDb _db;
  final LabelsRepository _repository;
  final LabelAssignmentRateLimiter _rateLimiter;
  final LoggingService _logging;

  Future<LabelAssignmentResult> processAssignment({
    required String taskId,
    required List<String> proposedIds,
    required List<String> existingIds,
    bool shadowMode = false,
  }) async {
    final requested = LinkedHashSet<String>.from(
      proposedIds.where((e) => e.isNotEmpty),
    ).take(kMaxLabelsPerAssignment).toList();
    if (requested.isEmpty) {
      return LabelAssignmentResult(
          assigned: const [], invalid: const [], skipped: const []);
    }
// End of file
    if (_rateLimiter.isRateLimited(taskId)) {
      _logging.captureEvent(
        'Rate limited label assignment for task $taskId',
        domain: 'labels_ai_assignment',
        subDomain: 'processor',
      );
      return LabelAssignmentResult.rateLimited();
    }

    // Build existing group occupancy from current task
    final existingGroups = <String, String>{}; // groupId -> labelId
    if (existingIds.isNotEmpty) {
      final existingDefs = await Future.wait(
        existingIds.map(_db.getLabelDefinitionById),
      );
      for (final def in existingDefs) {
        final gid = def?.groupId;
        final id = def?.id;
        if (gid != null && id != null) {
          existingGroups.putIfAbsent(gid, () => id);
        }
      }
    }

    final assigned = <String>[];
    final invalid = <String>[];
    final skipped = <Map<String, String>>[];
    final seenGroups = <String>{};

    for (final id in requested) {
      final def = await _db.getLabelDefinitionById(id);
      if (def == null || def.deletedAt != null) {
        invalid.add(id);
        continue;
      }
      final gid = def.groupId;
      if (gid != null) {
        if (existingGroups.containsKey(gid) || seenGroups.contains(gid)) {
          skipped.add({'id': id, 'reason': 'group_exclusivity'});
          continue;
        }
        seenGroups.add(gid);
      }
      assigned.add(id);
    }

    _logging.captureEvent(
      'Assignment attempt task=$taskId attempted=${requested.length} assigned=${assigned.length} invalid=${invalid.length} skipped=${skipped.length}',
      domain: 'labels_ai_assignment',
      subDomain: 'processor',
    );

    if (!shadowMode && assigned.isNotEmpty) {
      await _repository.addLabels(
        journalEntityId: taskId,
        addedLabelIds: assigned,
      );
      _rateLimiter.recordAssignment(taskId);
    }

    return LabelAssignmentResult(
      assigned: assigned,
      invalid: invalid,
      skipped: skipped,
    );
  }
}
