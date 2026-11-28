import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_labels.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_row.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/markdown_title.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the review's controls by.
abstract final class DocumentReviewViewKeys {
  static const close = Key('document-review-close');
  static const undo = Key('document-review-undo');
  static const ask = Key('document-review-ask');
  static const provenance = Key('document-review-provenance');
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

/// What a version of a document changed (ADR 0167): the version it was
/// written over beside its own text, row by row. Nothing here is a
/// decision — the version is already the document's, or was — so the glass
/// bar offers the two ways on: going back to the version before it, while
/// the document still shows this one, and asking the agent for changes.
///
/// Measured, never a window breakpoint: where the content column holds
/// [documentReviewSideBySideMinWidth] the versions stand side by side under
/// their column heads; narrower — a docked chat, a dragged divider — the
/// same rows stack into one column in reading order.
///
/// The rows are of two versions that never change, so nothing that lands
/// while the review is open moves them ([documentReviewProvider]). A key
/// that names no version of the document closes the review. Escape closes
/// too.
class DocumentReviewView extends ConsumerStatefulWidget {
  const DocumentReviewView({
    required this.reviewKey,
    required this.title,
    required this.onClose,
    super.key,
  });

  final DocumentReviewKey reviewKey;

  /// The document's title, for the header.
  final String title;
  final VoidCallback onClose;

  @override
  ConsumerState<DocumentReviewView> createState() => _DocumentReviewViewState();
}

class _DocumentReviewViewState extends ConsumerState<DocumentReviewView> {
  bool _busy = false;

  DocumentReviewKey get _key => widget.reviewKey;

  QueryScope get _chatScope =>
      QueryScope(kind: QueryScopeKind.task, id: _key.taskId);

  void _askAgent() =>
      ref.read(queryPaneOpenProvider(_chatScope).notifier).open = true;

  /// Goes back to the version this one was written over, by writing its
  /// text as the next version (`TaskDocumentRepository.restore`): nothing is
  /// lost, and this version stays in the history. Refused when another
  /// version landed meanwhile, and says so.
  Future<void> _undo(TaskDocumentVersionEntry base) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final result = await ref
        .read(taskDocumentRepositoryProvider)
        .restore(versionId: base.id, baseVersionId: _key.versionId);
    final written = result.status == TaskDocumentWriteStatus.written;
    messenger.showDesignSystemToast(
      tone: written
          ? DesignSystemToastTone.success
          : DesignSystemToastTone.error,
      title: switch (result.status) {
        TaskDocumentWriteStatus.written => messages.taskDocumentsRestored,
        TaskDocumentWriteStatus.stale => messages.taskDocumentsRestoreStale,
        TaskDocumentWriteStatus.missing ||
        TaskDocumentWriteStatus.failed => messages.saveFailedRetry,
      },
      clearQueue: true,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // The document shows the restored text now.
    if (written) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(documentReviewSnapshotProvider(_key), (_, next) {
      // The key names no version of this document: nothing to review.
      if (next.hasValue && next.value == null) widget.onClose();
    });
    final review = ref.watch(documentReviewProvider(_key));
    // The first load only: once shown, the review stays until it closes.
    if (review == null) return const SizedBox.shrink();
    final snapshot = review.snapshot;
    final tokens = context.designTokens;
    final base = snapshot.baseVersion;
    final baseNumber = base?.data.number;
    final number = snapshot.version.data.number;
    final byAgent = snapshot.version.data.author == TaskDocumentAuthor.agent;
    final pairs = _withoutTitleRow(snapshot.pairs, widget.title);
    final horizontal = tokens.spacing.step5; // see documentReviewMinPaneWidth
    final onUndo = review.isCurrent && base != null && !_busy
        ? () => _undo(base)
        : null;
    final canUndo = review.isCurrent && base != null;
    final canAsk = ref.watch(queryChatEnabledProvider);
    final hasBar = canUndo || canAsk;

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
                          snapshot: snapshot,
                          onClose: widget.onClose,
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
                              baseNumber: baseNumber,
                              number: number,
                              byAgent: byAgent,
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        bottom:
                            (hasBar
                                ? WoltModalConfig.stickyActionBarClearance
                                : 0) +
                            tokens.spacing.step5,
                      ),
                      sliver: SliverList.builder(
                        itemCount: pairs.length,
                        // The rows never change, so a row's index is its
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
                              version: number,
                              noTextLabel: context.messages.taskDocumentsNoText,
                              stacked: !sideBySide,
                              byAgent: byAgent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasBar)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    // The glass spans the pane; its buttons keep to the
                    // column, on the rows' text edge.
                    child: _Bar(
                      inset: EdgeInsets.only(
                        left:
                            (constraints.maxWidth - content) / 2 +
                            (sideBySide
                                ? IconSizes.m + tokens.spacing.step2
                                : 0),
                        right: (constraints.maxWidth - content) / 2,
                      ),
                      compact: !sideBySide,
                      baseNumber: canUndo ? baseNumber : null,
                      onUndo: onUndo,
                      onAsk: canAsk ? _askAgent : null,
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
    required this.snapshot,
    required this.onClose,
  });

