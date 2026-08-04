import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list_corners.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemListItemSize {
  small,
  medium,
}

enum DesignSystemListItemVisualState {
  idle,
  hover,
  focused,
  pressed,
}

/// The design-system's list row — a token-styled, tappable item with leading/
/// trailing slots and an optional divider.
///
/// Renders a [title] (or custom [titleContent], capped by [titleMaxLines]) over
/// a [subtitle] (or rich [subtitleSpans], capped by [subtitleMaxLines]), at one of
/// [DesignSystemListItemSize]. Slots [leading]/[leadingExtra] and [trailing]/
/// [trailingExtra] flank the content. Tracks hover/pressed/[activated]/
/// [selected] backgrounds (overridable per state) and reports interaction via
/// [onTap]/[onHoverChanged]; [forcedState] pins a
/// [DesignSystemListItemVisualState] for widgetbook/tests. An optional bottom
/// divider is configurable via [showDivider]/[dividerIndent]/[dividerColor].
/// Inside a grouped list, edge rows read the enclosing
/// [DesignSystemGroupedListCorners] scope and round their state fill and
/// focus border to the group's corner radius so neither is cropped by the
/// group's clip.
class DesignSystemListItem extends StatefulWidget {
  const DesignSystemListItem({
    this.title,
    this.subtitle,
    this.titleContent,
    this.titleMaxLines = 1,
    this.subtitleSpans,
    this.subtitleEmphasis,
    this.subtitleMaxLines = 1,
    this.size = DesignSystemListItemSize.medium,
    this.leading,
    this.leadingExtra,
    this.trailing,
    this.trailingExtra,
    this.showDivider = false,
    this.dividerIndent,
    this.dividerColor,
    this.activated = false,
    this.selected = false,
    this.activatedBackgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.onTap,
    this.focusNode,
    this.onHoverChanged,
    this.onFocusChanged,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.forcedState,
    super.key,
  }) : assert(
         (title != null) ^ (titleContent != null),
         'Provide exactly one of title or titleContent, not both.',
       ),
       assert(
         subtitle == null || subtitleSpans == null,
         'Provide either subtitle or subtitleSpans, not both.',
       );

  final String? title;
  final String? subtitle;
  final Widget? titleContent;

  /// Caps the plain-text title at this many lines. Pass `null` to let it wrap
  /// freely. This does not affect custom [titleContent].
  final int? titleMaxLines;
  final List<InlineSpan>? subtitleSpans;

  /// Overrides the subtitle's ink. Null keeps the size's default. Use it where
  /// the subtitle carries metadata that must rank against something outside
  /// this component — a section eyebrow above the row, say — rather than
  /// against the row's own title.
  final Color? subtitleEmphasis;

  /// Caps the rendered subtitle at this many lines. Defaults to `1` so
  /// every existing caller keeps the previous single-line ellipsis
  /// behaviour. Pass `null` to remove the cap and let long descriptions
  /// wrap freely (the row will grow vertically). Honoured by both the
  /// plain-text [subtitle] and the [subtitleSpans] paths.
  final int? subtitleMaxLines;
  final DesignSystemListItemSize size;
  final Widget? leading;
  final Widget? leadingExtra;
  final Widget? trailing;
  final Widget? trailingExtra;
  final bool showDivider;
  final double? dividerIndent;

  /// Overrides the divider colour. Useful for list surfaces that want to
  /// hide the divider without collapsing its 1 px of vertical space —
  /// pass [Colors.transparent] to keep layout stable while visually
  /// suppressing the line.
  final Color? dividerColor;
  final bool activated;
  final bool selected;
  final Color? activatedBackgroundColor;
  final Color? hoverBackgroundColor;
  final Color? pressedBackgroundColor;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  /// Fires whenever the pointer enters or leaves the item. Lets parent
  /// lists coordinate cross-row state — for example, hiding the divider
  /// between two rows when either one is hovered, matching the
  /// task-list behaviour.
  final ValueChanged<bool>? onHoverChanged;

  /// Fires whenever keyboard focus enters or leaves the row.
  ///
  /// Selection lists use this to coordinate adjacent decoration while keeping
  /// the row itself responsible for its token-driven focus treatment.
  final ValueChanged<bool>? onFocusChanged;
  final String? semanticsLabel;

  /// Suppresses the semantics contributed by the internal [InkWell].
  ///
  /// Set this when a higher-level component (for example a single- or
  /// multi-selection row) provides one deterministic semantics node for the
  /// entire row and its state.
  final bool excludeFromSemantics;
  final DesignSystemListItemVisualState? forcedState;

