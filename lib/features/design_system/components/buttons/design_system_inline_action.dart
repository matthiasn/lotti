import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A caption-tier tappable row for metadata contexts.
///
/// Sits below `DesignSystemButton` in the emphasis ladder: it reads as a
/// control through its glyph, its ink and its hover fill rather than through a
/// fill or a border, so it can live inside a run of caption text without
/// out-weighing it. Use it for the small actions that belong to metadata —
/// "skip this one", "change this setting" — where even a dense button would
/// look like the surface's primary action.
///
/// Three details are the point of having one component rather than an
/// open-coded `Material`/`InkWell` per call site:
///
///  * **The ink hugs the content.** The row shrink-wraps, so the hover and
///    press layers stop at the last glyph instead of running the width of
///    whatever column the action happens to sit in. An open-coded version
///    inherits its parent's width whenever that parent stretches, which is
///    silent and easy to miss.
///  * **The inset lives inside the ink.** Painted flush, the rounded ink
///    corners cut into the leading glyph.
///  * **One interaction target.** The row's minimum height is
///    `spacing.step8`, so a caption-sized label still has a real target.
///
/// It deliberately offers no way to decorate its label. An underline here lets
/// a caption-tier action out-decorate the value it acts on, and gives a surface
/// a third dialect for "this is tappable" alongside the glyph and the hover
/// fill — so the affordance is the fill, everywhere, and the knob does not
/// exist to be reached for.
class DesignSystemInlineAction extends StatelessWidget {
  const DesignSystemInlineAction({
    required this.onTap,
    required this.semanticsLabel,
    this.label,
    this.labelWidget,
    this.leadingIcon,
    this.trailingIcon,
    this.tooltip,
    this.ink,
    this.iconInk,
    super.key,
  }) : assert(
         label != null || labelWidget != null,
         'Provide either a label or a labelWidget.',
       );

  /// Null disables the action; the row still renders, so a control never
  /// vanishes just because it is currently unavailable.
  final VoidCallback? onTap;

  /// What a screen reader announces. Distinct from [tooltip], which describes
  /// the action to a pointer user, and from [label], which may be truncated.
  final String semanticsLabel;

  final String? label;

  /// Replaces [label] when the text needs its own behaviour — a wording ladder,
  /// a live value, a measured slot.
  final Widget? labelWidget;

  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final String? tooltip;

  /// Label colour. Defaults to `aiCard.metaText`-equivalent neutral ink from
  /// the text ramp so the action reads as metadata unless a caller opts into
  /// something louder.
  final Color? ink;

  /// Glyph colour when it should differ from [ink] — an error state tinting
  /// its icon while keeping the text readable, for example.
  final Color? iconInk;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final foreground = ink ?? tokens.colors.text.mediumEmphasis;
    final glyphColor = iconInk ?? foreground;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: foreground,
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: tokens.spacing.step5, color: glyphColor),
          SizedBox(width: tokens.spacing.step2),
        ],
        Flexible(
          child:
              labelWidget ??
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
        ),
        if (trailingIcon != null) ...[
          SizedBox(width: tokens.spacing.step2),
          Icon(trailingIcon, size: tokens.spacing.step5, color: glyphColor),
        ],
      ],
    );

    Widget target = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.spacing.step8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
            // The visible label may be truncated or a live value, so the
            // children stay silent and [semanticsLabel] speaks for the whole
            // control. Excluding *here* rather than above the InkWell keeps
            // its tap and focus actions, which a button must publish.
            child: ExcludeSemantics(
              child: DefaultTextStyle.merge(style: style, child: row),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      target = Tooltip(
        message: tooltip,
        // [semanticsLabel] is the whole announcement. A tooltip publishes its
        // message on the same node, so leaving it in makes a screen reader
        // read the action twice — literally so where a caller passes one
        // string as both, and near enough where the label already ends in
        // "Activate to change setup".
        excludeFromSemantics: true,
        child: target,
      );
    }

    // Everything that describes the control — its ink, its tooltip and its
    // accessibility bounds — sits on the shrink-wrapped side of this `Align`.
    //
    // The `Align` itself takes the full width a stretching parent offers, and
    // that is the point: it converts the tight constraint into a loose one, so
    // the `Material` below can honour `MainAxisSize.min` instead of spanning
    // the column. But anything wrapped *around* the `Align` inherits the full
    // width instead of the ink's — which would leave the tooltip firing over
    // blank space and the focus rectangle covering places a tap does nothing.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: semanticsLabel,
        child: target,
      ),
    );
  }
}