  /// A narrow pane: Close review is an icon, so the title keeps the line.
  final bool compact;
  final String title;
  final DocumentReviewSnapshot snapshot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final stats = snapshot.stats;
    final summary = snapshot.changeSummary;
    final byAgent = snapshot.version.data.author == TaskDocumentAuthor.agent;
    final accent = tokens.colors.aiCard.accent;
    final diff = tokens.colors.diff;
    final gap = SizedBox(height: tokens.spacing.step3);
    final textEdge = EdgeInsets.only(
      left: IconSizes.m + tokens.spacing.step2 + tokens.spacing.cardItemSpacing,
    );
    // Title, then which version this is and who wrote it, then its own line
    // on what it changes, then the counts the rows bear out.
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
          SizedBox(height: tokens.spacing.step2),
          Padding(
            padding: textEdge,
            child: Text(
              taskDocumentVersionLine(
                messages,
                snapshot.version,
                now: clock.now(),
              ),
              key: DocumentReviewViewKeys.provenance,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          if (summary != null) ...[
            gap,
            _HeaderLine(
              // The agent's own words carry its spark; a restore's or an
              // edit's line is plain.
              icon: byAgent ? LottiIcons.aiSpark : LottiIcons.edit,
              iconColor: byAgent ? accent : tokens.colors.text.mediumEmphasis,
              text: summary,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step2),
          // On the text edge, under the lines above.
          Padding(
            padding: textEdge,
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
        ],
      ),
    );
  }
}

/// "Before v3" over the left column and "After v4" over the right, on the
/// rows' text edge; the right head takes the agent's violet and spark when
/// the agent wrote the version.
class _ColumnHeads extends StatelessWidget {
  const _ColumnHeads({
    required this.baseNumber,
    required this.number,
    required this.byAgent,
  });

  /// Null when the document had no text before this version.
  final int? baseNumber;
  final int number;
  final bool byAgent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final head = tokens.typography.styles.subtitle.subtitle2;
    final neutral = tokens.colors.text.mediumEmphasis;
    final afterInk = byAgent ? tokens.colors.aiCard.accent : neutral;
    final textEdge = EdgeInsets.only(left: tokens.spacing.cardItemSpacing);
    final baseNumber = this.baseNumber;
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
                      messages.documentReviewBefore,
                      overflow: TextOverflow.ellipsis,
                      style: head.copyWith(color: neutral),
                    ),
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
          ),
          SizedBox(width: tokens.spacing.step6),
          Expanded(
            child: Padding(
              padding: textEdge,
              child: Row(
                children: [
                  if (byAgent) ...[
                    Icon(
                      LottiIcons.aiSpark,
                      size: IconSizes.s,
                      color: afterInk,
                    ),
                    SizedBox(width: tokens.spacing.step1),
                  ],
                  Flexible(
                    child: Text(
                      messages.documentReviewAfter,
                      overflow: TextOverflow.ellipsis,
                      style: head.copyWith(color: afterInk),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  DsPill(
                    variant: DsPillVariant.outline,
                    shape: DsPillShape.tag,
                    color: afterInk,
                    label: messages.taskDocumentsVersion(number),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The review's ways on, on glass: asking the agent for changes — the one
/// filled button, where the task's chat is available — and going back to
/// the version before this one, quiet beside it.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.inset,
    required this.compact,
    required this.baseNumber,
    required this.onUndo,
    required this.onAsk,
  });

  /// Keeps the buttons to the review's column inside the full-width glass.
  final EdgeInsets inset;

  /// One column, on a narrow pane: medium buttons, so the bar stays one row.
  final bool compact;

  /// The version going back lands on; null when there is nothing to go back
  /// to, or the document moved on.
  final int? baseNumber;

  /// Null while a restore runs.
  final VoidCallback? onUndo;

  /// Null where the task's chat is not available.
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final size = compact
        ? DesignSystemButtonSize.medium
        : DesignSystemButtonSize.large;
    final baseNumber = this.baseNumber;
    final onAsk = this.onAsk;
    final undo = baseNumber == null
        ? null
        : DesignSystemButton(
            key: DocumentReviewViewKeys.undo,
            label: messages.documentReviewUndo(baseNumber),
            leadingIcon: LottiIcons.restore,
            // Filled only when it is the bar's one action.
            variant: onAsk == null
                ? DesignSystemButtonVariant.primary
                : DesignSystemButtonVariant.quiet,
            size: size,
            onPressed: onUndo,
          );
    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: inset.add(
        EdgeInsets.symmetric(
          vertical: compact ? tokens.spacing.step3 : tokens.spacing.step4,
        ),
      ),
      secondary: [if (onAsk != null) ?undo],
      primary: onAsk == null
          ? undo!
          : DesignSystemButton(
              key: DocumentReviewViewKeys.ask,
              label: messages.documentReviewAskForChanges,
              leadingIcon: LottiIcons.chat,
              size: size,
              onPressed: onAsk,
            ),
    );
  }
}

/// The rows without a leading heading that only repeats the document's
/// title, which the header already shows; kept when the version rewrites it.
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

/// A line of the review's header — the version's summary — its icon in the rows' gutter column and its text on their text edge.
class _HeaderLine extends StatelessWidget {
  const _HeaderLine({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.style,
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
