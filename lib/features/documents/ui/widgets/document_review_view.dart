import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
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
import 'package:lotti/widgets/markdown/markdown_title.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
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
  static const openNewer = Key('document-review-open-newer');
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

  /// Discard draft, once the user says so: there is no undo yet, and the
  /// draft is the agent's work.
  Future<void> _discard(DocumentReviewSnapshot snapshot) async {
    final messages = context.messages;
    final sure = await showConfirmationModal(
      context: context,
      title: messages.documentReviewDiscardTitle,
      message: messages.documentReviewDiscardMessage,
      confirmLabel: messages.documentProposalDiscard,
    );
    if (sure && mounted) await _decide(snapshot, confirm: false);
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
    final pairs = _withoutTitleRow(snapshot.pairs, widget.title);
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
                          compact: !sideBySide,
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
                    // Pinned: however far the rows scroll, it stays clear
                    // which side is which.
                    if (sideBySide)
                      PinnedHeaderSliver(
                        child: ColoredBox(
                          color: tokens.colors.background.level01,
                          child: measure(
                            _ColumnHeads(
                              stale: review.isStale,
                              baseNumber: baseNumber,
                              proposedNumber: review.isStale
                                  ? null
                                  : proposedNumber,
                            ),
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
                        itemCount: pairs.length,
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
                              pair: pairs[index],
                              baseVersion: baseNumber,
                              proposedVersion: review.isStale
                                  ? null
                                  : proposedNumber,
                              noTextLabel: context.messages.taskDocumentsNoText,
                              stacked: !sideBySide,
                              stale: review.isStale,
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
                  // The glass spans the pane; its buttons keep to the
                  // column, Discard on the rows' text edge.
                  child: _Bar(
                    inset: EdgeInsets.only(
                      left:
                          (constraints.maxWidth - content) / 2 +
                          (sideBySide ? IconSizes.m + tokens.spacing.step2 : 0),
                      right: (constraints.maxWidth - content) / 2,
                    ),
                    compact: !sideBySide,
                    stale: review.isStale,
                    onOpenNewer: newer == null
                        ? null
                        : () => widget.onOpenDraft(newer),
                    busy: _busy,
                    proposedNumber: proposedNumber,
                    onConfirm: () => _decide(snapshot, confirm: true),
                    onDiscard: () => _discard(snapshot),
                    onAsk: _askAgent,
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
    required this.compact,
    required this.title,
    required this.review,
    required this.baseNumber,
    required this.currentNumber,
    required this.onClose,
    required this.onOpenNewer,
  });

  /// A narrow pane: Close review is an icon, so the title keeps the line.
  final bool compact;
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
    final accent = tokens.colors.aiCard.accent;
    final warning = tokens.colors.alert.warning.defaultColor;
    final diff = tokens.colors.diff;
    final gap = SizedBox(height: tokens.spacing.step3);
    // Title, then what would stop a confirm, then the agent's own line on
    // the draft, then the counts the rows bear out.
    return Padding(
      // The header stands apart from the table it introduces.
      padding: EdgeInsets.only(
        top: tokens.spacing.step2,
        bottom: tokens.spacing.step6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: tokens.typography.styles.heading.heading2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              if (compact)
                DesignSystemIconAction(
                  key: DocumentReviewViewKeys.close,
                  icon: LottiIcons.close,
                  tooltip: messages.documentReviewClose,
                  onPressed: onClose,
                )
              else
                DesignSystemButton(
                  key: DocumentReviewViewKeys.close,
                  label: messages.documentReviewClose,
                  variant: DesignSystemButtonVariant.tertiary,
                  onPressed: onClose,
                ),
            ],
          ),
          if (review.isStale && currentNumber != null) ...[
            gap,
            // The one message that stops a confirm: a line that wraps, never
            // a tag that clips.
            _HeaderLine(
              key: DocumentReviewViewKeys.stale,
              icon: LottiIcons.warning,
              iconColor: warning,
              text: baseNumber == null
                  ? messages.documentReviewStaleNoText(currentNumber)
                  : messages.documentReviewStale(baseNumber, currentNumber),
              // The warning hue on the glyph, the sentence in plain ink — the
              // design system's alert grammar.
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ],
          if (summary != null) ...[
            gap,
            _HeaderLine(
              icon: LottiIcons.aiSpark,
              iconColor: accent,
              text: summary,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step2),
          // On the text edge, under the lines above.
          Padding(
            padding: EdgeInsets.only(
              left:
                  IconSizes.m +
                  tokens.spacing.step2 +
                  tokens.spacing.cardItemSpacing,
            ),
            child: Semantics(
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
                    // The gutter's own marks, so a count and its rows match.
                    for (final (count, icon, color) in [
                      (stats.added, LottiIcons.add, diff.added.color),
                      (stats.removed, LottiIcons.remove, diff.removed.color),
                      (
                        stats.rewritten,
                        LottiIcons.compare,
                        diff.replaced.color,
                      ),
                    ])
                      if (count > 0)
                        DsPill(
                          variant: DsPillVariant.tinted,
                          shape: DsPillShape.tag,
                          color: color,
                          leading: Icon(icon, size: IconSizes.s, color: color),
                          label: '$count',
                          labelColor: tokens.colors.text.highEmphasis,
                        ),
                  ],
                ),
              ),
            ),
          ),
          // A stale draft's bar already offers it as the primary.
          if (onOpenNewer != null && !review.isStale) ...[
            gap,
            Padding(
              padding: EdgeInsets.only(
                left:
                    IconSizes.m +
                    tokens.spacing.step2 +
                    tokens.spacing.cardItemSpacing,
              ),
              child: IntrinsicWidth(
                child: DesignSystemInlineAction(
                  key: DocumentReviewViewKeys.newer,
                  label: messages.documentReviewNewer,
                  semanticsLabel: messages.documentReviewNewer,
                  leadingIcon: LottiIcons.aiSpark,
                  // The agent's own action, in its voice.
                  ink: accent,
                  onTap: onOpenNewer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Current v3" over the left column and "Proposed v4" over the right, on
/// the rows' text edge; the proposed head alone takes the agent's violet.
/// For a stale draft the left column is not the current text but the
/// version the draft was written over, and its head says so in the
/// warning's colour.
class _ColumnHeads extends StatelessWidget {
  const _ColumnHeads({
    required this.stale,
    required this.baseNumber,
    required this.proposedNumber,
  });

  final bool stale;
  final int? baseNumber;

  /// Null for a stale draft, which would not become the next version.
  final int? proposedNumber;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final head = tokens.typography.styles.subtitle.subtitle2;
    final neutral = tokens.colors.text.mediumEmphasis;
    final accent = tokens.colors.aiCard.accent;
    final baseInk = stale ? tokens.colors.alert.warning.defaultColor : neutral;
    final textEdge = EdgeInsets.only(left: tokens.spacing.cardItemSpacing);
    final baseNumber = this.baseNumber;
    final proposedNumber = this.proposedNumber;
    return Padding(
      key: DocumentReviewViewKeys.columnHeads,
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Row(
        children: [
          SizedBox(width: IconSizes.m + tokens.spacing.step2),
          Expanded(
            child: Padding(
              padding: textEdge,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      stale
                          ? messages.documentReviewBase
                          : messages.documentReviewCurrent,
                      overflow: TextOverflow.ellipsis,
                      style: head.copyWith(color: baseInk),
                    ),
                  ),
                  if (baseNumber != null) ...[
                    SizedBox(width: tokens.spacing.step2),
                    DsPill(
                      variant: DsPillVariant.outline,
                      shape: DsPillShape.tag,
                      color: baseInk,
                      label: messages.taskDocumentsVersion(baseNumber),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step6),
          Expanded(
            child: Padding(
              padding: textEdge,
              child: Row(
                children: [
                  Icon(LottiIcons.aiSpark, size: IconSizes.s, color: accent),
                  SizedBox(width: tokens.spacing.step1),
                  Flexible(
                    child: Text(
                      messages.documentReviewProposed,
                      overflow: TextOverflow.ellipsis,
                      style: head.copyWith(color: accent),
                    ),
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
    required this.inset,
    required this.compact,
    required this.stale,
    required this.onOpenNewer,
    required this.busy,
    required this.proposedNumber,
    required this.onConfirm,
    required this.onDiscard,
    required this.onAsk,
  });

  /// Keeps the buttons to the review's column inside the full-width glass.
  final EdgeInsets inset;

  /// One column, on a narrow pane: medium buttons, and Ask for changes as an
  /// icon, so the bar stays one row.
  final bool compact;
  final bool stale;

  /// Opens a newer draft of the document. For a stale draft with one
  /// waiting, that is the next step, not asking for yet another.
  final VoidCallback? onOpenNewer;
  final bool busy;
  final int proposedNumber;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final size = compact
        ? DesignSystemButtonSize.medium
        : DesignSystemButtonSize.large;
    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: inset.add(
        EdgeInsets.symmetric(
          vertical: compact ? tokens.spacing.step3 : tokens.spacing.step4,
        ),
      ),
      // On a narrow pane Discard — which asks first — is the icon, so the
      // constructive alternative to Confirm keeps its words.
      secondary: [
        if (compact)
          DesignSystemIconAction(
            key: DocumentReviewViewKeys.discard,
            icon: LottiIcons.delete,
            tooltip: messages.documentProposalDiscard,
            onPressed: busy ? null : onDiscard,
          )
        else
          DesignSystemButton(
            key: DocumentReviewViewKeys.discard,
            label: messages.documentProposalDiscard,
            variant: DesignSystemButtonVariant.quiet,
            size: size,
            onPressed: busy ? null : onDiscard,
          ),
        // A stale draft's primary already asks the agent.
        if (!stale)
          DesignSystemButton(
            key: DocumentReviewViewKeys.ask,
            label: messages.documentReviewAskForChanges,
            leadingIcon: LottiIcons.chat,
            variant: DesignSystemButtonVariant.tertiary,
            size: size,
            onPressed: onAsk,
          ),
      ],
      primary: stale && onOpenNewer != null
          ? DesignSystemButton(
              key: DocumentReviewViewKeys.openNewer,
              label: messages.documentReviewNewer,
              leadingIcon: LottiIcons.aiSpark,
              size: size,
              onPressed: onOpenNewer,
            )
          : stale
          ? DesignSystemButton(
              key: DocumentReviewViewKeys.redo,
              label: messages.documentReviewRedo,
              leadingIcon: LottiIcons.chat,
              size: size,
              onPressed: onAsk,
            )
          : DesignSystemButton(
              key: DocumentReviewViewKeys.confirm,
              label: messages.documentReviewConfirm(proposedNumber),
              size: size,
              onPressed: busy ? null : onConfirm,
            ),
    );
  }
}

/// The rows without a leading heading that only repeats the document's
/// title, which the header already shows; kept when the draft rewrites it.
List<MarkdownBlockPair> _withoutTitleRow(
  List<MarkdownBlockPair> pairs,
  String title,
) {
  final first = pairs.firstOrNull;
  if (first == null || first.kind != MarkdownBlockChange.same) return pairs;
  final repeatsTitle = withoutRepeatedTitle(
    first.proposed ?? '',
    title,
  ).trim().isEmpty;
  return repeatsTitle ? pairs.sublist(1) : pairs;
}

/// A line of the review's header — the stale warning, the agent's summary —
/// its icon in the rows' gutter column and its text on their text edge.
class _HeaderLine extends StatelessWidget {
  const _HeaderLine({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.style,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: IconSizes.m,
          child: Icon(icon, size: IconSizes.m, color: iconColor),
        ),
        SizedBox(width: tokens.spacing.step2 + tokens.spacing.cardItemSpacing),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            // A sentence, not a column: held to the reading measure.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kProseMeasureWidth),
              child: Text(text, style: style),
            ),
          ),
        ),
      ],
    );
  }
}
