import 'package:lotti/classes/checklist_item_data.dart';
// Barrel file — re-exports all agent test factories from focused files.
//
// Existing imports of `test_utils.dart` continue to work unchanged.
// New tests may import individual factory files from `test_data/` directly
// when only a subset is needed.
export 'test_data/ai_config_factories.dart';
export 'test_data/change_set_factories.dart';
export 'test_data/constants.dart';
export 'test_data/entity_factories.dart';
export 'test_data/evolution_factories.dart';
export 'test_data/feedback_factories.dart';
export 'test_data/ledger_factories.dart';
export 'test_data/link_factories.dart';
export 'test_data/soul_factories.dart';
export 'test_data/template_factories.dart';
export 'test_data/wake_factories.dart';

/// Stable receipt for synthetic checklist approval regressions.
ChecklistItemProvenance makeTestChecklistApproval({
  ChecklistApprovalMode mode = ChecklistApprovalMode.individual,
  bool? isChecked = true,
  String? title,
  bool? isArchived,
}) => ChecklistItemProvenance(
  approvedBy: 'user',
  approvalHost: 'device',
  approvedAt: DateTime.utc(2026, 9, 13, 8, 46),
  approvalMode: mode,
  originatingMessageId: 'question',
  conversationId: 'chat',
  changeSetId: 'query-chat:question:actions',
  decisionId: 'decision',
  agentId: 'agent',
  isChecked: isChecked,
  title: title,
  isArchived: isArchived,
);

/// Checklist item whose current checked state, title and archival are each
/// backed by [makeTestChecklistApproval] receipts when the flag is set.
ChecklistItemData makeTestApprovedChecklistItem({
  String title = 'Walk pressure seals A–F',
  bool isChecked = true,
  bool isArchived = false,
  bool checkedViaChat = true,
  bool titleViaChat = false,
  bool archivedViaChat = false,
}) {
  final approval = makeTestChecklistApproval(isChecked: null);
  return ChecklistItemData(
    title: title,
    isChecked: isChecked,
    isArchived: isArchived,
    linkedChecklists: const ['checklist'],
    checkedBy: checkedViaChat ? ChangeSource.user : ChangeSource.agent,
    checkedAt: checkedViaChat ? approval.approvedAt : null,
    approvalHistory: [
      if (checkedViaChat) approval.copyWith(isChecked: isChecked),
      if (titleViaChat) approval.copyWith(title: title),
      if (archivedViaChat) approval.copyWith(isArchived: isArchived),
    ],
  );
}
