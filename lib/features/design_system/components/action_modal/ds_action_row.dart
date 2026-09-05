import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';
import 'package:material_ui/material_ui.dart';

/// Which family a [DsActionRow] belongs to, which is the only thing that
/// varies between the app's two action modals.
///
/// The tone drives the icon tile's wash and glyph ink — nothing else. Title
/// type, row geometry and hover behaviour are identical across tones, because
/// the two sheets are one pattern and a reader moving between them must not
/// have to re-learn the row.
enum DsActionRowTone {
  /// An action on the entry that already exists — the `•••` menu. Neutral
  /// tile (`surface.enabled`), glyph at `text.mediumEmphasis`.
  neutral,

  /// An action that brings something new into being — the "Add" sheet. Teal
  /// tile (`surface.selected`), glyph in `interactive.enabled`.
  accent,

  /// The one irreversible action, always last and always alone below a
  /// divider. Error wash, error glyph, error title, error hover.
  destructive,
}

/// The glyph on a row's trailing edge, which reports what the tap will do.
enum DsActionRowTrailing {
  /// Nothing. The row acts in place and stays where it is — a copy, a
  /// toggle, a confirm-then-act.
  none,

  /// `+` — the row creates the thing it names, right here.
  add,

  /// `›` — the row hands off to another surface the user continues in.
  chevron,
}

/// One row of an action modal — the shared anatomy behind the `•••` menu and
/// the "Add" sheet.
///
/// A [DsActionRowTone]-washed icon tile leads, the [title] carries the row,
/// an optional [subtitle] says what the tap does, and the trailing edge holds
/// an optional [trailingValue] (the row's current setting, e.g. the entry's
/// language) followed by the [trailing] glyph.
///
/// Rows have no dividers between them: the rounded hover wash is the
/// separator, which is why the row rounds to `radii.m` and carries its own
/// 4pt bottom gap rather than a hairline. The gap rides the *row* and not the
/// list because half these rows decide at build time that they do not apply
/// to this entry and collapse to nothing — a gap owned by the list would then
/// stack up between the rows that did render. The one divider in either sheet
/// sits above the [DsActionRowTone.destructive] row.
class DsActionRow extends StatefulWidget {
  const DsActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingValue,
    this.trailingValueLeading,
    this.trailing = DsActionRowTrailing.none,
    this.tone = DsActionRowTone.neutral,
    this.semanticsLabel,
    super.key,
  });

  /// Share of the row a [trailingValue] may claim before it ellipsizes.
  ///
  /// The value cannot be a flex child — a flex child that asks for less than
  /// its share leaves the remainder as dead space at the row's end, which
  /// dragged the trailing glyph off the rail its neighbours sit on. It is
  /// therefore laid out at its natural width against this cap, so a long
  /// value truncates instead of overflowing and a short one costs nothing.
  static const double trailingValueMaxWidthFraction = 0.45;

  final IconData icon;
  final String title;

  /// One line saying what the tap does. The "Add" sheet requires one on every
  /// row; the `•••` menu carries one only where the row's target is not
  /// obvious from its verb.
  final String? subtitle;

  /// The row's current value, rendered small and quiet before the trailing
  /// glyph — the language on "Set language". Not a description: it is the
  /// state the row would change.
  final String? trailingValue;

  /// A small adornment set immediately before [trailingValue] — the flag
  /// beside a language's name. Ignored when there is no value: it decorates
  /// the reading, it is not a reading of its own.
  final Widget? trailingValueLeading;

  final DsActionRowTrailing trailing;
  final DsActionRowTone tone;

  /// Announced instead of [title] when the visible text under-describes the
  /// action for a screen reader.
  final String? semanticsLabel;

  /// A null callback disables the row: it dims, stops washing on hover and
  /// drops out of the tap order.
  final VoidCallback? onTap;

  @override
  State<DsActionRow> createState() => _DsActionRowState();
}

class _DsActionRowState extends State<DsActionRow> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void didUpdateWidget(covariant DsActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.onTap == null) != (widget.onTap == null)) {
      _hovered = false;
      _pressed = false;
      _focused = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onTap != null;
    final palette = _DsActionRowPalette.of(tokens, widget.tone);
    final radius = BorderRadius.circular(tokens.radii.m);