  /// The horizontal inset from the row's left edge to its TITLE column, for
  /// the medium spec with a step5-sized leading glyph: gutter + glyph + gap.
  ///
  /// Surfaces that append non-row content to a list (the Add sheet's closing
  /// caption) consume this instead of re-deriving the arithmetic, so the
  /// single-axis alignment is owned here and cannot drift when the spec
  /// changes.
  static double titleColumnInset(DsTokens tokens) =>
      tokens.spacing.step5 + tokens.spacing.step5 + tokens.spacing.step3;

  @override
  State<DesignSystemListItem> createState() => _DesignSystemListItemState();
}

class _DesignSystemListItemState extends State<DesignSystemListItem> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void didUpdateWidget(covariant DesignSystemListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forcedState != widget.forcedState ||
        (oldWidget.onTap == null) != (widget.onTap == null)) {
      _hovered = false;
      _pressed = false;
      _focused = false;
    }
  }

  DesignSystemListItemVisualState _resolveVisualState(bool enabled) {
    if (widget.forcedState != null) return widget.forcedState!;
    if (!enabled) return DesignSystemListItemVisualState.idle;
    if (_pressed) return DesignSystemListItemVisualState.pressed;
    if (_focused) return DesignSystemListItemVisualState.focused;
    if (_hovered) return DesignSystemListItemVisualState.hover;
    return DesignSystemListItemVisualState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ListItemSpec.fromTokens(tokens, widget.size);
    // "Can this row wrap?" — not "does it right now". A row whose caps allow a
    // second line has to reserve the aligned-slot geometry, or the icon rail
    // would shift the moment a longer locale wrapped a string that fits in
    // English.
    final multiLine = widget.subtitle != null || widget.subtitleSpans != null
        ? (widget.subtitleMaxLines == null || widget.subtitleMaxLines! > 1) ||
              (widget.titleMaxLines == null || widget.titleMaxLines! > 1)
        : (widget.titleMaxLines == null || widget.titleMaxLines! > 1);
    final enabled = widget.onTap != null;
    final visualState = _resolveVisualState(enabled);

    final backgroundColor = widget.activated
        ? widget.activatedBackgroundColor ??
              DesignSystemListPalette.activatedFill(tokens)
        : switch (visualState) {
            DesignSystemListItemVisualState.idle => Colors.transparent,
            DesignSystemListItemVisualState.hover =>
              widget.hoverBackgroundColor ?? tokens.colors.surface.hover,
            DesignSystemListItemVisualState.focused =>
              tokens.colors.surface.focusPressed,
            DesignSystemListItemVisualState.pressed =>
              widget.pressedBackgroundColor ??
                  tokens.colors.surface.focusPressed,
          };
    final focused = visualState == DesignSystemListItemVisualState.focused;
    // Rows at the edge of a grouped list round their decoration to the
    // group's clip, so the focus border is not cropped at the corners.
    final groupCorners = DesignSystemGroupedListCorners.maybeOf(context);

    final item = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: groupCorners,
              border: Border.all(
                color: focused
                    ? tokens.colors.interactive.enabled
                    : Colors.transparent,
                width: tokens.spacing.step1,
              ),
            ),
            child: InkWell(
              focusNode: widget.focusNode,
              onTap: widget.onTap,
              excludeFromSemantics: widget.excludeFromSemantics,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onHover: enabled
                  ? (value) {
                      // Internal hover state is suppressed while a
                      // forcedState is in effect (e.g., widgetbook
                      // previews); the callback still fires so parent
                      // lists can coordinate cross-row state regardless.
                      if (widget.forcedState == null) {
                        setState(() => _hovered = value);
                      }
                      widget.onHoverChanged?.call(value);
                    }
                  : null,
              onFocusChange: enabled
                  ? (value) {
                      if (widget.forcedState == null) {
                        setState(() => _focused = value);
                      }
                      widget.onFocusChanged?.call(value);
                    }
                  : null,
              onHighlightChanged: widget.forcedState == null && enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: Semantics(
                button: widget.onTap != null,
                label: widget.semanticsLabel,
                selected: widget.selected,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spec.horizontalPadding,
                    vertical: spec.verticalPadding,
                  ),
                  child: _RowAlign(
                    multiLine: multiLine,
                    children: [
                      // Both glyph rails centre against the row's full text
                      // block. The leading slot used to pin to the title's
                      // first line while the trailing slot centred — two
                      // vertical axes on one row, and on every two-line row
                      // the mismatch read as a wobble rather than a rail.
                      // One axis, both sides.
                      if (widget.leadingExtra != null)
                        _SlotAlign(
                          multiLine: multiLine,
                          child: widget.leadingExtra!,
                        ),
                      if (widget.leadingExtra != null && widget.leading != null)
                        SizedBox(width: spec.itemGap),
                      if (widget.leading != null)
                        _SlotAlign(
                          multiLine: multiLine,
                          child: widget.leading!,
                        ),
                      if (widget.leadingExtra != null || widget.leading != null)
                        SizedBox(width: spec.itemGap),
                      Expanded(
                        child: _TitleContent(
                          title: widget.title,
                          subtitle: widget.subtitle,
                          titleContent: widget.titleContent,
                          titleMaxLines: widget.titleMaxLines,
                          subtitleSpans: widget.subtitleSpans,
                          subtitleEmphasis: widget.subtitleEmphasis,
                          subtitleMaxLines: widget.subtitleMaxLines,
                          spec: spec,
                        ),
                      ),
                      if (widget.trailing != null ||
                          widget.trailingExtra != null)
                        SizedBox(width: spec.itemGap),
                      if (widget.trailing != null)
                        _SlotAlign(
                          multiLine: multiLine,
                          child: widget.trailing!,
                        ),
                      if (widget.trailing != null &&
                          widget.trailingExtra != null)
                        SizedBox(width: spec.itemGap),
                      if (widget.trailingExtra != null)
                        _SlotAlign(
                          multiLine: multiLine,
                          child: widget.trailingExtra!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: widget.dividerIndent ?? spec.horizontalPadding,
            color: widget.dividerColor ?? tokens.colors.decorative.level01,
          ),
      ],
    );

    final semanticItem = widget.excludeFromSemantics
        ? ExcludeSemantics(child: item)
        : item;

    return semanticItem.withDisabledOpacity(
      enabled: enabled || widget.forcedState != null,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }
}

