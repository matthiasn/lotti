// No direct blur usage; keep imports minimal
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_detail_footer.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_borders.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/nested_ai_responses_widget.dart';
import 'package:lotti/features/labels/ui/widgets/entry_labels_display.dart';
import 'package:lotti/features/ratings/ui/rating_summary.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_section_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/events/event_form.dart';

/// Renders a single journal entry of any type, watching
/// [entryControllerProvider] for `itemId` and choosing a layout based on the
/// resolved entity.
///
/// This is the outer shell: it hides deleted/AI-suppressed entries, renders a
/// task as a [ModernJournalCard] when `showTaskDetails` is false (so a linked
/// task collapses to a compact card), and otherwise wraps
/// [EntryDetailsContent] in a [TaskDetailSectionCard]. It also paints the two
/// mutually exclusive border decorations: a persistent [TimerBorder] for the
/// actively-recording entry (`isActiveTimer`) and a temporary [PulsingBorder]
/// in the entry's category color for scroll-to highlights (`isHighlighted`).
/// Per-type body rendering lives in [EntryDetailsContent].
class EntryDetailsWidget extends ConsumerWidget {
  const EntryDetailsWidget({
    required this.itemId,
    required this.showAiEntry,
    super.key,
    this.showTaskDetails = false,
    this.hideTaskEntries = false,
    this.linkedFrom,
    this.link,
    this.isHighlighted = false,
    this.isActiveTimer = false,
  });

  final String itemId;
  final bool showTaskDetails;
  final bool showAiEntry;
  final bool hideTaskEntries;
  final bool isHighlighted;
  final bool isActiveTimer;

