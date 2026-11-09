import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the floating card's parts.
@visibleForTesting
abstract final class CompanionFloatingCardKeys {
  static const Key card = Key('companion-floating-card');
  static const Key resizeGrip = Key('companion-floating-card-resize');
  static const Key usualSize = Key('companion-floating-card-usual-size');
  static const Key small = Key('companion-floating-card-small');
  static const Key large = Key('companion-floating-card-large');
  static const Key demo = Key('companion-floating-card-demo');
  static const Key restyle = Key('companion-floating-card-restyle');
  static const Key reset = Key('companion-floating-card-reset');
}

/// The companion over a conversation: [figure] in a glass card that floats
/// over the thread, small by default in the bottom-right corner, moved and
/// resized by the user and kept where they leave it
/// ([companionCardControllerProvider], one placement per [form]).
///
/// Fills its parent — the thread's own area, so the card never reaches the
/// header above it or the field below it — but takes touches only on the
/// card: everywhere else the thread scrolls as usual.
///
/// Drag the card to move it; double-tap Small ⇄ Large; pinch it to any size
/// in between; a long press (a right-click on a desktop) opens its menu —
/// Small, Large, Demo size, restyle, reset. A desktop also resizes from a
/// grip on the card's corner that faces the open screen, shown on hover,
/// and with Ctrl/⌘ + scroll. Demo size fills the area and is never saved:
/// it ends from its own button, a double tap, or when the card goes away.
///
/// While [speaking], the card's edge takes the interactive accent.
class CompanionFloatingCard extends ConsumerStatefulWidget {
  const CompanionFloatingCard({
    required this.form,
    required this.figure,
    required this.onRestyle,
    this.speaking = false,
    super.key,
  });

  final CompanionCardForm form;

  /// Her figure, head to toe ([CompanionFraming.full]); it fills the card.
  final Widget figure;

  /// Changes her look — the menu's restyle row.
  final VoidCallback onRestyle;

  final bool speaking;

  /// The card's shape: her full framing, so she fills it with no margin.
  static final double aspectRatio = CompanionFraming.full.aspectRatio;

  /// The share of the backdrop showing through the glass is set by these
  /// fills over `background.level02`; lighter than the sticky bars'
  /// `DesignSystemGlassStrip` scrim, since the card floats over content
  /// the user is reading rather than closing off an edge.
  static const darkFillAlpha = 0.45;
  static const lightFillAlpha = 0.5;

  /// How fast Ctrl/⌘ + scroll grows the card: a share of its height per
  /// logical pixel scrolled.
  static const scrollScale = 0.0025;

  @override
  ConsumerState<CompanionFloatingCard> createState() =>
      _CompanionFloatingCardState();
}

class _CompanionFloatingCardState extends ConsumerState<CompanionFloatingCard> {
  final _menu = MenuController();
  bool _demo = false;
  bool _hovered = false;

  // True while a pointer is down on the resize grip: the card's own drag,
  // which also sees that pointer, must not move the card meanwhile.
  bool _resizing = false;
  double _pinchStart = 0;

  CompanionCardController get _controller =>
      ref.read(companionCardControllerProvider(widget.form).notifier);

  void _showMenu(Offset position) => _menu.open(position: position);

