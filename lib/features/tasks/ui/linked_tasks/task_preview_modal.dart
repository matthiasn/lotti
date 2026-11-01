import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a glance at task [taskId] — its title, and what its agent last said
/// about it — with a way on to the task itself.
///
/// For a task named from inside another one, such as the target of a
/// suggested link: the reader can see which task is meant without leaving the
/// one they are in. *Open task* closes the preview and opens the task the
/// way a linked task opens ([openLinkedTaskDetail]): stacked over the current
/// one, so Back returns to it.
Future<void> showTaskPreviewModal({
  required BuildContext context,
  required String taskId,
}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    // The task's own title leads the content, so the bar holds nothing but
    // the close button: drawn as a layer it would be an empty band.
    hasTopBarLayer: false,
    // The bar already spaces the title from the edge; the page's own top
    // inset on top of it would float the title away from its close button.
    padding: ModalUtils.defaultPadding(context).copyWith(top: 0),
    builder: (modalContext) => TaskPreviewContent(
      taskId: taskId,
      onOpenTask: () {
        Navigator.of(modalContext).pop();
        if (context.mounted) {
          openLinkedTaskDetail(context: context, taskId: taskId);
        }
      },
    ),
  );
}

/// The body of [showTaskPreviewModal].
///
/// The title leads; the agent's one-liner and TL;DR follow, or — before any
/// report exists — the task's own notes, so a task never previews as blank
/// when it has something to say.
class TaskPreviewContent extends ConsumerWidget {
  const TaskPreviewContent({
    required this.taskId,
    required this.onOpenTask,
    super.key,
  });

  final String taskId;
  final VoidCallback onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final preview = ref.watch(taskPreviewProvider(taskId));
    return preview.when(
      skipLoadingOnReload: true,
      loading: () => Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: const Center(child: DesignSystemSpinner()),
      ),
      // A preview that cannot be read offers the task anyway: opening it is
      // what the reader came for.
      error: (_, _) => _OpenTaskButton(onPressed: onOpenTask),
      data: (preview) => preview == null
          ? const SizedBox.shrink()
          : _PreviewBody(preview: preview, onOpenTask: onOpenTask),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.preview, required this.onOpenTask});

  final TaskPreview preview;
  final VoidCallback onOpenTask;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final colors = tokens.colors.text;
    final summary = preview.tldr ?? preview.notes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          preview.task.data.title,
          style: styles.heading.heading3.copyWith(color: colors.highEmphasis),
        ),
        if (preview.oneLiner case final oneLiner?) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            oneLiner,
            style: styles.subtitle.subtitle2.copyWith(
              color: colors.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        if (summary != null)
          AgentMarkdownView(
            summary,
            style: styles.body.bodyMedium.copyWith(color: colors.highEmphasis),
          )
        else
          Text(
            context.messages.taskPreviewNoSummary,
            style: styles.body.bodyMedium.copyWith(
              color: colors.mediumEmphasis,
            ),
          ),
        SizedBox(height: tokens.spacing.step6),
        _OpenTaskButton(onPressed: onOpenTask),
      ],
    );
  }
}

class _OpenTaskButton extends StatelessWidget {
  const _OpenTaskButton({required this.onPressed});

  final VoidCallback onPressed;

  /// Its own width, at the trailing edge: the task's title is what the
  /// preview is about, and a full-width button would outweigh it.
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: DesignSystemButton(
      label: context.messages.taskPreviewOpenTask,
      size: DesignSystemButtonSize.medium,
      onPressed: onPressed,
    ),
  );
}
