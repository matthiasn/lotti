import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

/// Stable keys for the collapsing task-list header, for tests.
@visibleForTesting
abstract final class CollapsingTaskListHeaderKeys {
  static const Key root = Key('collapsing-task-list-header');
  static const Key compactBar = Key('collapsing-task-list-header-compact');
  static const Key compactTitle = Key(
    'collapsing-task-list-header-compact-title',
  );
  static const Key compactTitleTapArea = Key(
    'collapsing-task-list-header-compact-title-tap-area',
  );
  static const Key compactSearchButton = Key(
    'collapsing-task-list-header-compact-search',
  );
  static const Key compactFilterButton = Key(
    'collapsing-task-list-header-compact-filter',
  );
}

/// Decides whether the task-list header is collapsed, from scroll movement.
///
/// The header collapses while the user scrolls *down* (consuming content) and
/// expands again on a deliberate upward scroll — the same direction-driven
/// contract as a hide-on-scroll toolbar. Direction is derived from the pixel
/// deltas between frames, NOT from `userScrollDirection`: a desktop scrollbar
/// drag moves the position via `jumpTo` and never reports a gesture
/// direction, so keying on it would make the header input-device-dependent.
/// Guards keep the header expanded whenever collapsing could trap the user:
///
/// * the list is too short to meaningfully scroll ([minCollapsibleExtent] —
///   collapsing grows the viewport, which shrinks `maxScrollExtent` further;
///   the margin guarantees the list stays scrollable so an upward scroll can
///   always bring the header back),
/// * the viewport sits at (or bounces above) the top of the list,
/// * deltas inside the overscroll zone are ignored, so a bottom-edge bounce
///   settling back cannot masquerade as an upward scroll.
///
/// Gaining search focus expands the header (the field must be visible to
/// type into), but focus does NOT pin it open: on desktop a clicked field
/// keeps focus indefinitely, and pinning would disable the collapse for the
/// rest of the session. The page releases the field's focus when a scroll
/// collapses the header instead — typed text lives in the page state and
/// survives.
///
/// Purely computational — no scroll controller, no widgets — so the rules are
/// unit-testable without a viewport.
class TaskListHeaderCollapseController extends ChangeNotifier {
  /// Scroll offset the user must pass before a downward scroll collapses the
  /// header, so a tiny settle after pull-to-refresh doesn't hide it.
  static const double collapseActivationOffset = 48;

  /// At or above this offset the header always expands — the user is back at
  /// the top of the list where the full header belongs.
  static const double expandNearTopOffset = 8;

  /// Cumulative downward travel (px) an expanded header requires before a
  /// scroll-down collapses it. Symmetric with [expandUpwardTravel], and it
  /// is what makes the bar's own restore affordances trustworthy: without
  /// it, a deliberate title tap was undone by the very next pixel of scroll,
  /// because the offset was already past [collapseActivationOffset].
  static const double collapseDownwardTravel = 24;

  /// Cumulative upward travel (px) a collapsed header requires before a
  /// scroll-up expands it. The expanded header is nearly half the small-phone
  /// viewport, so a single accidental upward jiggle must not slam it back in;
  /// a deliberate upward scroll crosses this within its first few frames.
  static const double expandUpwardTravel = 24;

  /// Minimum `maxScrollExtent` (measured while expanded) required before
  /// collapsing. Sized to exceed the expanded-header height plus a usable
  /// scroll margin: after the collapse reclaims the header's extent the list
  /// must still scroll, otherwise no upward gesture could re-expand it.
  static const double minCollapsibleExtent = 240;

  bool _collapsed = false;
  double? _lastPixels;
  double _upwardTravel = 0;
  double _downwardTravel = 0;
  double? _lastMaxScrollExtent;

  /// Whether the header should currently render collapsed.
  bool get collapsed => _collapsed;

  /// Reports search-field focus. Gaining focus expands the header so the
  /// field is visible to type into; it does not pin it (see class docs).
  void setSearchFocused({required bool focused}) {
    if (focused) _setCollapsed(false);
  }