  void _toggleSize() {
    if (_demo) {
      setState(() => _demo = false);
    } else {
      _controller.toggleSize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final placement = ref.watch(companionCardControllerProvider(widget.form));
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = tokens.spacing.step5;
        final roomWidth = math.max<double>(
          0,
          constraints.maxWidth - 2 * margin,
        );
        final roomHeight = math.max<double>(
          0,
          constraints.maxHeight - 2 * margin,
        );
        // Never taller or wider than the room, whatever was saved: a card
        // saved large on a big window still fits a small one.
        final maxHeight = math.min(
          roomHeight,
          roomWidth / CompanionFloatingCard.aspectRatio,
        );
        final height = _demo
            ? maxHeight
            : math.min(placement.height, maxHeight);
        final width = height * CompanionFloatingCard.aspectRatio;
        final travelX = roomWidth - width;
        final travelY = roomHeight - height;
        final x = _demo ? 0.5 : placement.x;
        final y = _demo ? 0.5 : placement.y;
        return Stack(
          children: [
            Positioned(
              left: margin + x * travelX,
              top: margin + y * travelY,
              width: width,
              height: height,
              child: _card(
                context,
                placement: placement,
                height: height,
                travelX: travelX,
                travelY: travelY,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context, {
    required CompanionCardPlacement placement,
    required double height,
    required double travelX,
    required double travelY,
  }) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final form = widget.form;
    final small = !_demo && placement.height <= form.smallHeight;
    final large = !_demo && placement.height >= form.largeHeight;
    final colors = tokens.colors;
    final dark = colors.background.level01.computeLuminance() < 0.5;
    final radius = BorderRadius.circular(tokens.radii.xl);
    final grip = form == CompanionCardForm.desktop && _hovered && !_demo;

    final glass = DsGlassChipSurface(
      radius: radius,
      blurred: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: colors.background.level02.withValues(
            alpha: dark
                ? CompanionFloatingCard.darkFillAlpha
                : CompanionFloatingCard.lightFillAlpha,
          ),
          border: Border.all(
            color: widget.speaking
                ? colors.interactive.enabled.withValues(
                    alpha: SurfaceAlphas.linework,
                  )
                : colors.decorative.level02,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step5),
                child: widget.figure,
              ),
            ),
            // The grabber says the card moves; it has no gesture of its own.
            if (!_demo)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step3),
                  child: Container(
                    width: tokens.spacing.step7,
                    height: tokens.spacing.step2,
                    decoration: BoxDecoration(
                      color: colors.decorative.level02,
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                    ),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.step3),
                  child: DesignSystemButton(
                    key: CompanionFloatingCardKeys.usualSize,
                    variant: DesignSystemButtonVariant.outlined,
                    leadingIcon: LottiIcons.shrinkFull,
                    label: messages.companionCardUsualSize,
                    onPressed: () => setState(() => _demo = false),
                  ),
                ),
              ),
            if (grip) _resizeGrip(context, placement),
          ],
        ),
      ),
    );

    return DesignSystemContextMenuAnchor(
      controller: _menu,
      semanticsLabel: messages.companionCardOptions,
      fitContent: true,
      items: [
        DesignSystemContextMenuItem(
          key: CompanionFloatingCardKeys.small,
          label: messages.companionCardSmall,
          isSelected: small,
          onTap: () {
            setState(() => _demo = false);
            _controller.resizeTo(form.smallHeight);
          },
        ),
        DesignSystemContextMenuItem(
          key: CompanionFloatingCardKeys.large,
          label: messages.companionCardLarge,
          isSelected: large,
          onTap: () {
            setState(() => _demo = false);
            _controller.resizeTo(form.largeHeight);
          },
        ),
        DesignSystemContextMenuItem(
          key: CompanionFloatingCardKeys.demo,
          label: messages.companionCardDemo,
          icon: LottiIcons.expandFull,
          isSelected: _demo,
          onTap: () => setState(() => _demo = true),
        ),
        DesignSystemContextMenuItem(
          key: CompanionFloatingCardKeys.restyle,
          label: messages.companionCardRestyle,
          icon: LottiIcons.palette,
          startsGroup: true,
          onTap: widget.onRestyle,
        ),
        DesignSystemContextMenuItem(
          key: CompanionFloatingCardKeys.reset,
          label: messages.companionCardReset,
          icon: LottiIcons.undo,
          onTap: () {
            setState(() => _demo = false);
            _controller.reset();
          },
        ),
      ],
      builder: (context, {required toggle, required isOpen}) => Semantics(
        container: true,
        label: messages.companionCardLabel,
        onLongPressHint: messages.companionCardOptions,
        onLongPress: () => _showMenu(Offset.zero),
        child: MouseRegion(
          cursor: _demo ? MouseCursor.defer : SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerSignal: (event) => _scaleOnScroll(event, height),
            child: GestureDetector(
              key: CompanionFloatingCardKeys.card,
              onDoubleTap: _toggleSize,
              onLongPressStart: (details) => _showMenu(details.localPosition),
              onSecondaryTapUp: (details) => _showMenu(details.localPosition),
              onScaleStart: (_) => _pinchStart = height,
              onScaleUpdate: _demo
                  ? null
                  : (details) {
                      if (_resizing) return;
                      if (details.pointerCount > 1) {
                        _controller.resizeTo(_pinchStart * details.scale);
                      } else {
                        _controller.moveBy(
                          travelX > 0
                              ? details.focalPointDelta.dx / travelX
                              : 0,
                          travelY > 0
                              ? details.focalPointDelta.dy / travelY
                              : 0,
                        );
                      }
                    },
              child: glass,
            ),
          ),
        ),
      ),
    );
  }

  /// Ctrl/⌘ + scroll over the card scales it; a plain scroll is left to the
  /// thread.
  void _scaleOnScroll(PointerSignalEvent event, double height) {
    if (_demo || event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      _controller.resizeTo(
        height * (1 - dy * CompanionFloatingCard.scrollScale),
      );
    });
  }

  /// The desktop's resize grip, on the corner that faces the open screen —
  /// the one away from the edges the card is nearest — so growing it never
  /// pushes the card into a wall. Dragging away from the card grows it.
  Widget _resizeGrip(BuildContext context, CompanionCardPlacement placement) {
    final tokens = context.designTokens;
    final top = placement.inLowerHalf;
    final left = placement.x >= 0.5;
    return Align(
      alignment: Alignment(left ? -1 : 1, top ? -1 : 1),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: MouseRegion(
          cursor: top == left
              ? SystemMouseCursors.resizeUpLeftDownRight
              : SystemMouseCursors.resizeUpRightDownLeft,
          // Raw pointer events rather than a recognizer: the card's drag
          // would win the gesture arena from a pan on its own child.
          child: Listener(
            key: CompanionFloatingCardKeys.resizeGrip,
            onPointerDown: (_) => _resizing = true,
            onPointerUp: (_) => _resizing = false,
            onPointerCancel: (_) => _resizing = false,
            onPointerMove: (event) {
              final grow = top ? -event.delta.dy : event.delta.dy;
              _controller.resizeTo(
                ref.read(companionCardControllerProvider(widget.form)).height +
                    grow,
              );
            },
            child: Tooltip(
              message: context.messages.companionCardResize,
              child: Container(
                width: ControlSizes.iconChipCompact,
                height: ControlSizes.iconChipCompact,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.colors.background.level03,
                  border: Border.all(color: tokens.colors.decorative.level02),
                ),
                child: Icon(
                  LottiIcons.expandFull,
                  size: tokens.spacing.step5,
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
