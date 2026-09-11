import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart'
    show HapticFeedback, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/world_chrome_tokens.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What a key press does to the plaza's collapsible toolbar.
///
/// The binding lives here, as data, rather than inside the renderer's key
/// handler: `PlazaView` needs a live Flutter GPU context to build at all, so
/// nothing inside it can be exercised by the test suite. The toolbar's
/// keyboard contract is small enough to state on its own and too load-bearing
/// to leave unstated.
enum PlazaToolbarKey {
  /// `T` — show a hidden toolbar, hide a shown one.
  toggle,

  /// `Esc` — always hide, whatever else the same press dismisses. It is the
  /// key people already press to get a screen out of the way, and the plaza
  /// hands it to the panel and the morning walk as well.
  close;

  /// The toolbar binding for [key], or null when the press is not ours.
  static PlazaToolbarKey? of(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyT) return toggle;
    if (key == LogicalKeyboardKey.escape) return close;
    return null;
  }

  /// The binding [event] *presses*, or null for anything else.
  ///
  /// The renderer's key handler deliberately accepts repeats, because walking
  /// is a key held down. A toggle is not: fed repeats it flips once per
  /// repeat, so holding `T` past the OS threshold strobes the toolbar and
  /// leaves it wherever the user happened to let go. Only the first press of
  /// a key counts.
  static PlazaToolbarKey? pressed(KeyEvent event) =>
      event is KeyDownEvent ? of(event.logicalKey) : null;

  /// The state this press leaves the toolbar in, given it is [open] now.
  bool applyTo({required bool open}) => switch (this) {
    PlazaToolbarKey.toggle => !open,
    PlazaToolbarKey.close => false,
  };
}

/// Who a key press belongs to while the plaza has the keyboard.
///
/// The world binds nearly every key: `WASD` walks, `Tab` steps to the next
/// beacon, `Space` pauses a walk, `H` and `M` fly. That leaves nothing for
/// focus traversal, which is why the toolbar's controls — and the two corner
/// buttons — were reachable by pointer only: the renderer's handler sits on
/// an ancestor `Focus` and answers `Tab` before the app's own traversal ever
/// sees it.
///
/// The way in is the toolbar itself. It is shut for nearly all of a visit,
/// and while it is shut every key is the world's, exactly as before. Open it
/// and `Tab` hands the keyboard to the chrome instead of stepping to the next
/// beacon; `Esc` hands it back.
///
/// Stated here as data, for the same reason [PlazaToolbarKey] is: `PlazaView`
/// needs a live Flutter GPU context to build at all, so a rule left inside it
/// is a rule no test can reach.
enum PlazaKeyRouting {
  /// The world's own binding runs.
  world,

  /// The press belongs to whatever control holds focus — `Tab` traverses,
  /// `Enter` and `Space` activate. The renderer keeps its hands off.
  chrome,

  /// Shut the toolbar and take the keyboard back, whoever was holding it.
  /// The world's own handling still runs afterwards, so one `Esc` dismisses
  /// the toolbar, the task panel and the morning walk together — which is
  /// what it did before focus entered the picture.
  dismiss;

  /// Where [event] goes, given the world holds the keyboard
  /// ([worldHasFocus]) and the toolbar is [toolbarOpen].
  static PlazaKeyRouting of(
    KeyEvent event, {
    required bool worldHasFocus,
    required bool toolbarOpen,
  }) {
    if (PlazaToolbarKey.pressed(event) == PlazaToolbarKey.close) {
      return dismiss;
    }
    if (!worldHasFocus) return chrome;
    if (toolbarOpen && event.logicalKey == LogicalKeyboardKey.tab) {
      return chrome;
    }
    return world;
  }
}

