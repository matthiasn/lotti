import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:material_ui/material_ui.dart';

/// What a timeline tile says about its row.
enum DesignSystemTimelineTileTone {
  /// Something the user wrote, said, took or planned. Every kind of row
  /// wears this one: the glyph says which kind, not a colour.
  neutral,

  /// Something the agent wrote or suggests — the one tile with a colour of
  /// its own, the AI card's, so agent content is never mistaken for the
  /// user's.
  agent,
}

/// The compact round tile a timeline row hangs on its rail: one glyph naming
/// what the row is (a call, a note, a photo, a meeting).
///
/// [ControlSizes.iconChipCompact], not the list rows' full chip: the tile
/// marks the row, it does not carry it, and the full chip out-weighed the
/// meta line it leads.
class DesignSystemTimelineTile extends StatelessWidget {
  const DesignSystemTimelineTile({
    required this.icon,
    this.tone = DesignSystemTimelineTileTone.neutral,
    super.key,
  });

  final IconData icon;
  final DesignSystemTimelineTileTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (fill, ink) = switch (tone) {
      DesignSystemTimelineTileTone.neutral => (
        tokens.colors.background.level03,
        tokens.colors.text.mediumEmphasis,
      ),
      DesignSystemTimelineTileTone.agent => (
        tokens.colors.aiCard.background,
        tokens.colors.aiCard.accent,
      ),
    };
    return Container(
      width: ControlSizes.iconChipCompact,
      height: ControlSizes.iconChipCompact,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: tone == DesignSystemTimelineTileTone.agent
            ? Border.all(color: tokens.colors.aiCard.border)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: IconSizes.s, color: ink),
    );
  }
}

/// One row of a timeline: a tile on a vertical rail, then a meta line, the
/// body and an optional footer, with an optional trailing control.
///
/// The rail runs from just below the tile to just above the next row's
/// tile, so stacked rows read as one continuous line through time; [last]
/// ends it, at the end of a section. Rows sit on the page itself — no card, no divider —
/// which is what lets a timeline be the page rather than one more box on it.
///
/// [semanticsLabel] is required and must not be blank: a row is often only
/// a glyph and fragments of text, and a screen reader must hear one sentence
/// for it ("Call with Pip, Saturday 1 August, 11 minutes").
class DesignSystemTimelineRow extends StatelessWidget {
  DesignSystemTimelineRow({
    required this.leading,
    required this.meta,
    required this.semanticsLabel,
    this.body,
    this.footer,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.last = false,
    this.highlighted = false,
    super.key,
  }) : assert(
         semanticsLabel.trim().isNotEmpty,
         'A timeline row needs an accessible name',
       );

  /// The tile, usually a [DesignSystemTimelineTile].
  final Widget leading;

  /// The one-line caption naming when and what — usually a `DsTieredText`.
  final Widget meta;

  final Widget? body;

  /// What the row also carries: a feeling, topics, counts, thumbnails.
  final Widget? footer;

  /// A control at the row's end, aligned with the meta line.
  final Widget? trailing;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The last row of its section: the rail stops at the tile.
  final bool last;

  /// Draws the row in the lists' activated fill — a row the user just
  /// brought into being, briefly marked so the eye finds it.
  final bool highlighted;

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    const tile = ControlSizes.iconChipCompact;
    final railLeft = spacing.step3 + tile / 2 - BorderWidths.hairline / 2;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.step3,
        spacing.step3,
        spacing.step3,
        spacing.step4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The row speaks as one sentence ([semanticsLabel]); its glyph and
          // text fragments would only repeat it in pieces.
          Expanded(
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  SizedBox(width: spacing.step4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Centred on the tile, so the meta reads as the
                        // tile's label.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: tile),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            heightFactor: 1,
                            child: meta,
                          ),
                        ),
                        // Prose at a reading measure, however wide the
                        // column: the meta and footer may run on.
                        if (body case final body?)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: kProseMeasureWidth,
                            ),
                            child: body,
                          ),
                        if (footer != null) ...[
                          SizedBox(height: spacing.step3),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: spacing.step3),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: tile),
              child: Align(heightFactor: 1, widthFactor: 1, child: trailing),
            ),
          ],
        ],
      ),
    );

    // The rail leaves the tile a `step1` below it and runs on past this
    // row's bottom, through the next row's top inset, to `step1` above the
    // next tile — one continuous line through a section, with the same gap
    // at either end of every tile.
    final row = Stack(
      clipBehavior: Clip.none,
      children: [
        if (!last)
          Positioned(
            key: const ValueKey('timeline-row-rail'),
            left: railLeft,
            top: spacing.step3 + tile + spacing.step1,
            bottom: spacing.step1 - spacing.step3,
            width: BorderWidths.hairline,
            child: ColoredBox(color: tokens.colors.decorative.level01),
          ),
        content,
      ],
    );

    final tap = onTap;
    return Semantics(
      container: true,
      label: semanticsLabel,
      button: tap != null,
      selected: highlighted,
      onTap: tap,
      onLongPress: onLongPress,
      child: tap == null
          ? row
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onLongPress,
              child: GroupedCardRowSurface(
                selected: highlighted,
                hoverColor: tokens.colors.surface.hover,
                selectedColor: DesignSystemListPalette.activatedFill(tokens),
                padding: EdgeInsets.zero,
                backgroundBorderRadius: BorderRadius.circular(tokens.radii.m),
                onTap: tap,
                child: row,
              ),
            ),
    );
  }
}

/// The heading over a run of timeline rows — *Upcoming*, *This week*,
/// *August* — in the calm eyebrow, aligned with the rows' text column, with
/// an optional [trailing] control (a filter, a count).
class DesignSystemTimelineSectionHeader extends StatelessWidget {
  const DesignSystemTimelineSectionHeader({
    required this.label,
    this.trailing,
    super.key,
  });

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.step3,
          spacing.step5,
          spacing.step3,
          spacing.step2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: calmEyebrowStyle(tokens),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
