import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The "Add" sheet's row that writes a new document on task [taskId]: it
/// closes the sheet and opens the document editor. The task's Documents
/// section appears with the first document, so this row is the way to it.
class NewDocumentItem extends StatelessWidget {
  const NewDocumentItem(this.taskId, {super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return DsActionRow(
      tone: DsActionRowTone.accent,
      icon: LottiIcons.description,
      title: context.messages.taskDocumentsAddAction,
      subtitle: context.messages.taskDocumentsAddActionHint,
      // Chevron, not plus: the row opens the editor rather than adding in
      // place.
      trailing: DsActionRowTrailing.chevron,
      onTap: () async {
        Navigator.of(context).pop();
        await showTaskDocumentEditor(context, taskId: taskId);
      },
    );
  }
}

/// The documents feature's create-entry action for a task (wired into
/// `JournalDetailSlots.taskCreateActions`): always offered, since a task
/// can hold any number of documents.
Widget? newDocumentAction(WidgetRef ref, String taskId) =>
    NewDocumentItem(taskId);
