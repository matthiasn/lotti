import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_card_ports.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/tasks/state/checklist_completion_controller.dart';

/// The tasks feature's completion counts behind
/// `journalChecklistCountsProvider`.
Future<JournalChecklistCounts?> checklistCountsFromTasks(
  Ref ref,
  String checklistId,
) => ref.watch(
  checklistCompletionControllerProvider((id: checklistId, taskId: null)).future,
);

/// The relationships feature's name lookup behind
/// `journalRelationshipNameProvider`.
Future<String?> relationshipNameFromRelationships(
  Ref ref,
  String relationshipId,
) => ref.watch(relationshipNameProvider(relationshipId).future);
