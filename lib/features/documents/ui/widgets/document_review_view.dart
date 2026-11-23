import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_row.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the review's controls by.
abstract final class DocumentReviewViewKeys {
  static const close = Key('document-review-close');
  static const confirm = Key('document-review-confirm');
  static const discard = Key('document-review-discard');
  static const ask = Key('document-review-ask');
  static const redo = Key('document-review-redo');
  static const stale = Key('document-review-stale');
  static const newer = Key('document-review-newer');
  static const columnHeads = Key('document-review-column-heads');
}

/// The widest gutter-and-columns row a side-by-side review needs: the
/// gutter mark and its gap, two [kReviewColumnMinWidth] columns and the gap
/// between them. Narrower, the review shows one column.
double documentReviewSideBySideMinWidth(DsTokens tokens) =>
    IconSizes.m +
    tokens.spacing.step2 +
    2 * kReviewColumnMinWidth +
    tokens.spacing.step6;

/// The narrowest pane that shows a review side by side: the two columns
/// with their gutter, and the review's own margins either side. The task
/// split hides its list while a review needs that much more than it leaves.
double documentReviewMinPaneWidth(DsTokens tokens) =>
    documentReviewSideBySideMinWidth(tokens) + 2 * tokens.spacing.step5;

/// A draft of a document under review (ADR 0166, direction B): the version
/// it was written over beside the text it proposes, row by row, with
/// Confirm, Discard draft and Ask for changes on a glass bar.
///
/// Measured, never a window breakpoint: where the content column holds
/// [documentReviewSideBySideMinWidth] the versions stand side by side under
/// their column heads; narrower — a docked chat, a dragged divider — the
/// same rows stack into one column in reading order.
///
/// The rows are pinned ([documentReviewProvider]): nothing that lands while
/// the review is open moves them. A version landing meanwhile makes the
/// draft stale — it would overwrite that version — so Confirm gives way to
/// asking the agent for a fresh draft; a newer draft is offered, not swapped
/// in. Once the draft stops waiting — decided here or on another device —
/// [onClose] returns to the document. Escape closes too.
class DocumentReviewView extends ConsumerStatefulWidget {
  const DocumentReviewView({
    required this.reviewKey,
    required this.title,
    required this.onClose,
    required this.onOpenDraft,
    super.key,
  });

  final DocumentReviewKey reviewKey;

  /// The document's title, for the header.
  final String title;
  final VoidCallback onClose;

  /// Reviews another draft of the same document instead: the newer one.
  final ValueChanged<DocumentReviewKey> onOpenDraft;

  @override
  ConsumerState<DocumentReviewView> createState() => _DocumentReviewViewState();
}

class _DocumentReviewViewState extends ConsumerState<DocumentReviewView> {
  bool _busy = false;

  DocumentReviewKey get _key => widget.reviewKey;

  TaskDocumentKey get _document =>
      (taskId: _key.taskId, documentId: _key.documentId);

  QueryScope get _chatScope =>
      QueryScope(kind: QueryScopeKind.task, id: _key.taskId);

  void _askAgent() =>
      ref.read(queryPaneOpenProvider(_chatScope).notifier).open = true;