/// The plaza's collapsible top bar: two round buttons that never move, and a
/// toolbar that slides out to their right.
///
/// The world is the point of this screen. The bar it replaces spanned the top
/// of the window with a title, a count, three navigation buttons, two
/// segmented controls and four checkboxes — chrome worth a glance on arrival
/// and in the way for every minute after. Collapsed by default, it gives the
/// street back the top of the screen; the toggle is the standing promise that
/// the controls are one click away.
///
/// The two buttons are the fixed point of the layout. They come first in the
/// row and the toolbar is laid out after them, so revealing it cannot shift
/// them by a pixel — which is what lets the toggle be pressed twice in a row
/// without the pointer having to chase it.
class PlazaTopBar extends StatelessWidget {
  const PlazaTopBar({
    required this.open,
    required this.onToggle,
    required this.toolbar,
    this.onExit,
    super.key,
  });

  /// Whether the toolbar is shown.
  final bool open;

  /// Asks the host to flip [open]. The bar itself holds no state: the same
  /// switch is thrown by the `T` key, which only the renderer can see.
  final VoidCallback onToggle;

  /// The chrome that is revealed — the title row and the tools row. Unchanged
  /// by the collapse; only its container and its visibility are this widget's
  /// business.
  final Widget toolbar;

  /// Leaves the world. Absent where there is nothing to go back to, which is
  /// how the standalone dev harness runs.
  final VoidCallback? onExit;

  /// How long the reveal takes. The design prototype asks for 260ms, which is
  /// the app's [MotionDurations.medium1] to within a frame at 60Hz.
  static const Duration motion = MotionDurations.medium1;

  /// The prototype's `cubic-bezier(.2,.8,.2,1)`: fast off the line, long
  /// gentle tail. That is what [MotionCurves.emphasizedDecelerate] is for.
  static const Curve curve = MotionCurves.emphasizedDecelerate;

  /// The horizontal squeeze the toolbar enters from. Not a spacing token —
  /// it is a ratio, and it exists so the panel reads as unfolding from the
  /// toggle rather than sliding in from off-screen.
  static const double closedScale = 0.96;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onExit != null) ...[
          PlazaHudIconButton(
            icon: LottiIcons.back,
            tooltip: messages.designSystemBackLabel,
            onPressed: onExit!,
          ),
          SizedBox(width: tokens.spacing.step3),
        ],
        PlazaHudIconButton(
          icon: LottiIcons.sidebar,
          tooltip: messages.plazaToggleToolbar,
          onPressed: onToggle,
          lit: open,
        ),
        Flexible(child: _reveal(context)),
      ],
    );
  }

  /// The toolbar's entrance and exit.
  ///
  /// At rest closed it is [SizedBox.shrink] rather than a transparent panel:
  /// an invisible widget that still claims the width of the whole toolbar
  /// would sit over the street swallowing drags, and the one thing a hidden
  /// toolbar must not do is interfere with walking. On its way out it is
  /// still in the tree, so [IgnorePointer] holds it inert from the frame the
  /// dismissal lands: the press that closed it cannot also hit a control.
  /// It has to wrap the glass and not just the controls — a [DecoratedBox]
  /// hit-tests its own decoration, so the panel would swallow the drag even
  /// with every control inside it inert.
  ///
  /// Reduced motion collapses the whole reveal to a single frame, the same
  /// way the plaza already drops character animation.
  Widget _reveal(BuildContext context) {
    final tokens = context.designTokens;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: open ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion,
      curve: curve,
      child: toolbar,
      builder: (context, t, child) => t == 0
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(left: tokens.spacing.step3),
              child: Transform.translate(
                offset: Offset(-tokens.spacing.step4 * (1 - t), 0),
                child: Transform.scale(
                  scaleX: closedScale + (1 - closedScale) * t,
                  scaleY: 1,
                  alignment: Alignment.centerLeft,
                  child: IgnorePointer(
                    ignoring: !open,
                    child: _panel(context, t, child!),
                  ),
                ),
              ),
            ),
    );
  }

  /// The glass itself, at [t] of the way in.
  ///
  /// The fade is spent on the glass's own alpha and on an [Opacity] *inside*
  /// the [BackdropFilter] rather than on one wrapping the panel: an opacity
  /// layer is a save layer, and a backdrop filter nested in one has no
  /// backdrop left to sample. Wrapped, the blur would be inert for the whole
  /// reveal and then snap on in the frame the opacity reached 1.
  Widget _panel(BuildContext context, double t, Widget child) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          for (final shadow in WorldGlass.drop)
            shadow.copyWith(color: _fade(shadow.color, t)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WorldGlass.blurSigma,
            sigmaY: WorldGlass.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _fade(WorldGlass.fill, t),
              borderRadius: radius,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step3,
              ),
              child: Opacity(opacity: t, child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// [color] scaled to [t] of its own alpha, so a translucent surface fades
  /// from nothing to exactly the opacity it was authored at.
  static Color _fade(Color color, double t) =>
      color.withValues(alpha: color.a * t);
}

