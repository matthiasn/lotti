import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The modal host for [TaskMetaSection].
///
/// The fall-back surface: on a phone, in a narrow pane, and anywhere the
/// persistent details column (`TaskMetaColumn`) cannot fit, this is where the
/// task's metadata is read and edited. Where the column *is* mounted the
/// header drops its "Details" trigger rather than offering the same content
/// twice.
abstract final class TaskMetaFlyout {
  /// Opens the fly-out for [taskId] near the header ("Details" affordance).
  ///
  /// Closes itself when the status picker returns a choice — any choice, a
  /// re-pick of the current status included, because the reader has finished
  /// with the panel either way and a selection that visibly does nothing
  /// reads as a dead tap. The status write plays the completion celebration
  /// on the header's status pill, directly behind this panel, and a reader
  /// who has just marked a task Done should see that rather than a scrim over
  /// it.
  ///
  /// Both shapes this modal takes close: the dialog on a wide window, where
  /// the scrim covers the whole celebration, and the bottom sheet on a phone,
  /// where it covers less but the rule is worth more than the exception.
  static Future<void> show(BuildContext context, {required String taskId}) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.taskMetaSheetTitle,
      builder: (modalContext) => TaskMetaSection(
        taskId: taskId,
        // The status picker has already popped by the time this runs, so the
        // fly-out is the top route and `pop` closes it and nothing else.
        onStatusPicked: () {
          if (modalContext.mounted) Navigator.of(modalContext).pop();
        },
      ),
    );
  }
}