  /// Seeds the delta baseline with the position's current offset (call once
  /// after the scroll view's first frame). Without it, the very first scroll
  /// event after attach has nothing to diff against and a fast single-event
  /// jump (a fling's opening frame) would be silently swallowed.
  void primeBaseline(double pixels) {
    _lastPixels ??= pixels;
  }

  /// Feeds one scroll frame into the state machine.
  void handleScroll({
    required double pixels,
    required double maxScrollExtent,
  }) {
    final lastPixels = _lastPixels;
    _lastPixels = pixels;
    _lastMaxScrollExtent = maxScrollExtent;
    if (pixels <= expandNearTopOffset) {
      _upwardTravel = 0;
      _downwardTravel = 0;
      _setCollapsed(false);
      return;
    }
    if (lastPixels == null) return;
    // Ignore frames in the bottom overscroll zone: the bounce-back would
    // otherwise read as a deliberate upward scroll and pop the header open
    // at the end of the list.
    if (pixels > maxScrollExtent || lastPixels > maxScrollExtent) return;
    final delta = pixels - lastPixels;
    if (delta > 0) {
      // Moving down the list.
      _upwardTravel = 0;
      if (_collapsed) return;
      _downwardTravel += delta;
      if (_downwardTravel >= collapseDownwardTravel &&
          pixels > collapseActivationOffset &&
          maxScrollExtent >= minCollapsibleExtent) {
        _downwardTravel = 0;
        _setCollapsed(true);
      }
    } else if (delta < 0) {
      if (!_collapsed) return;
      // Accumulate genuine upward travel across frames; an accidental
      // jiggle below [expandUpwardTravel] leaves the compact bar in place,
      // a deliberate scroll-up restores the full header.
      _upwardTravel += -delta;
      if (_upwardTravel >= expandUpwardTravel) {
        _upwardTravel = 0;
        _downwardTravel = 0;
        _setCollapsed(false);
      }
    }
  }

  /// Reacts to content/viewport size changes that arrive without a gesture
  /// (filter narrowed the list, entries deleted, window resized). If the list
  /// can no longer scroll there is no gesture left to restore the header, so
  /// it must expand itself.
  ///
  /// [pixels] resynchronises the delta baseline, but ONLY when the content
  /// actually resized. Flutter can correct the scroll offset during such a
  /// resize WITHOUT emitting a scroll update, so a baseline left at the
  /// pre-resize offset makes the next real scroll frame diff against a
  /// position the viewport no longer holds — a downward wheel step after a
  /// big shrink reads as upward travel and is swallowed.
  ///
  /// The extent guard matters: these notifications also arrive mid-gesture,
  /// and resyncing on those would discard the upward travel accumulating
  /// across frames and make the header impossible to scroll back open.
  void handleContentDimensionsChanged({
    required double maxScrollExtent,
    required double pixels,
  }) {
    if (maxScrollExtent != _lastMaxScrollExtent) {
      _lastMaxScrollExtent = maxScrollExtent;
      _lastPixels = pixels;
      _upwardTravel = 0;
      _downwardTravel = 0;
    }
    if (_collapsed && maxScrollExtent <= 0) _setCollapsed(false);
  }

  /// Expands the header immediately (compact-bar tap, focus-search command).
  ///
  /// Resets the downward budget so the deliberate action survives contact
  /// with the scroll position it was taken at — re-collapsing costs a fresh
  /// [collapseDownwardTravel] of movement, not one stray pixel.
  void expand() {
    _downwardTravel = 0;
    _upwardTravel = 0;
    _setCollapsed(false);
  }

  void _setCollapsed(bool value) {
    if (_collapsed == value) return;
    _collapsed = value;
    notifyListeners();
  }
}