  final JournalEntity? linkedFrom;
  final EntryLink? link;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null ||
        item.meta.deletedAt != null ||
        (item is AiResponseEntry && !showAiEntry)) {
      return const SizedBox.shrink();
    }

    final isTask = item is Task;

    // Hide task entries when viewing from a task's linked entries
    // (tasks are shown in the dedicated Linked Tasks section instead)
    if (isTask && hideTaskEntries) {
      return const SizedBox.shrink();
    }
    final isAudio = item is JournalAudio;

    if (isTask && !showTaskDetails) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
        child: ModernJournalCard(
          item: item,
          showLinkedDuration: true,
          removeHorizontalMargin: true,
        ),
      );
    }

    final tokens = context.designTokens;
    final cardMargin = EdgeInsets.only(
      left: tokens.spacing.step2,
      right: tokens.spacing.step2,
      bottom: tokens.spacing.step4,
    );

    final card = TaskDetailSectionCard(
      key: isAudio ? Key('$itemId-${item.meta.vectorClock}') : Key(itemId),
      margin: cardMargin,
      // One shared shell inset: a consistent left/right gutter so every card
      // type aligns to a single content edge. The top is intentionally tighter
      // (step3) because the header's 48px tap targets overhang below the
      // timestamp baseline and already supply visual air; the bottom has no such
      // overhang, so it takes the full gutter (step4, matching the horizontal
      // inset and the inter-section rhythm) to keep the last line — e.g. an audio
      // transcript — from crowding the card edge.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step4,
        tokens.spacing.step3,
        tokens.spacing.step4,
        tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntryDetailsContent(
            itemId,
            linkedFrom: linkedFrom,
            link: link,
          ),
        ],
      ),
    );

    // Timer highlight takes precedence (persistent, border-centric glow)
    if (isActiveTimer) {
      final color = context.colorScheme.error;
      return Stack(
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: cardMargin,
                child: TimerBorder(
                  color: color,
                  radius: AppTheme.cardBorderRadius,
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Scroll highlight (temporary, border-centric; color differs from timer)
    if (isHighlighted) {
      // Use the category color for the entry to match calendar tint
      final categoryId = item.meta.categoryId;
      final category = getIt<EntitiesCacheService>().getCategoryById(
        categoryId,
      );
      const fallback = Colors.pink;
      final categoryColor = category != null
          ? colorFromCssHex(category.color)
          : fallback;
      return Stack(
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: cardMargin,
                child: PulsingBorder(
                  color: categoryColor,
                  radius: AppTheme.cardBorderRadius,
                  strokeWidth: 1,
                  duration: const Duration(milliseconds: 4800),
                  startDelay: const Duration(milliseconds: 1000),
                  loopCount: 4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

/// Builds the body of an entry detail card: header, optional editor, the
/// type-specific detail section, and footer.
///
/// The `switch (item)` here is the per-type dispatcher — each [JournalEntity]
/// subtype maps to its summary/player widget (audio player, health/workout/
/// survey/measurement summaries, event form, AI response, checklist, rating,
/// etc.), and `shouldHideEditor` suppresses the rich-text editor for types
/// that render their own content instead of free text.
///
/// When shown inside a parent's linked-entries list (`linkedFrom != null`)
/// and the entry is image/audio/text, the body becomes collapsible and the
/// header drives an animated expand/collapse plus a best-effort auto-scroll so
/// a newly expanded card is brought into view.
class EntryDetailsContent extends ConsumerStatefulWidget {
  const EntryDetailsContent(
    this.itemId, {
    this.linkedFrom,
    this.link,
    super.key,
  });

  final String itemId;

  final JournalEntity? linkedFrom;
  final EntryLink? link;

  @override
  ConsumerState<EntryDetailsContent> createState() =>
      _EntryDetailsContentState();
}

class _EntryDetailsContentState extends ConsumerState<EntryDetailsContent> {
  // Optimistic collapse state: flipped instantly on tap so a collapsed entry
  // expands the moment it is tapped, while the persisted `link.collapsed`
  // catches up asynchronously. Persisting runs inside a vector-clock scope that
  // can lag behind a large sync backlog, which made the tap feel unresponsive;
  // the override is cleared once the persisted value matches it again.
  bool? _collapsedOverride;

  @override
  void didUpdateWidget(EntryDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_collapsedOverride != null &&
        (widget.link?.collapsed ?? false) == _collapsedOverride) {
      _collapsedOverride = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemId = widget.itemId;
    final linkedFrom = widget.linkedFrom;
    final link = widget.link;

    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    final isCollapsible =
        linkedFrom != null &&
        (item is JournalImage || item is JournalAudio || item is JournalEntry);
    final isCollapsed =
        isCollapsible && (_collapsedOverride ?? (link?.collapsed ?? false));

    final shouldHideEditor = switch (item) {
      JournalEvent() ||
      QuantitativeEntry() ||
      WorkoutEntry() ||
      Checklist() ||
      ChecklistItem() ||
      AiResponseEntry() ||
      RatingEntry() => true,
      _ => false,
    };

    final detailSection = switch (item) {
      JournalAudio() => AudioPlayerWidget(item),
      WorkoutEntry() => WorkoutSummary(item),
      SurveyEntry() => SurveySummary(item),
      QuantitativeEntry() => HealthSummary(item),
      MeasurementEntry() => MeasurementSummary(item),
      JournalEvent() => EventForm(item),
      // No leading avatar glyph — the habit line uses the same plain
      // "label: value" grammar as the other value cards.
      HabitCompletionEntry() => HabitSummary(item, showText: false),
      AiResponseEntry() => AiResponseSummary(
        item,
        linkedFromId: linkedFrom?.id,
        fadeOut: true,
      ),
      Checklist() => ChecklistCardWrapper(
        entryId: item.meta.id,
        taskId: item.data.linkedTasks.first,
      ),
      // Standalone rendering — no parent task/checklist context available.
      // Standalone rendering — use the parent task id when available so
      // row actions/providers get proper task-scoped context.
      ChecklistItem() => ChecklistItemRow(
        itemId: item.id,
        checklistId: item.data.linkedChecklists.isEmpty
            ? ''
            : item.data.linkedChecklists.first,
        taskId: linkedFrom is Task ? linkedFrom.id : '',
        index: 0,
      ),
      RatingEntry() => RatingSummary(item),
      _ => null,
    };

    // Show labels for non-event, non-task entries (chips only, no header/edit button)
    final showLabels = item is! JournalEvent && item is! Task;

    final currentLink = link;
    final header = EntryDetailHeader(
      entryId: itemId,
      inLinkedEntries: linkedFrom != null,
      linkedFromId: linkedFrom?.id,
      link: link,
      isCollapsible: isCollapsible,
      isCollapsed: isCollapsed,
      onToggleCollapse: isCollapsible && currentLink != null
          ? () async {
              final isExpanding = isCollapsed;
              // Flip the displayed state immediately so the tap is responsive
              // even if the persist (below) lags behind a sync backlog.
              setState(() => _collapsedOverride = !isCollapsed);
              try {
                await ref
                    .read(journalRepositoryProvider)
                    .updateLink(
                      currentLink.copyWith(collapsed: !isCollapsed),
                    );
              } catch (e, s) {
                getIt<DomainLogger>().error(
                  LogDomain.persistence,
                  e,
                  stackTrace: s,
                  subDomain: 'onToggleCollapse',
                );
              }
              // Only auto-scroll when expanding and the card top is pushed
              // above the visible viewport. Collapsing never needs a scroll.
              if (isExpanding) {
                Future.delayed(AppTheme.collapseAnimationDuration, () {
                  if (!context.mounted) return;
                  final renderObject = context.findRenderObject();
                  if (renderObject == null) return;
                  final viewport = RenderAbstractViewport.maybeOf(renderObject);
                  if (viewport == null) return;
                  final revealedOffset = viewport.getOffsetToReveal(
                    renderObject,
                    0,
                  );
                  final scrollable = Scrollable.maybeOf(context);
                  if (scrollable == null) return;
                  final currentOffset = scrollable.position.pixels;
                  if (revealedOffset.offset < currentOffset) {
                    Scrollable.ensureVisible(
                      context,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      alignment: 0.05,
                    );
                  }
                });
              }
            }
          : null,
    );

    // Only count labels that will actually render, so the rhythm never inserts
    // a gap before an empty (collapsed) labels row.
    final hasLabels = showLabels && (item.meta.labelIds?.isNotEmpty ?? false);

    // Only mount the nested AI responses section when there are responses to
    // show. The widget hides itself when empty, but it is still a body section,
    // so the rhythm step in front of it left a wasted gap above the footer
    // (most visible as the dead band over the Save button on audio entries).
    final hasNestedAiResponses =
        item is JournalAudio &&
        (ref
                .watch(linkedAiResponsesControllerProvider(itemId))
                .value
                ?.isNotEmpty ??
            false);

    final footer = EntryDetailFooter(
      entryId: itemId,
      linkedFrom: linkedFrom,
      inLinkedEntries: linkedFrom != null,
    );

    if (!isCollapsible) {
      final body = <Widget>[
        if (hasLabels) EntryLabelsDisplay(entryId: itemId),
        if (item is JournalImage) EntryImageWidget(item),
        if (!shouldHideEditor) _bodyEditor(itemId),
        ?detailSection,
        if (hasNestedAiResponses)
          NestedAiResponsesWidget(
            parentEntryId: itemId,
            linkedFromEntity: item,
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          ..._withRhythm(context, body),
          // Footer self-collapses to zero when there is nothing to show, so it
          // carries its own (small) leading gap rather than a rhythm step.
          footer,
        ],
      );
    }

    // Collapsible layout for image/audio entries in linked context.
    // Date is shown in the header, not duplicated here.
    final collapsibleBody = <Widget>[
      if (item is JournalImage) EntryImageWidget(item),
      if (item is JournalAudio && detailSection != null) detailSection,
      if (hasLabels) EntryLabelsDisplay(entryId: itemId),
      if (!shouldHideEditor) _bodyEditor(itemId),
      if (hasNestedAiResponses)
        NestedAiResponsesWidget(parentEntryId: itemId, linkedFromEntity: item),
    ];
    final expandedContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [..._withRhythm(context, collapsibleBody), footer],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        _CollapsibleBody(
          isCollapsed: isCollapsed,
          child: expandedContent,
        ),
      ],
    );
  }

  /// The entry's body/note editor, nudged left so its text hangs from the same
  /// content gutter as the timestamp and value lines. flutter_quill insets a
  /// read-only line's text ~3px from the editor's own left edge; without this
  /// the body sat on a second, inboard left rail (the most-flagged break in the
  /// card family's alignment).
  Widget _bodyEditor(String itemId) => Transform.translate(
    offset: const Offset(-3, 0),
    // Drop the Material Card's default vertical margin (EdgeInsets.all(4)) — it
    // added a stray band above the read-only markdown (most visible before the
    // editor toolbar appears). Keep the 4px horizontal margin: the -3px nudge
    // above is tuned against it to land the text on the shared content gutter,
    // so zeroing it entirely would clip the first glyph.
    child: EditorWidget(
      entryId: itemId,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    ),
  );

  /// Interleaves ONE shared vertical-rhythm step (`cardItemSpacing`) *between*
  /// stacked body sections — but not before the first one. The header row is
  /// taller than its timestamp text (its 48px icon-button tap targets overhang
  /// below the baseline), so an explicit leading gap stacked on top of that
  /// overhang made the header→body gap visibly larger than every body→body and
  /// body→value gap, leaving the card front-loaded. Letting the overhang serve
  /// as the header→first-content gap evens the cadence top to bottom.
  List<Widget> _withRhythm(BuildContext context, List<Widget> sections) {
    final tokens = context.designTokens;
    final out = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) out.add(SizedBox(height: tokens.spacing.cardItemSpacing));
      out.add(sections[i]);
    }
    return out;
  }
}

/// Animates expand/collapse with synchronized size and opacity transitions.
///
/// Uses [SizeTransition] (clips from bottom, no squishing) combined with
/// [FadeTransition] for a smooth reveal/hide effect.
class _CollapsibleBody extends StatefulWidget {
  const _CollapsibleBody({
    required this.isCollapsed,
    required this.child,
  });

  final bool isCollapsed;
  final Widget child;

  @override
  State<_CollapsibleBody> createState() => _CollapsibleBodyState();
}

class _CollapsibleBodyState extends State<_CollapsibleBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sizeAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.collapseAnimationDuration,
      vsync: this,
      value: widget.isCollapsed ? 0.0 : 1.0,
    );
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      // Delay fade-in so content becomes visible after size has grown enough
      curve: const Interval(0.3, 1, curve: Curves.easeInOutCubic),
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(_CollapsibleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      alignment: AlignmentGeometry.topStart,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: widget.child,
      ),
    );
  }
}
