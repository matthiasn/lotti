import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The modal host for [TaskMetaSection].
///
/// The fall-back surface: on a phone, in a narrow pane, and anywhere the
/// persistent details column (`TaskMetaColumn`) cannot fit, this is where the
/// task's metadata is read and edited. Where the column *is* mounted the
/// header drops its "Details" trigger rather than offering the same content
/// twice.
abstract final class TaskMetaFlyout {
  /// Opens the fly-out for [taskId] near the header ("Details" affordance).
  static Future<void> show(BuildContext context, {required String taskId}) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.taskMetaSheetTitle,
      builder: (_) => TaskMetaSection(taskId: taskId),
    );
  }
}