/// A round button of the plaza's HUD glass, standing on its own over the
/// world.
///
/// Deliberately not `DesignSystemIconAction`: that control is transparent and
/// borrows the contrast of the surface it sits on, which over a 3D street is
/// whatever the camera happens to be pointing at. This one brings its own
/// surface — fill, blur and drop — so the glyph reads against a night facade
/// and a midday sky alike.
class PlazaHudIconButton extends StatefulWidget {
  const PlazaHudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.lit,
    super.key,
  });

  final IconData icon;

  /// Shown on hover and published as the control's semantic label; an
  /// icon-only button has no other name.
  final String tooltip;

  final VoidCallback onPressed;

  /// Whether the thing this button controls is currently showing, or null
  /// when the button toggles nothing — Back leaves, it does not reveal. A lit
  /// button wears the brand teal, so the toggle answers "is it open?"
  /// without the toolbar having to be in view; the same flag is published as
  /// the control's toggled state, because teal is no answer to a screen
  /// reader.
  final bool? lit;

  @override
  State<PlazaHudIconButton> createState() => _PlazaHudIconButtonState();
}

class _PlazaHudIconButtonState extends State<PlazaHudIconButton> {
  bool _hovered = false;
  bool _focused = false;

  void _tap() {
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final lit = widget.lit ?? false;
    final fill = lit
        ? (_hovered ? PlazaStyle.tealHover : PlazaStyle.teal)
        : (_hovered ? WorldGlass.fillHover : WorldGlass.fill);
    // On teal, white type is unreadable; this is the same ink the design
    // system puts on any filled interactive surface.
    final ink = lit
        ? tokens.colors.text.onInteractiveAlert
        : tokens.colors.text.highEmphasis;
    // A ring of the interactive teal, except on a lit button — which is
    // already that teal, and would wear an invisible ring.
    final ring = !_focused
        ? Colors.transparent
        : (lit
              ? tokens.colors.text.onInteractiveAlert
              : tokens.colors.interactive.enabled);
    return Semantics(
      container: true,
      button: true,
      toggled: widget.lit,
      focusable: true,
      focused: _focused,
      label: widget.tooltip,
      onTap: _tap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: widget.tooltip,
          // Focus and activation only. The pointer wash stays on a plain
          // [MouseRegion]: `onShowHoverHighlight` is gated on the focus
          // highlight mode, and this control is lifted by a pointer whether
          // or not the app currently thinks it is being touched.
          child: FocusableActionDetector(
            onShowFocusHighlight: (focused) =>
                setState(() => _focused = focused),
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _tap();
                  return null;
                },
              ),
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                // The glass chip is [ControlSizes.iconChip], but the thing you
                // have to hit is [TapTargets.minimum]: a glyph-only control has
                // no label to borrow hit area from, so a compact target would
                // be its only target.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: TapTargets.minimum,
                    minHeight: TapTargets.minimum,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: SizedBox.square(
                      dimension: ControlSizes.iconChip,
                      child: DecoratedBox(
                        // Foreground, so the ring lands on the glass rather
                        // than behind an opaque fill.
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ring,
                            width: BorderWidths.emphasis,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: WorldGlass.drop,
                          ),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: WorldGlass.blurSigma,
                                sigmaY: WorldGlass.blurSigma,
                              ),
                              child: ColoredBox(
                                color: fill,
                                child: Center(
                                  child: Icon(
                                    widget.icon,
                                    size: IconSizes.m,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
