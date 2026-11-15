import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One other way an inbox item can go: what it becomes ([label]), what
/// choosing it does ([hint]), and the choosing itself.
class FrontDoorWay {
  const FrontDoorWay({
    required this.name,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  /// The way's name in its row's key: `front-door-<name>-<index>`.
  final String name;
  final String label;
  final String hint;
  final IconData icon;

  /// Null while the item's action is in flight: the row is not offered.
  final VoidCallback? onTap;
}

/// The other ways an inbox item can go, listed in its card: the card grows
/// by them, on its own surface and its own two columns — each way's glyph
/// on a tile under the item's tile, its name and what it does under the
/// item's words. Three levels: the ways' names, then what each does and the
/// label over them, then the way out.
///
/// [leave], the way that makes nothing, comes last, set apart and quiet:
/// the ways that make something lead. Escape closes the list ([onClose])
/// while it, or a row in it, holds focus.
class FrontDoorWays extends StatefulWidget {
  const FrontDoorWays({
    required this.index,
    required this.ways,
    required this.leave,
    required this.onClose,
    super.key,
  });

  /// The item's segment index, which its rows' keys carry.
  final int index;
  final List<FrontDoorWay> ways;
  final FrontDoorWay leave;
  final VoidCallback onClose;

  @override
  State<FrontDoorWays> createState() => _FrontDoorWaysState();
}

class _FrontDoorWaysState extends State<FrontDoorWays> {
  /// The list's own focus: Escape closes it while it, or a row in it,
  /// holds focus.
  final _focus = FocusNode(debugLabel: 'front-door-ways');

  @override
  void initState() {
    super.initState();
    // Asked for, not left to autofocus, which yields to whatever already
    // holds focus; and brought into view — the last card of a conversation
    // opens its ways under the composer otherwise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MotionDurations.short4,
        curve: MotionCurves.standard,
      ).ignore();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !_focus.hasFocus) {
      return KeyEventResult.ignored;
    }
    widget.onClose();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final index = widget.index;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      // The card is drawn on a plain box; the rows' ink needs a surface.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Further from the item's own line than the ways stand from
            // each other: it heads them, and is no second line of the
            // question over it.
            SizedBox(height: tokens.spacing.step6),
            Padding(
              // On the words' edge: past the tile's column and its gap.
              padding: EdgeInsetsDirectional.only(
                start: ControlSizes.iconChipCompact + tokens.spacing.step3,
                bottom: tokens.spacing.step1,
              ),
              child: Text(
                context.messages.frontDoorOtherWays,
                key: ValueKey('front-door-ways-heading-$index'),
                // A quiet label: the ways' names under it carry the weight.
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
            for (final way in widget.ways) _WayRow(way: way, index: index),
            // Set apart by more than the ways stand from each other, and by
            // less than the list stands from the item's own line: the
            // card's largest break is over the list, not inside it.
            SizedBox(height: tokens.spacing.step4),
            _WayRow(way: widget.leave, index: index, quiet: true),
          ],
        ),
      ),
    );
  }
}

/// One way as a row of the card: its glyph on a tile in the item's tile
/// column, its name — the row's one strong line — over what it does.
///
/// [quiet] is the way out: no tile, its name in the quiet ink, so the ways
/// that make something are what the eye lands on.
class _WayRow extends StatelessWidget {
  const _WayRow({required this.way, required this.index, this.quiet = false});

  final FrontDoorWay way;
  final int index;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final quietInk = tokens.colors.text.mediumEmphasis;
    return Semantics(
      key: ValueKey('front-door-${way.name}-$index'),
      button: true,
      enabled: way.onTap != null,
      label: '${way.label}. ${way.hint}',
      onTap: way.onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: way.onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          hoverColor: DesignSystemListPalette.hoverFill(tokens),
          highlightColor: DesignSystemListPalette.pressedFill(tokens),
          focusColor: tokens.colors.surface.focusPressed,
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
            child: Row(
              children: [
                // The item's tile again, in the neutral fill: the ways line
                // up under it as things of its kind, without its accent.
                Container(
                  key: ValueKey('front-door-${way.name}-tile-$index'),
                  width: ControlSizes.iconChipCompact,
                  height: ControlSizes.iconChipCompact,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: quiet ? null : tokens.colors.surface.enabled,
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                  ),
                  child: Icon(
                    way.icon,
                    // Grows with the text, short of filling its tile.
                    size: math.min(
                      MediaQuery.textScalerOf(context).scale(IconSizes.s),
                      IconSizes.l,
                    ),
                    color: quiet ? quietInk : tokens.colors.text.highEmphasis,
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        way.label,
                        style: quiet
                            ? styles.body.bodySmall.copyWith(color: quietInk)
                            : styles.subtitle.subtitle2.copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                      ),
                      Text(
                        way.hint,
                        style: styles.others.caption.copyWith(color: quietInk),
                      ),
                    ],
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

/// The toggle that opens and closes an item's [FrontDoorWays], in the slot
/// a card's overflow takes: a chevron, since the list opens in place under
/// it rather than as a menu over it.
class FrontDoorWaysToggle extends StatelessWidget {
  const FrontDoorWaysToggle({
    required this.open,
    required this.onPressed,
    super.key,
  });

  final bool open;

  /// Null while the item's action is in flight.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = context.messages.frontDoorOtherWays;
    return SizedBox.square(
      dimension: DesignSystemContextMenuButton.extent(tokens),
      child: Semantics(
        label: label,
        button: true,
        expanded: open,
        enabled: onPressed != null,
        excludeSemantics: true,
        onTap: onPressed,
        child: IconButton(
          tooltip: label,
          padding: EdgeInsets.zero,
          // Grows with the text, as the ways' glyphs do.
          iconSize: math.min(
            MediaQuery.textScalerOf(context).scale(IconSizes.m),
            IconSizes.l,
          ),
          icon: Icon(
            open ? LottiIcons.chevronUp : LottiIcons.chevronDown,
            color: open
                ? tokens.colors.text.highEmphasis
                : tokens.colors.text.mediumEmphasis,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
