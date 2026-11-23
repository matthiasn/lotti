import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/query/query_ask_button.dart';
import 'package:lotti/features/agents/ui/query/query_companion.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_copy.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/features/documents/ui/task_document_history.dart';
import 'package:lotti/features/documents/ui/task_document_labels.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart' show BackWidget;
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown/markdown_title.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the page's controls by.
abstract final class TaskDocumentPageKeys {
  static const edit = Key('task-document-page-edit');
  static const copy = Key('task-document-page-copy');
  static const history = Key('task-document-page-history');
  static const delete = Key('task-document-page-delete');
  static const provenance = Key('task-document-page-provenance');
}

/// One document of a task, for reading (ADR 0166): its title, where the
/// version on show came from, and its text rendered at the prose measure —
/// with Edit, Copy, History and Delete, and Ask, which opens the task's chat
/// beside the document to ask for a revision there.
///
/// The text stays on screen while a newer version loads and is replaced in
/// place ([taskDocumentCurrentVersionProvider]); only the very first load
/// shows nothing. A document deleted while open — here, or on another
/// device — says so instead of its text.
///
/// [onClose] leaves the page: the desktop detail pane passes the action that
/// returns it to the task. Without it, the back arrow pops the page or beams
/// back, as for any page.
class TaskDocumentPage extends ConsumerWidget {
  const TaskDocumentPage({
    required this.taskId,
    required this.documentId,
    this.onClose,
    super.key,
  });

  final String taskId;
  final String documentId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final key = (taskId: taskId, documentId: documentId);
    final document = ref.watch(taskDocumentProvider(key));
    final version = ref.watch(taskDocumentCurrentVersionProvider(key)).value;

    void close() {
      if (onClose != null) {
        onClose!();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    Future<void> delete() async {
      final confirmed = await showConfirmationModal(
        context: context,
        title: messages.taskDocumentsDeleteTitle,
        message: messages.taskDocumentsDeleteMessage,
        confirmLabel: messages.deleteButton,
      );
      if (!confirmed) return;
      await ref.read(taskDocumentRepositoryProvider).delete(documentId);
      if (context.mounted) close();
    }

    return Scaffold(
      // The task's chat docks beside the document, so a revision can be
      // asked for while reading; it is the task's own discussion, the one
      // its page opens, and its proposals carry a Read draft.
      body: QueryCompanion(
        scope: QueryScope(kind: QueryScopeKind.task, id: taskId),
        entryViewBuilder: (entryId) =>
            EntryDetailsPage(itemId: entryId, showBackButton: false),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BackWidget(onPressed: onClose),
                ),
              ),
              Expanded(
                child: document == null
                    ? Center(
                        child: Text(
                          messages.taskDocumentsGone,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      )
                    : _DocumentBody(
                        document: document,
                        version: version,
                        onEdit: () async => showTaskDocumentEditor(
                          context,
                          taskId: taskId,
                          document: document,
                        ),
                        onCopy: version == null
                            ? null
                            : () async => copyTaskDocumentMarkdown(
                                context,
                                version.data.markdown,
                              ),
                        onHistory: version == null
                            ? null
                            : () async => showTaskDocumentHistory(context, key),
                        onDelete: delete,
                        chatScope: QueryScope(
                          kind: QueryScopeKind.task,
                          id: taskId,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({
    required this.document,
    required this.version,
    required this.onEdit,
    required this.onCopy,
    required this.onHistory,
    required this.onDelete,
    required this.chatScope,
  });

  final TaskDocumentEntry document;

  /// The version on show; null before the first one, or while it loads.
  final TaskDocumentVersionEntry? version;
  final VoidCallback onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onHistory;
  final VoidCallback onDelete;

  /// The task's discussion, which the Ask button opens beside the page.
  final QueryScope chatScope;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final version = this.version;
    final hasText = document.data.current != null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step2,
        tokens.spacing.step5,
        tokens.spacing.step7,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            // One measure for header and text, so the title, the rule and
            // the prose share both edges.
            constraints: const BoxConstraints(maxWidth: kProseMeasureWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.data.title,
                        style: tokens.typography.styles.heading.heading2
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    // Apart from the actions that work on the text, so it
                    // never wraps into their row; neutral at rest — the
                    // confirmation it opens carries the warning.
                    DesignSystemIconAction(
                      key: TaskDocumentPageKeys.delete,
                      icon: LottiIcons.delete,
                      tooltip: messages.deleteButton,
                      onPressed: onDelete,
                    ),
                  ],
                ),
                if (version != null) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    taskDocumentVersionLine(
                      messages,
                      version,
                      now: clock.now(),
                    ),
                    key: TaskDocumentPageKeys.provenance,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step4),
                Wrap(
                  spacing: tokens.spacing.step2,
                  runSpacing: tokens.spacing.step2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DesignSystemButton(
                      key: TaskDocumentPageKeys.edit,
                      label: messages.taskDocumentsEditAction,
                      leadingIcon: LottiIcons.edit,
                      onPressed: onEdit,
                    ),
                    DesignSystemButton(
                      key: TaskDocumentPageKeys.copy,
                      label: messages.taskDocumentsCopyAction,
                      leadingIcon: LottiIcons.copy,
                      variant: DesignSystemButtonVariant.tertiary,
                      onPressed: onCopy,
                    ),
                    DesignSystemButton(
                      key: TaskDocumentPageKeys.history,
                      label: messages.taskDocumentsHistory,
                      leadingIcon: LottiIcons.restore,
                      variant: DesignSystemButtonVariant.tertiary,
                      onPressed: onHistory,
                    ),
                  ],
                ),
                // The agent's own control, labelled and in its violet, on a
                // line of its own at every width rather than wherever the
                // actions above happen to wrap.
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step2),
                  child: QueryAskButton(scope: chatScope, inline: true),
                ),
                SizedBox(height: tokens.spacing.step4),
                const DesignSystemDivider(),
                SizedBox(height: tokens.spacing.step5),
                if (!hasText)
                  Text(
                    messages.taskDocumentsNoText,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  )
                else if (version != null)
                  SizedBox(
                    width: double.infinity,
                    child: AgentMarkdownView(
                      withoutRepeatedTitle(
                        version.data.markdown,
                        document.data.title,
                      ),
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