    // Keyboard focus outranks hover: the pointer can rest on one row while
    // the focus traversal sits on another, and the row the keyboard would
    // activate is the one that has to look activatable. The transparent
    // `overlayColor` below removes Ink's own focus highlight, so the wash and
    // the ring are this widget's to draw — the same pairing
    // `DesignSystemListItem` uses.
    final background = !enabled
        ? Colors.transparent
        : _pressed
        ? palette.pressedWash
        : _focused
        ? palette.focusWash
        : _hovered
        ? palette.hoverWash
        : Colors.transparent;

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        // The wash is animated below; Ink's own overlays would double it and
        // land on a different curve.
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onHover: enabled ? (value) => setState(() => _hovered = value) : null,
        onHighlightChanged: enabled
            ? (value) => setState(() => _pressed = value)
            : null,
        onFocusChange: enabled
            ? (value) => setState(() => _focused = value)
            : null,
        child: AnimatedContainer(
          duration: MotionDurations.short2,
          curve: MotionCurves.standard,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: Border.all(
              color: _focused && enabled
                  ? tokens.colors.interactive.enabled
                  : Colors.transparent,
              width: BorderWidths.emphasis,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4 - BorderWidths.emphasis,
            vertical: tokens.spacing.step3 - BorderWidths.emphasis,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                _DsActionIconTile(icon: widget.icon, palette: palette),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: palette.titleColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.subtitle case final subtitle?
                          when subtitle.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          subtitle,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailingValue case final value?
                    when value.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          constraints.maxWidth *
                          DsActionRow.trailingValueMaxWidthFraction,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: tokens.spacing.step3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.trailingValueLeading case final leading?)
                            Padding(
                              // step3, not step2: at 4pt the flag crowded the
                              // name it marks and the pair read as one smudge
                              // rather than a mark and a word.
                              padding: EdgeInsets.only(
                                right: tokens.spacing.step3,
                              ),
                              child: leading,
                            ),
                          Flexible(
                            child: Text(
                              value,
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: tokens.colors.text.lowEmphasis,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_trailingGlyph(widget.trailing) case final glyph?)
                  Padding(
                    padding: EdgeInsets.only(left: tokens.spacing.step3),
                    child: Icon(
                      glyph,
                      size: IconSizes.s,
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticsLabel,
        child: row.withDisabledOpacity(
          enabled: enabled,
          disabledOpacity: tokens.colors.text.lowEmphasis.a,
        ),
      ),
    );
  }

  static IconData? _trailingGlyph(DsActionRowTrailing trailing) {
    return switch (trailing) {
      DsActionRowTrailing.none => null,
      DsActionRowTrailing.add => LottiIcons.add,
      DsActionRowTrailing.chevron => LottiIcons.chevronRight,
    };
  }
}

/// The washed square behind a row's glyph.
///
/// A container dimension, so it takes [ControlSizes.iconChip] rather than a
/// spacing step that happens to share the number: the tile must not resize
/// when the gap scale is retuned.
class _DsActionIconTile extends StatelessWidget {
  const _DsActionIconTile({required this.icon, required this.palette});

  final IconData icon;
  final _DsActionRowPalette palette;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: ControlSizes.iconChip,
      height: ControlSizes.iconChip,
      decoration: BoxDecoration(
        color: palette.tileFill,
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Center(
        child: Icon(icon, size: IconSizes.m, color: palette.tileInk),
      ),
    );
  }
}

/// The four colours a [DsActionRowTone] resolves to.
@immutable
class _DsActionRowPalette {
  const _DsActionRowPalette({
    required this.tileFill,
    required this.tileInk,
    required this.titleColor,
    required this.hoverWash,
    required this.focusWash,
    required this.pressedWash,
  });

  factory _DsActionRowPalette.of(DsTokens tokens, DsActionRowTone tone) {
    return switch (tone) {
      DsActionRowTone.neutral => _DsActionRowPalette(
        tileFill: tokens.colors.surface.enabled,
        tileInk: tokens.colors.text.mediumEmphasis,
        titleColor: tokens.colors.text.highEmphasis,
        hoverWash: tokens.colors.surface.hover,
        focusWash: tokens.colors.surface.focusPressed,
        pressedWash: tokens.colors.surface.focusPressed,
      ),
      DsActionRowTone.accent => _DsActionRowPalette(
        tileFill: tokens.colors.surface.selected,
        tileInk: tokens.colors.interactive.enabled,
        titleColor: tokens.colors.text.highEmphasis,
        hoverWash: tokens.colors.surface.hover,
        focusWash: tokens.colors.surface.focusPressed,
        pressedWash: tokens.colors.surface.focusPressed,
      ),
      // The destructive row washes in its own hue rather than the neutral
      // grey: the modal's one irreversible action must not feel identical
      // under the pointer to the row that copies some text.
      DsActionRowTone.destructive => _DsActionRowPalette(
        tileFill: DsActionRowPalette.errorWash(tokens),
        tileInk: tokens.colors.alert.error.defaultColor,
        titleColor: tokens.colors.alert.error.defaultColor,
        hoverWash: DsActionRowPalette.errorWash(tokens),
        focusWash: DsActionRowPalette.errorPressedWash(tokens),
        pressedWash: DsActionRowPalette.errorPressedWash(tokens),
      ),
    };
  }

  final Color tileFill;
  final Color tileInk;
  final Color titleColor;
  final Color hoverWash;
  final Color focusWash;
  final Color pressedWash;
}

/// The derived washes behind the destructive row, kept out of the widget so
/// the two sheets and their tests read them from one place.
abstract final class DsActionRowPalette {
  /// The error hue at the same 12 % the design system already uses for a
  /// tinted row fill, so "destructive" and "selected" carry equal weight and
  /// differ only in hue.
  static const double errorWashAlpha = 0.12;

  /// The pressed step, one notch heavier than [errorWashAlpha] — the same
  /// ratio the neutral `surface.hover` → `surface.focusPressed` pair uses.
  static const double errorPressedWashAlpha = 0.2;

  static Color errorWash(DsTokens tokens) =>
      tokens.colors.alert.error.defaultColor.withValues(alpha: errorWashAlpha);

  static Color errorPressedWash(DsTokens tokens) => tokens
      .colors
      .alert
      .error
      .defaultColor
      .withValues(alpha: errorPressedWashAlpha);
}
