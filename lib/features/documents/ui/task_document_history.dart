import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_labels.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown/markdown_title.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the history's controls by.
abstract final class TaskDocumentHistoryKeys {
  static Key row(String versionId) => Key('task-document-version-$versionId');
  static const restore = Key('task-document-version-restore');
  static const current = Key('task-document-version-current');
}

/// Lists every version of the document [key] names, newest first, the
/// current one marked. Opening one shows its text, and an older one can be
/// restored from there.
Future<void> showTaskDocumentHistory(
  BuildContext context,
  TaskDocumentKey key,
) => ModalUtils.showSinglePageModal<void>(
  context: context,
  title: context.messages.taskDocumentsHistory,
  builder: (_) => TaskDocumentHistory(documentKey: key),
);

/// The versions of a document, newest first: each one's number, who wrote it
/// and how long ago, the one the document shows marked as current. The list
/// follows the document, so a restore — or a version that lands by sync —
/// joins it at the top without a reload.
class TaskDocumentHistory extends ConsumerWidget {
  const TaskDocumentHistory({required this.documentKey, super.key});

  final TaskDocumentKey documentKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final versions =
        ref.watch(taskDocumentVersionsProvider(documentKey)).value ?? const [];
    final currentId = ref
        .watch(taskDocumentProvider(documentKey))
        ?.data
        .current
        ?.id;
    final now = clock.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final version in versions)
          DesignSystemListItem(
            key: TaskDocumentHistoryKeys.row(version.id),
            onTap: () async => showTaskDocumentVersion(
              context,
              documentKey,
              version,
              isCurrent: version.id == currentId,
            ),
            borderRadius: BorderRadius.circular(tokens.radii.m),
            // Which and when lead; who wrote it is the line under them.
            title:
                '${messages.taskDocumentsVersion(version.data.number)} · '
                '${relativeAgeOrDateLabel(messages, at: version.meta.createdAt, now: now)}',
            subtitle: taskDocumentAuthorship(messages, version),
            subtitleEmphasis: tokens.colors.text.mediumEmphasis,
            // Who and when wrap rather than lose the date beside a pill.
            subtitleMaxLines: 2,
            size: DesignSystemListItemSize.small,
            // The version on show is marked, not just named in the title.
            trailing: version.id == currentId
                ? DsPill(
                    key: TaskDocumentHistoryKeys.current,
                    variant: DsPillVariant.outline,
                    shape: DsPillShape.tag,
                    color: tokens.colors.text.mediumEmphasis,
                    label: messages.taskDocumentsCurrent,
                  )
                : null,
            // Last on every row, so the chevrons line up.
            trailingExtra: Icon(
              LottiIcons.chevronRight,
              size: IconSizes.m,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
      ],
    );
  }
}

/// Shows [version]'s text, with a way to restore it when it is not the one
/// the document shows ([isCurrent]).
Future<void> showTaskDocumentVersion(
  BuildContext context,
  TaskDocumentKey key,
  TaskDocumentVersionEntry version, {
  required bool isCurrent,
}) => ModalUtils.showSinglePageModal<void>(
  context: context,
  // Which document, then which version: a bare "v1" says neither alone.
  title: switch (ProviderScope.containerOf(
    context,
    listen: false,
  ).read(taskDocumentProvider(key))?.data.title) {
    final String title =>
      '$title · ${context.messages.taskDocumentsVersion(version.data.number)}',
    null => context.messages.taskDocumentsVersion(version.data.number),
  },
  padding: EdgeInsets.all(context.designTokens.spacing.step5),
  builder: (_) => TaskDocumentVersionView(
    documentKey: key,
    version: version,
    isCurrent: isCurrent,
  ),
);

/// One version's text, and — for an older one — Restore, which writes that
/// text as the next version by the user (`TaskDocumentRepository.restore`),
/// over the version the document shows now. A version that landed meanwhile
/// refuses the restore, and the user is told to look again.
class TaskDocumentVersionView extends ConsumerWidget {
  const TaskDocumentVersionView({
    required this.documentKey,
    required this.version,
    required this.isCurrent,
    super.key,
  });

  final TaskDocumentKey documentKey;
  final TaskDocumentVersionEntry version;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    Future<void> restore() async {
      final document = ref.read(taskDocumentProvider(documentKey));
      final result = await ref
          .read(taskDocumentRepositoryProvider)
          .restore(
            versionId: version.id,
            baseVersionId: document?.data.current?.id,
          );
      if (!context.mounted) return;
      final written = result.status == TaskDocumentWriteStatus.written;
      context.showToast(
        tone: written
            ? DesignSystemToastTone.success
            : DesignSystemToastTone.error,
        title: switch (result.status) {
          TaskDocumentWriteStatus.written => messages.taskDocumentsRestored,
          TaskDocumentWriteStatus.stale => messages.taskDocumentsRestoreStale,
          TaskDocumentWriteStatus.missing ||
          TaskDocumentWriteStatus.failed => messages.saveFailedRetry,
        },
        duration: const Duration(seconds: 3),
      );
      // Back past the version view and the History sheet under it, onto the
      // page, which now shows the restored text and its provenance.
      if (written) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // The sheet's title already names the version.
          '${taskDocumentAuthorship(messages, version)} · '
          '${relativeAgeOrDateLabel(messages, at: version.meta.createdAt, now: clock.now())}',
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        AgentMarkdownView(
          withoutRepeatedTitle(
            version.data.markdown,
            ref.watch(taskDocumentProvider(documentKey))?.data.title,
          ),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        if (!isCurrent) ...[
          SizedBox(height: tokens.spacing.step5),
          Align(
            alignment: Alignment.centerRight,
            child: DesignSystemButton(
              key: TaskDocumentHistoryKeys.restore,
              label: messages.taskDocumentsRestore,
              leadingIcon: LottiIcons.restore,
              onPressed: restore,
            ),
          ),
        ],
      ],
    );
  }
}