/// Cross-fades the full task-list header stack against a one-row compact bar,
/// animating the freed height so the list below reflows on the same tween.
///
/// Mirrors the task-details app bar's collapse feel (scroll-driven compact
/// state, short cross-fade) — see `TaskExpandableAppBar` — but is
/// direction-driven and lives above the scroll view because this header's
/// height is content-dependent (active-filter chips wrap, the saved-filter
/// rail appears conditionally), which a fixed-extent sliver cannot express.
///
/// Both children stay mounted throughout ([AnimatedCrossFade] keeps the hidden
/// child in the tree behind `ExcludeSemantics`/`TickerMode`), so typed search
/// input survives a collapse and screen readers only ever see one header at a
/// time. With [reduceMotion] the swap is instant.
class CollapsingTaskListHeader extends StatelessWidget {
  const CollapsingTaskListHeader({
    required this.collapsed,
    required this.expandedHeader,
    required this.compactBar,
    required this.reduceMotion,
    super.key,
  });

  final bool collapsed;
  final Widget expandedHeader;
  final Widget compactBar;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final Widget header;
    if (reduceMotion) {
      // Structural swap, no tween: `Duration.zero` would make the cross-fade's
      // internal RenderAnimatedSize complete synchronously during layout
      // (which asserts). Offstage keeps both children mounted (search input
      // survives) while excluding the hidden one from paint, semantics and
      // hit-testing.
      header = Column(
        key: CollapsingTaskListHeaderKeys.root,
        mainAxisSize: MainAxisSize.min,
        children: [
          Offstage(
            offstage: collapsed,
            child: ExcludeFocus(excluding: collapsed, child: expandedHeader),
          ),
          Offstage(
            offstage: !collapsed,
            child: ExcludeFocus(excluding: !collapsed, child: compactBar),
          ),
        ],
      );
    } else {
      header = AnimatedCrossFade(
        key: CollapsingTaskListHeaderKeys.root,
        duration: MotionDurations.medium1,
        sizeCurve: MotionCurves.standard,
        firstCurve: MotionCurves.emphasizedDecelerate,
        secondCurve: MotionCurves.emphasizedDecelerate,
        crossFadeState: collapsed
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: expandedHeader,
        secondChild: compactBar,
      );
    }
    // The seat hairline lives on the wrapper, not the compact bar, so BOTH
    // header states sit against the content scrolling beneath them and the
    // line cannot pop in or out mid cross-fade. It must paint in the
    // FOREGROUND: the compact bar fills its own level02 plane, which would
    // otherwise cover a background-painted border and leave chrome and the
    // first task card meeting at the same value with no edge between them.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TaskShowcasePalette.border(context)),
        ),
      ),
      child: header,
    );
  }
}

/// The one-row compact bar shown while the task-list header is collapsed.
///
/// Left → right: the tab title (tapping it re-expands the header), then
/// [TabHeaderIconButton]s for search (re-expands and focuses the field) and
/// filters (opens the filter modal directly). Both buttons reuse the expanded
/// header's activated treatment — accent glyph over the activated fill, at
/// the same ink as the expanded header so the collapse changes layout only
/// and never brightness. The magnitude of the narrowing is spelled out in
/// [contextLabel] ("4 filters") rather than repeated as a numeral on the
/// funnel: one channel, in words, that localizes and cannot collide with the
/// glyph it sits on. A token hairline seats the bar against the content
/// scrolling beneath it. Every control keeps a ≥48dp tap target
/// via the standard [IconButton] constraints and the min-height title InkWell.
class TaskListCompactHeaderBar extends StatelessWidget {
  const TaskListCompactHeaderBar({
    required this.title,
    required this.searchTooltip,
    required this.filterTooltip,
    required this.expandSemanticHint,
    required this.filtersActive,
    required this.searchActive,
    required this.onExpandRequested,
    required this.onSearchRequested,
    required this.onFilterPressed,
    this.leading,
    this.contextLabel,
    super.key,
  });

  final String title;
  final String searchTooltip;
  final String filterTooltip;

  /// Announced to assistive tech as the title button's hint, so the expand
  /// action is spoken rather than implied by the visual chevron alone.
  final String expandSemanticHint;

  /// Whether any filter currently narrows the list (mirrors the expanded
  /// header's `filtersActive` affordance).
  final bool filtersActive;

  /// Medium-emphasis context rendered after the title — the active saved
  /// view's name, or the current search query — so the collapsed bar states
  /// *what* is narrowing the list, not only that something is.
  final String? contextLabel;
  final Widget? leading;

  /// Whether a search query is currently applied.
  final bool searchActive;

