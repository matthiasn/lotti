import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
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
/// requests (ADR 0166).
///
/// `TaskForm` shows it only while the task holds a document: the "Add" sheet
/// is the way to the first one, so the section never stands empty. Each
/// document is a row with its version and age; tapping it opens the editor,
/// and its Copy action puts the current version's markdown on the
/// clipboard.
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
                  DesignSystemButton(
                    key: TaskDocumentsSectionKeys.add,
                    label: '',
                    semanticsLabel: messages.taskDocumentsNew,
                    variant: DesignSystemButtonVariant.tertiary,
                    leadingIcon: LottiIcons.add,
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
/// was written — or that it has no text yet. Tapping it opens the editor;
/// the Copy action copies the current version's markdown, and is offered
/// only once there is one.
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

    Future<void> copy() async {
      final version = await ref
          .read(taskDocumentRepositoryProvider)
          .currentVersion(document);
      if (version == null) return;
      await Clipboard.setData(ClipboardData(text: version.data.markdown));
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: messages.taskDocumentsCopied,
        duration: const Duration(seconds: 2),
      );
    }

    return DesignSystemListItem(
      key: TaskDocumentsSectionKeys.row(document.id),
      onTap: () async => showTaskDocumentEditor(
        context,
        taskId: taskId,
        document: document,
      ),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      title: document.data.title,
      titleMaxLines: 2,
      subtitle: current == null
          ? messages.taskDocumentsNoText
          : '${messages.taskDocumentsVersion(current.number)} · '
                '${relativeAgeOrDateLabel(messages, at: current.createdAt, now: clock.now())}',
      subtitleEmphasis: tokens.colors.text.lowEmphasis,
      size: DesignSystemListItemSize.small,
      leading: Icon(
        LottiIcons.description,
        size: IconSizes.m,
        color: tokens.colors.text.mediumEmphasis,
      ),
      trailingExtra: current == null
          ? null
          : DesignSystemButton(
              key: TaskDocumentsSectionKeys.copy(document.id),
              label: '',
              semanticsLabel: messages.taskDocumentsCopy,
              variant: DesignSystemButtonVariant.tertiary,
              leadingIcon: LottiIcons.copy,
              onPressed: copy,
            ),
    );
  }
}
