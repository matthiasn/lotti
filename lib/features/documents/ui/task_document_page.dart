import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/query/query_ask_button.dart';
import 'package:lotti/features/agents/ui/query/query_companion.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_copy.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/features/documents/ui/task_document_history.dart';
import 'package:lotti/features/documents/ui/task_document_labels.dart';
import 'package:lotti/features/documents/ui/widgets/document_review_view.dart';
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
  static const review = Key('task-document-page-review');
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
class TaskDocumentPage extends ConsumerStatefulWidget {
  const TaskDocumentPage({
    required this.taskId,
    required this.documentId,
    this.onClose,
    this.initialReview,
    this.onInitialReviewOpened,
    super.key,
  });

  final String taskId;
  final String documentId;
  final VoidCallback? onClose;

  /// A draft of this document to open for review as the page appears, or
  /// when a later link asks for it — the review route's. Ignored when it
  /// names another document.
  final DocumentReviewKey? initialReview;

  /// Called once [initialReview] is open, so whoever asked can forget it.
  final VoidCallback? onInitialReviewOpened;

  @override
  ConsumerState<TaskDocumentPage> createState() => _TaskDocumentPageState();
}

class _TaskDocumentPageState extends ConsumerState<TaskDocumentPage> {
  @override
  void initState() {
    super.initState();
    _openInitialReview();
  }

  @override
  void didUpdateWidget(TaskDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialReview != oldWidget.initialReview) _openInitialReview();
  }

  void _openInitialReview() {
    final draft = widget.initialReview;
    if (draft == null ||
        draft.taskId != widget.taskId ||
        draft.documentId != widget.documentId) {
      return;
    }
    // After the frame: opening it rebuilds this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(documentReviewOpenProvider(widget.taskId).notifier).open(draft);
      widget.onInitialReviewOpened?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.taskId;
    final documentId = widget.documentId;
    final onClose = widget.onClose;
    final tokens = context.designTokens;
    final messages = context.messages;
    final key = (taskId: taskId, documentId: documentId);
    final document = ref.watch(taskDocumentProvider(key));
    final version = ref.watch(taskDocumentCurrentVersionProvider(key)).value;
    final drafts = ref.watch(pendingDocumentProposalsProvider(key));
    // The newest draft waiting for this document, which the notice opens.
    final waiting = drafts?.fold<PendingSuggestion?>(
      null,
      (newest, draft) =>
          newest == null ||
              draft.changeSet.createdAt.isAfter(
                newest.changeSet.createdAt,
              )
          ? draft
          : newest,
    );
    final review = ref.read(documentReviewOpenProvider(taskId).notifier);
    final open = ref.watch(documentReviewOpenProvider(taskId));
    final reviewing = open?.documentId == documentId ? open : null;
    // A review whose draft stopped waiting while the page was away, or whose
    // document is gone, is over: the page reads, and the panes that stepped
    // aside for it come back.
    final over =
        reviewing != null &&
        (document == null ||
            (drafts != null &&
                !drafts.any(
                  (draft) =>
                      draft.changeSet.id == reviewing.changeSetId &&
                      draft.itemIndex == reviewing.itemIndex,
                )));
    if (over) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(documentReviewOpenProvider(taskId)) == reviewing) {
          review.close();
        }
      });
    }

    void close() {
      if (onClose != null) {
        onClose();
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

    final showingReview = reviewing != null && !over && document != null;

    // While reviewing, back — the arrow, the system back, the iOS swipe —
    // closes the review onto the text instead of leaving the document with
    // the decision open.
    return PopScope<void>(
      canPop: !showingReview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showingReview) review.close();
      },
      child: Scaffold(
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
                    child: BackWidget(
                      onPressed: showingReview ? review.close : onClose,
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : MotionDurations.short4,
                    switchInCurve: MotionCurves.standard,
                    switchOutCurve: MotionCurves.standard,
                    child: showingReview
                        ? DocumentReviewView(
                            key: ValueKey(reviewing),
                            reviewKey: reviewing,
                            title: document.data.title,
                            onClose: review.close,
                            onOpenDraft: review.open,
                          )
                        : document == null
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
                                : () async =>
                                      showTaskDocumentHistory(context, key),
                            onDelete: delete,
                            chatScope: QueryScope(
                              kind: QueryScopeKind.task,
                              id: taskId,
                            ),
                            reviewOutOfDate:
                                waiting != null &&
                                waiting.item.args['baseVersionId'] !=
                                    document.data.current?.id,
                            onReview: waiting == null
                                ? null
                                : () => review.open((
                                    taskId: taskId,
                                    documentId: documentId,
                                    changeSetId: waiting.changeSet.id,
                                    itemIndex: waiting.itemIndex,
                                  )),
                          ),
                  ),
                ),
              ],
            ),
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
    required this.onReview,
    required this.reviewOutOfDate,
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

  /// Opens the agent's waiting draft of this document for review; null when
  /// none waits.
  final VoidCallback? onReview;

  /// The waiting draft was written over an older version than the one
  /// shown.
  final bool reviewOutOfDate;

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
                // A waiting draft comes before the actions: editing now
                // would leave it stale, so reviewing it is the first thing
                // to do, and the one filled button while it waits.
                if (onReview != null) ...[
                  SizedBox(height: tokens.spacing.step4),
                  SizedBox(
                    width: double.infinity,
                    child: _DraftWaitingNotice(
                      onReview: onReview!,
                      outOfDate: reviewOutOfDate,
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
                      variant: onReview == null
                          ? DesignSystemButtonVariant.primary
                          : DesignSystemButtonVariant.tertiary,
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

/// The agent's draft of a new version, waiting: a status on the agent's own
/// card surface — violet on its spark alone — with the button that lays the
/// draft beside the current text.
class _DraftWaitingNotice extends StatelessWidget {
  const _DraftWaitingNotice({required this.onReview, required this.outOfDate});

  final VoidCallback onReview;

  /// The draft was written over a version the document no longer shows; it
  /// says so before the review does.
  final bool outOfDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final ai = tokens.colors.aiCard;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ai.background,
        border: Border.all(color: ai.border),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Wrap(
          spacing: tokens.spacing.step4,
          runSpacing: tokens.spacing.step3,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  outOfDate ? LottiIcons.warning : LottiIcons.aiSpark,
                  size: IconSizes.m,
                  color: outOfDate
                      ? tokens.colors.alert.warning.defaultColor
                      : ai.accent,
                ),
                SizedBox(width: tokens.spacing.step2),
                Flexible(
                  child: Text(
                    outOfDate
                        ? messages.documentReviewWaitingStale
                        : messages.documentReviewWaiting,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ],
            ),
            DesignSystemButton(
              key: TaskDocumentPageKeys.review,
              label: messages.documentReviewOpen,
              onPressed: onReview,
            ),
          ],
        ),
      ),
    );
  }
}