  /// Re-expands the full header (title tap).
  final VoidCallback onExpandRequested;

  /// Re-expands the header and focuses the search field.
  final VoidCallback onSearchRequested;

  /// Opens the filter modal without expanding first.
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final semanticsLabel = contextLabel == null
        ? title
        : '$title, $contextLabel';

    // One surface step above the page (level02 over level01): the bar reads
    // as chrome by *plane*, not just by the seat hairline the wrapper draws.
    return ColoredBox(
      color: tokens.colors.background.level02,
      child: DetailContentWidth(
        key: CollapsingTaskListHeaderKeys.compactBar,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
          child: Row(
            children: [
              if (leading != null)
                SizedBox.square(
                  dimension: TapTargets.minimum,
                  child: Center(child: leading),
                ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: semanticsLabel,
                  hint: expandSemanticHint,
                  // The inner tap targets are excluded from the tree below,
                  // so this node must carry the action itself — a button
                  // that announces a hint but has no tap action cannot be
                  // activated by a screen reader at all.
                  onTap: onExpandRequested,
                  child: ExcludeSemantics(
                    // The whole leading region stays tappable (opaque
                    // GestureDetector) while the ink ripple is bounded to
                    // the label itself (inner InkWell) — a full-row ripple
                    // reads as a list row, not a title.
                    child: GestureDetector(
                      key: CollapsingTaskListHeaderKeys.compactTitleTapArea,
                      behavior: HitTestBehavior.opaque,
                      onTap: onExpandRequested,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              tokens.spacing.step8 + tokens.spacing.step3,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            key: CollapsingTaskListHeaderKeys.compactTitle,
                            borderRadius: BorderRadius.circular(
                              tokens.radii.badgesPills,
                            ),
                            onTap: onExpandRequested,
                            child: Padding(
                              // No leading pad: the title sits on the shared
                              // DetailContentWidth gutter, so the cross-fade
                              // compresses vertically without jogging the
                              // anchor element sideways between states.
                              padding: EdgeInsets.only(
                                right: tokens.spacing.step2,
                                top: tokens.spacing.step2,
                                bottom: tokens.spacing.step2,
                              ),
                              // One rich text run: the mixed type sizes
                              // share a real baseline, the chevron anchors
                              // to the title (one expand affordance meaning
                              // across every variant), and end-ellipsis
                              // truncates the context label before the page
                              // title can ever be cut.
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: title,
                                      // One ramp step above the card-title
                                      // style (subtitle2) so the collapsed
                                      // page title outranks the list items —
                                      // the token style as-is, no phantom
                                      // weight override.
                                      style: tokens
                                          .typography
                                          .styles
                                          .subtitle
                                          .subtitle1
                                          .copyWith(
                                            color:
                                                tokens.colors.text.highEmphasis,
                                          ),
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: tokens.spacing.step1,
                                        ),
                                        // Visible restore affordance: the
                                        // title is a button, and this says
                                        // so.
                                        child: Icon(
                                          LottiIcons.expand,
                                          size: IconSizes.s,
                                          color:
                                              tokens.colors.text.mediumEmphasis,
                                        ),
                                      ),
                                    ),
                                    if (contextLabel != null)
                                      TextSpan(
                                        text: ' · $contextLabel',
                                        // Demoted by SIZE only: the context
                                        // names what narrows the list, a
                                        // fact that must not read at
                                        // placeholder emphasis.
                                        style: tokens
                                            .typography
                                            .styles
                                            .body
                                            .bodySmall
                                            .copyWith(
                                              color: tokens
                                                  .colors
                                                  .text
                                                  .highEmphasis,
                                            ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              TabHeaderIconButton(
                key: CollapsingTaskListHeaderKeys.compactSearchButton,
                icon: LottiIcons.search,
                tooltip: searchTooltip,
                onPressed: onSearchRequested,
                active: searchActive,
              ),
              TabHeaderIconButton(
                key: CollapsingTaskListHeaderKeys.compactFilterButton,
                icon: LottiIcons.filter,
                tooltip: filterTooltip,
                onPressed: onFilterPressed,
                active: filtersActive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
