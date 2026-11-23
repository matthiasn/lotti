import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/task_checklist_titles.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:material_ui/material_ui.dart';

/// The task page's `AiSummaryCard.reportTodoAction`: [ReportTodoChecklistAction]
/// for task [taskId].
Widget Function(String text) reportTodoChecklistActionFor(String taskId) =>
    (text) => ReportTodoChecklistAction(taskId: taskId, text: text);

/// Beside an open to-do of a task's agent report: *Add to checklist*, which
/// adds it to the task's checklist, or a quiet mark when the checklist
/// already holds it. Draws nothing until the task has loaded.
class ReportTodoChecklistAction extends ConsumerStatefulWidget {
  const ReportTodoChecklistAction({
    required this.taskId,
    required this.text,
    super.key,
  });

  final String taskId;

  /// The to-do as the report wrote it; inline Markdown is stripped for the
  /// item's title.
  final String text;

  @override
  ConsumerState<ReportTodoChecklistAction> createState() =>
      _ReportTodoChecklistActionState();
}

class _ReportTodoChecklistActionState
    extends ConsumerState<ReportTodoChecklistAction> {
  bool _adding = false;

  Future<void> _add() async {
    final task = ref.read(entryControllerProvider(widget.taskId)).value?.entry;
    if (task is! Task) return;
    setState(() => _adding = true);
    var added = false;
    try {
      added = await addTodoToTaskChecklist(
        ref.read(checklistRepositoryProvider),
        task: task,
        text: widget.text,
      );
    } on Object {
      added = false;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
    // A failed write leaves the button for another try, and says so.
    if (!added && mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.reportTodoAddFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(taskChecklistTitleKeysProvider(widget.taskId));
    if (keys == null) return const SizedBox.shrink();
    final messages = context.messages;
    if (keys.contains(checklistTitleKey(widget.text))) {
      final tokens = context.designTokens;
      return Tooltip(
        message: messages.reportTodoOnChecklist,
        child: Semantics(
          label: messages.reportTodoOnChecklist,
          // As wide as the add button, so marks and buttons share a column.
          child: SizedBox(
            width: TapTargets.minimum,
            child: Icon(
              LottiIcons.checkAll,
              size: IconSizes.s,
              color: tokens.colors.aiCard.metaText,
            ),
          ),
        ),
      );
    }
    return DesignSystemIconAction(
      icon: LottiIcons.addCircled,
      tooltip: messages.reportTodoAddToChecklist,
      isBusy: _adding,
      onPressed: _adding ? null : _add,
    );
  }
}
