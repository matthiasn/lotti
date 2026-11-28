import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_copy.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/features/documents/ui/task_document_labels.dart';
import 'package:lotti/features/documents/ui/task_document_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the section's controls by.
abstract final class TaskDocumentsSectionKeys {
  static const title = Key('task-documents-title');
  static const add = Key('task-documents-add');
  static Key row(String documentId) => Key('task-document-row-$documentId');
  static Key copy(String documentId) => Key('task-document-copy-$documentId');
}

/// The task's documents, in their own card below its linked tasks and pull
/// requests (ADR 0167).
///
/// `TaskForm` shows it only while the task holds a document: the "Add" sheet
/// is the way to the first one, so the section never stands empty. Each
/// document is a row with its version and age; tapping it opens the
/// document page, and its Copy action puts the current version's markdown
/// on the clipboard.
class TaskDocumentsSection extends ConsumerWidget {
  const TaskDocumentsSection({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(taskDocumentsProvider(taskId));
    final tokens = context.designTokens;
    final messages = context.messages;
    final inset = DesignSystemListItem.contentInset(
      tokens,
      DesignSystemListItemSize.small,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: DesignSystemSectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              // On the rows' content edges, so the title starts over the row
              // text and the + centres over the rows' copy buttons.
              padding: EdgeInsets.only(
                left: tokens.spacing.step2 + inset,
                right: tokens.spacing.step2 + inset,
                top: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      messages.taskDocumentsTitle,
                      key: TaskDocumentsSectionKeys.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                  ),
                  DesignSystemIconAction(
                    key: TaskDocumentsSectionKeys.add,
                    icon: LottiIcons.add,
                    tooltip: messages.taskDocumentsNew,
                    tone: tokens.colors.interactive.enabled,
                    onPressed: () async =>
                        showTaskDocumentEditor(context, taskId: taskId),
                  ),
                ],
              ),
            ),
            Padding(
              // Inset so each row's rounded hover fill floats inside the
              // card's edge, a hairline between rows — the linked-tasks and
              // pull-request cards' rhythm.
              padding: EdgeInsets.only(
                left: tokens.spacing.step2,
                right: tokens.spacing.step2,
                bottom: tokens.spacing.step2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < documents.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.spacing.step1,
                        ),
                        child: const DesignSystemDivider(),
                      ),
                    TaskDocumentRow(
                      key: ValueKey(documents[i].id),
                      taskId: taskId,
                      document: documents[i],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One document of a task: its title, then its version and how long ago it
/// was written — or that it has no text yet. A version the agent wrote says
/// so ("v3 · Written by the agent · 2 h ago"): the agent writes without
/// asking (ADR 0167), and this line is where the task shows that it did.
/// Tapping the row opens the document page; the Copy action copies the
/// current version's markdown, and is offered only once there is one.
class TaskDocumentRow extends ConsumerWidget {
  const TaskDocumentRow({
    required this.taskId,
    required this.document,
    super.key,
  });

  final String taskId;
  final TaskDocumentEntry document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final current = document.data.current;
    // Read with `.value`: the line a row shows stays while the next version
    // loads.
    final version = ref
        .watch(
          taskDocumentCurrentVersionProvider((
            taskId: taskId,
            documentId: document.id,
          )),
        )
        .value;
    final byAgent =
        version != null &&
        version.id == current?.id &&
        version.data.author == TaskDocumentAuthor.agent;

    Future<void> copy() async {
      final version = await ref
          .read(taskDocumentRepositoryProvider)
          .currentVersion(document);
      if (version == null || !context.mounted) return;
      await copyTaskDocumentMarkdown(context, version.data.markdown);
    }

    return DesignSystemListItem(
      key: TaskDocumentsSectionKeys.row(document.id),
      onTap: () => openTaskDocument(
        context,
        taskId: taskId,
        documentId: document.id,
      ),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      title: document.data.title,
      titleMaxLines: 2,
      subtitle: current == null
          ? messages.taskDocumentsNoText
          : byAgent
          ? taskDocumentVersionLine(messages, version, now: clock.now())
          : '${messages.taskDocumentsVersion(current.number)} · '
                '${relativeAgeOrDateLabel(messages, at: current.createdAt, now: clock.now())}',
      subtitleEmphasis: tokens.colors.text.mediumEmphasis,
      size: DesignSystemListItemSize.small,
      leading: Icon(
        LottiIcons.description,
        size: IconSizes.m,
        color: tokens.colors.text.mediumEmphasis,
      ),
      // Copy is a quiet shortcut beside the row; the chevron, last on every
      // row so they line up, says the row itself opens the document.
      trailing: current == null
          ? null
          : DesignSystemIconAction(
              key: TaskDocumentsSectionKeys.copy(document.id),
              icon: LottiIcons.copy,
              tooltip: messages.taskDocumentsCopy,
              onPressed: copy,
            ),
      trailingExtra: Icon(
        LottiIcons.chevronRight,
        size: IconSizes.m,
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
