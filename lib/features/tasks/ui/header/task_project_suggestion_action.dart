import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_project_suggestion_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:material_ui/material_ui.dart';

/// The proactive project suggestion for a task without a project: an
/// "Add to {project}?" offer beside the crumb's "No project", and a dismiss
/// control next to it.
///
/// One tap on the offer files the task under the project; one tap on the
/// dismiss control records that the task does not belong there, so the same
/// project is never offered for it again. Renders nothing while there is no
/// suggestion, which is the state of every task that already has a project.
///
/// Either tap hides the offer at once rather than waiting for the provider to
/// recompute: its reload keeps the previous value on screen, and an offer
/// that lingers after "no" reads as ignored.
class TaskProjectSuggestionAction extends ConsumerStatefulWidget {
  const TaskProjectSuggestionAction({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<TaskProjectSuggestionAction> createState() =>
      _TaskProjectSuggestionActionState();
}

class _TaskProjectSuggestionActionState
    extends ConsumerState<TaskProjectSuggestionAction> {
  /// The project whose offer was just accepted or dismissed — hidden until
  /// the provider stops proposing it, or brought back if an accept failed.
  String? _settledProjectId;

  @override
  Widget build(BuildContext context) {
    // `.value`: a background recompute keeps the established offer instead
    // of blinking it out and back in.
    final suggestion = ref
        .watch(taskProjectSuggestionProvider(widget.taskId))
        .value;
    // Held while the offer can be dismissed, so a dismissal lands in a live
    // provider rather than one created for the tap and disposed mid-write.
    ref.watch(taskProjectSuggestionDismissalsProvider(widget.taskId));
    if (suggestion == null || suggestion.projectId == _settledProjectId) {
      return const SizedBox.shrink();
    }

    final messages = context.messages;
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          // The inline action aligns itself across all the width it is
          // offered; sized to its content instead, the dismiss control sits
          // right after the label rather than at the far end of the crumb,
          // and the label still ellipsizes when the crumb runs out of room.
          child: IntrinsicWidth(
            child: DesignSystemInlineAction(
              onTap: () => _accept(suggestion),
              leadingIcon: LottiIcons.folder,
              iconInk: tokens.colors.interactive.enabled,
              label: messages.taskProjectSuggestionAccept(
                suggestion.projectTitle,
              ),
              tooltip: messages.taskProjectSuggestionTooltip,
              semanticsLabel: messages.taskProjectSuggestionSemantics(
                suggestion.projectTitle,
              ),
            ),
          ),
        ),
        DesignSystemIconAction(
          icon: LottiIcons.close,
          tooltip: messages.taskProjectSuggestionDismiss,
          onPressed: () => _dismiss(suggestion),
        ),
      ],
    );
  }

  Future<void> _accept(TaskProjectSuggestion suggestion) async {
    setState(() => _settledProjectId = suggestion.projectId);
    bool linked;
    try {
      linked = await ref
          .read(projectRepositoryProvider)
          .linkUnassignedTaskToProject(
            projectId: suggestion.projectId,
            taskId: widget.taskId,
          );
    } catch (_) {
      linked = false;
    }
    if (linked || !mounted) return;
    // The write was refused — since the suggestion was computed, the task
    // changed category or privacy, or another device filed it under a
    // project, which an offer to *add* it must not undo. Say so, and give
    // the offer back.
    setState(() => _settledProjectId = null);
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.projectPickerUpdateFailed,
    );
  }

  Future<void> _dismiss(TaskProjectSuggestion suggestion) async {
    setState(() => _settledProjectId = suggestion.projectId);
    await ref
        .read(taskProjectSuggestionDismissalsProvider(widget.taskId).notifier)
        .dismiss(suggestion.projectId);
  }
}