  Future<void> _decide(
    DocumentReviewSnapshot snapshot, {
    required bool confirm,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final set = snapshot.proposal.changeSet;
    final index = snapshot.proposal.itemIndex;
    final service = ref.read(changeSetConfirmationServiceProvider);
    try {
      var decided = false;
      if (confirm) {
        final result = await service.confirmItem(set, index);
        decided = result.success;
        if (decided && result.errorMessage != null) {
          messenger.showDesignSystemToast(
            tone: DesignSystemToastTone.warning,
            title: messages.changeSetItemConfirmedWithWarning(
              result.errorMessage!,
            ),
            clearQueue: true,
          );
        }
      } else {
        decided = await service.rejectItem(set, index);
      }
      ref.read(updateNotificationsProvider).notify({set.agentId});
      if (decided) {
        // The draft is no longer waiting; the document shows the outcome.
        if (mounted) widget.onClose();
        return;
      }
      messenger.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: messages.changeSetConfirmError,
        clearQueue: true,
      );
    } catch (error, stackTrace) {
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.agentWorkflow,
            error,
            stackTrace: stackTrace,
            subDomain: 'DocumentReviewView',
            message: confirm ? 'confirmItem failed' : 'rejectItem failed',
          );
      messenger.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: messages.changeSetConfirmError,
        clearQueue: true,
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  /// The newest other draft of this document, if one arrived after this one.
  DocumentReviewKey? _newerDraft(DocumentReviewSnapshot snapshot) {
    final drafts = ref.watch(pendingDocumentProposalsProvider(_document));
    final opened = snapshot.proposal.changeSet.createdAt;
    final newer = [
      for (final draft in drafts ?? const <PendingSuggestion>[])
        if (draft.changeSet.createdAt.isAfter(opened)) draft,
    ]..sort((a, b) => b.changeSet.createdAt.compareTo(a.changeSet.createdAt));
    final newest = newer.firstOrNull;
    if (newest == null) return null;
    return (
      taskId: _key.taskId,
      documentId: _key.documentId,
      changeSetId: newest.changeSet.id,
      itemIndex: newest.itemIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(documentReviewProvider(_key), (previous, next) {
      // Decided or withdrawn elsewhere: back to the document, which shows
      // whatever came of it.
      if (previous != null && next == null) widget.onClose();
    });
    final review = ref.watch(documentReviewProvider(_key));
    // The first load only: once shown, the review stays until it closes.
    if (review == null) return const SizedBox.shrink();
    final snapshot = review.snapshot;
    final tokens = context.designTokens;
    final currentNumber = ref.watch(
      taskDocumentProvider(
        _document,
      ).select((document) => document?.data.current?.number),
    );
    final baseNumber = snapshot.baseVersion?.data.number;
    final proposedNumber = (baseNumber ?? 0) + 1;
    final newer = review.newerProposalAvailable ? _newerDraft(snapshot) : null;
    final horizontal = tokens.spacing.step5; // see documentReviewMinPaneWidth

    return AppCommandScope(
      handlers: {
        AppCommandId.cancel: AppCommandHandler(invoke: (_) => widget.onClose()),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = (constraints.maxWidth - 2 * horizontal).clamp(
              0.0,
              kDetailContentMaxWidth,
            );
            final sideBySide =
                content >= documentReviewSideBySideMinWidth(tokens);
            Widget measure(Widget child) => Center(
              child: SizedBox(width: content, child: child),
            );
            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: measure(
                        _Header(
                          title: widget.title,
                          review: review,
                          baseNumber: baseNumber,
                          currentNumber: currentNumber,
                          onClose: widget.onClose,
                          onOpenNewer: newer == null
                              ? null
                              : () => widget.onOpenDraft(newer),
                        ),
                      ),
                    ),
                    if (sideBySide)
                      SliverToBoxAdapter(
                        child: measure(
                          _ColumnHeads(
                            baseNumber: baseNumber,
                            proposedNumber: review.isStale
                                ? null
                                : proposedNumber,
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        bottom:
                            WoltModalConfig.stickyActionBarClearance +
                            tokens.spacing.step5,
                      ),
                      sliver: SliverList.builder(
                        itemCount: snapshot.pairs.length,
                        // The rows are pinned, so a row's index is its
                        // identity for as long as the review is open.
                        findChildIndexCallback: (key) =>
                            key is ValueKey<int> ? key.value : null,
                        itemBuilder: (context, index) => measure(
                          Padding(
                            key: ValueKey(index),
                            padding: EdgeInsets.only(
                              bottom: tokens.spacing.cardItemSpacing,
                            ),
                            child: ReviewBlockRow(
                              pair: snapshot.pairs[index],
                              baseVersion: baseNumber,
                              proposedVersion: review.isStale
                                  ? null
                                  : proposedNumber,
                              noTextLabel: context.messages.taskDocumentsNoText,
                              stacked: !sideBySide,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: measure(
                    _Bar(
                      stale: review.isStale,
                      busy: _busy,
                      proposedNumber: proposedNumber,
                      onConfirm: () => _decide(snapshot, confirm: true),
                      onDiscard: () => _decide(snapshot, confirm: false),
                      onAsk: _askAgent,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.review,
    required this.baseNumber,
    required this.currentNumber,
    required this.onClose,
    required this.onOpenNewer,
  });

  final String title;
  final DocumentReview review;
  final int? baseNumber;
  final int? currentNumber;
  final VoidCallback onClose;
  final VoidCallback? onOpenNewer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final snapshot = review.snapshot;
    final stats = snapshot.stats;
    final summary = snapshot.changeSummary;
    final currentNumber = this.currentNumber;
    final baseNumber = this.baseNumber;
    final meta = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step2,
        bottom: tokens.spacing.step5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              DesignSystemButton(
                key: DocumentReviewViewKeys.close,
                label: messages.documentReviewClose,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: onClose,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          Semantics(
            label: messages.documentReviewCounts(
              stats.added,
              stats.removed,
              stats.rewritten,
            ),
            child: ExcludeSemantics(
              child: Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                children: [
                  for (final (count, glyph, color) in [
                    (stats.added, '+', tokens.colors.diff.added.color),
                    (stats.removed, '−', tokens.colors.diff.removed.color),
                    (stats.rewritten, '~', tokens.colors.diff.replaced.color),
                  ])
                    if (count > 0)
                      DsPill(
                        variant: DsPillVariant.outline,
                        shape: DsPillShape.tag,
                        color: color,
                        label: '$glyph$count',
                      ),
                ],
              ),
            ),
          ),
          if (summary != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(summary, style: meta),
          ],
          if (review.isStale && currentNumber != null) ...[
            SizedBox(height: tokens.spacing.step3),
            DsPill(
              key: DocumentReviewViewKeys.stale,
              variant: DsPillVariant.tinted,
              shape: DsPillShape.tag,
              color: tokens.colors.alert.warning.defaultColor,
              leading: Icon(
                LottiIcons.warning,
                size: IconSizes.s,
                color: tokens.colors.alert.warning.defaultColor,
              ),
              label: baseNumber == null
                  ? messages.documentReviewStaleNoText(currentNumber)
                  : messages.documentReviewStale(baseNumber, currentNumber),
            ),
          ],
          if (onOpenNewer != null) ...[
            SizedBox(height: tokens.spacing.step2),
            IntrinsicWidth(
              child: DesignSystemInlineAction(
                key: DocumentReviewViewKeys.newer,
                label: messages.documentReviewNewer,
                semanticsLabel: messages.documentReviewNewer,
                leadingIcon: LottiIcons.aiSpark,
                ink: tokens.colors.interactive.enabled,
                onTap: onOpenNewer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Current v3" over the left column and "Proposed v4" over the right, in
/// the gutter's alignment; the proposed head alone takes the agent's violet.
class _ColumnHeads extends StatelessWidget {
  const _ColumnHeads({required this.baseNumber, required this.proposedNumber});

  final int? baseNumber;

  /// Null for a stale draft, which would not become the next version.
  final int? proposedNumber;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final head = tokens.typography.styles.others.caption.copyWith(
      fontWeight: tokens.typography.weight.semiBold,
    );
    final neutral = tokens.colors.text.mediumEmphasis;
    final accent = tokens.colors.aiCard.accent;
    final baseNumber = this.baseNumber;
    final proposedNumber = this.proposedNumber;
    return Padding(
      key: DocumentReviewViewKeys.columnHeads,
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Row(
        children: [
          SizedBox(width: IconSizes.m + tokens.spacing.step2),
          Expanded(
            child: Row(
              children: [
                Text(
                  messages.documentReviewCurrent,
                  style: head.copyWith(color: neutral),
                ),
                if (baseNumber != null) ...[
                  SizedBox(width: tokens.spacing.step2),
                  DsPill(
                    variant: DsPillVariant.outline,
                    shape: DsPillShape.tag,
                    color: neutral,
                    label: messages.taskDocumentsVersion(baseNumber),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step6),
          Expanded(
            child: Row(
              children: [
                Icon(LottiIcons.aiSpark, size: IconSizes.s, color: accent),
                SizedBox(width: tokens.spacing.step1),
                Text(
                  messages.documentReviewProposed,
                  style: head.copyWith(color: accent),
                ),
                if (proposedNumber != null) ...[
                  SizedBox(width: tokens.spacing.step2),
                  DsPill(
                    variant: DsPillVariant.outline,
                    shape: DsPillShape.tag,
                    color: accent,
                    label: messages.taskDocumentsVersion(proposedNumber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The review's verdicts on glass: Confirm vN the one primary, or — for a
/// stale draft, which confirming would let overwrite the newer text —
/// asking the agent to redo it against the current version.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.stale,
    required this.busy,
    required this.proposedNumber,
    required this.onConfirm,
    required this.onDiscard,
    required this.onAsk,
  });

  final bool stale;
  final bool busy;
  final int proposedNumber;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      secondary: [
        DesignSystemButton(
          key: DocumentReviewViewKeys.discard,
          label: messages.documentProposalDiscard,
          variant: DesignSystemButtonVariant.quiet,
          size: DesignSystemButtonSize.large,
          onPressed: busy ? null : onDiscard,
        ),
        // A stale draft's primary already asks the agent.
        if (!stale)
          DesignSystemButton(
            key: DocumentReviewViewKeys.ask,
            label: messages.documentReviewAskForChanges,
            leadingIcon: LottiIcons.chat,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.large,
            onPressed: onAsk,
          ),
      ],
      primary: stale
          ? DesignSystemButton(
              key: DocumentReviewViewKeys.redo,
              label: messages.documentReviewRedo,
              leadingIcon: LottiIcons.chat,
              size: DesignSystemButtonSize.large,
              onPressed: onAsk,
            )
          : DesignSystemButton(
              key: DocumentReviewViewKeys.confirm,
              label: messages.documentReviewConfirm(proposedNumber),
              size: DesignSystemButtonSize.large,
              onPressed: busy ? null : onConfirm,
            ),
    );
  }
}