/// The list row's layout shell. Single-line rows are a plain centred [Row];
/// rows that can wrap get an [IntrinsicHeight] + stretch so the glyph slots
/// can centre against the full text block ([_SlotAlign]).
class _RowAlign extends StatelessWidget {
  const _RowAlign({required this.children, required this.multiLine});

  final List<Widget> children;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    if (!multiLine) {
      return Row(children: children);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Centres a glyph slot against the row's full (possibly two-line) text
/// block. Both rails use the same axis: the leading slot used to pin to the
/// title's first line while the trailing slot centred, and the two anchors on
/// one row read as a wobble on every two-line list. A pass-through when the
/// row cannot wrap — centring and the title rail are the same thing on a
/// single line.
class _SlotAlign extends StatelessWidget {
  const _SlotAlign({required this.child, required this.multiLine});

  final Widget child;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    if (!multiLine) return child;
    return Center(child: child);
  }
}

class _TitleContent extends StatelessWidget {
  const _TitleContent({
    required this.spec,
    required this.titleMaxLines,
    required this.subtitleMaxLines,
    this.title,
    this.subtitle,
    this.titleContent,
    this.subtitleSpans,
    this.subtitleEmphasis,
  });

  final String? title;
  final String? subtitle;
  final Widget? titleContent;
  final int? titleMaxLines;
  final List<InlineSpan>? subtitleSpans;
  final Color? subtitleEmphasis;
  final int? subtitleMaxLines;
  final _ListItemSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleContent ??
            Text(
              title!,
              style: spec.titleStyle,
              maxLines: titleMaxLines,
              overflow: titleMaxLines == null
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
            ),
        if (subtitle != null || subtitleSpans != null) ...[
          SizedBox(height: spec.textGap),
          if (subtitleSpans != null)
            RichText(
              text: TextSpan(
                style: subtitleEmphasis == null
                    ? spec.subtitleStyle
                    : spec.subtitleStyle.copyWith(color: subtitleEmphasis),
                children: subtitleSpans,
              ),
              maxLines: subtitleMaxLines,
              overflow: subtitleMaxLines == null
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
            )
          else
            Text(
              subtitle!,
              style: subtitleEmphasis == null
                  ? spec.subtitleStyle
                  : spec.subtitleStyle.copyWith(color: subtitleEmphasis),
              maxLines: subtitleMaxLines,
              overflow: subtitleMaxLines == null
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
            ),
        ],
      ],
    );
  }
}

class _ListItemSpec {
  const _ListItemSpec({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.textGap,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  factory _ListItemSpec.fromTokens(
    DsTokens tokens,
    DesignSystemListItemSize size,
  ) {
    return switch (size) {
      DesignSystemListItemSize.medium => _ListItemSpec(
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step4,
        itemGap: tokens.spacing.step3,
        // step2, not step1. At 2pt the title/subtitle gap was smaller than the
        // subtitle's own line leading, so a two-line row read as one
        // paragraph rather than a labelled action.
        textGap: tokens.spacing.step2,
        titleStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        // `caption` (12), not `bodySmall` (14): subtitle2 is also 14, so the
        // two lines differed only in weight and the row had no size ramp at
        // all.
        subtitleStyle: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
      DesignSystemListItemSize.small => _ListItemSpec(
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step3,
        itemGap: tokens.spacing.step3,
        textGap: tokens.spacing.step1,
        titleStyle: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        subtitleStyle: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    };
  }

  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double textGap;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
}
