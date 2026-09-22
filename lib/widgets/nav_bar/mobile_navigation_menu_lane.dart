import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/navigation/ds_menu_glyph.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the mobile sidebar navigation's top lane.
@visibleForTesting
abstract final class MobileNavigationMenuLaneKeys {
  static const Key lane = Key('mobile-navigation-menu-lane');
  static const Key button = Key('mobile-navigation-menu-button');
}

/// The mobile sidebar navigation's top lane: a slim row of the shell's own,
/// above every page, with the menu button fixed at its leading edge.
///
/// **Structural, never an overlay.** Every tab owns its own top-leading
/// corner — a title here, a back chevron there, the Daily OS day stepper —
/// so a button floated over the page would land on a different control on
/// each one. The lane is the first child of a [Column] whose second child is
/// the page, so the button sits in one fixed place on every tab and the
/// page's own header starts beneath it, untouched: the large-title
/// arrangement, with the bar button above the title.
///
/// **It owns the status-bar inset while it shows.** The lane pads itself by
/// the top safe area and hands the page a zero top inset, so the page does
/// not pad a second time for a status bar the lane already cleared. When
/// [visible] turns false — a route that hides navigation — the row folds
/// away and the inset is handed back in the same motion: the lane's height
/// and the page's top inset are both driven by one value, so their sum moves
/// smoothly from "inset + row" to "inset" and the page never jumps.
class MobileNavigationMenuLane extends StatelessWidget {
  const MobileNavigationMenuLane({
    required this.visible,
    required this.onOpenMenu,
    required this.child,
    this.duration = MotionDurations.medium4,
    this.curve = MotionCurves.easeOutQuart,
    super.key,
  });

  /// Whether the lane shows. False on the routes that hide navigation.
  final bool visible;

  final VoidCallback onOpenMenu;

  /// The page beneath the lane.
  final Widget child;

  /// How long the row takes to fold away or back. Ignored — the change is
  /// immediate — while the platform asks for reduced motion.
  final Duration duration;

  final Curve curve;

  /// Diameter of the menu button: the compact touch target, so the lane
  /// costs a page as little height as a bar button honestly can.
  static const double buttonDiameter = TapTargets.compact;

  /// Height of the button row itself, without the status-bar inset.
  static double rowHeight(BuildContext context) =>
      buttonDiameter + context.designTokens.spacing.step2 * 2;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: reduceMotion ? Duration.zero : duration,
      curve: curve,
      builder: (context, shown, _) => _build(context, shown),
    );
  }

  Widget _build(BuildContext context, double shown) {
    final tokens = context.designTokens;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    // What the lane has not absorbed of the status-bar inset goes back to
    // the page: all of it once the lane is gone, none of it while it shows.
    final pageTopInset = topInset * (1 - shown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown > 0)
          ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: shown,
              child: Padding(
                key: MobileNavigationMenuLaneKeys.lane,
                padding: EdgeInsets.fromLTRB(
                  media.padding.left + tokens.spacing.step5,
                  topInset + tokens.spacing.step2,
                  media.padding.right + tokens.spacing.step5,
                  tokens.spacing.step2,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  // A surface one step above the page with a hairline edge,
                  // not the translucent glass of the app's floating chips:
                  // the lane is part of the page's own plane, with nothing
                  // scrolling beneath it to blur, and the quieter disc lets
                  // the two strokes carry the button.
                  child: DsGlassRoundButton.glyph(
                    key: MobileNavigationMenuLaneKeys.button,
                    glyph: const DsMenuGlyph(),
                    semanticLabel: context.messages.navSidebarOpenLabel,
                    onPressed: onOpenMenu,
                    backgroundColor: tokens.colors.background.level02,
                    outlineColor: tokens.colors.decorative.level01,
                    diameter: buttonDiameter,
                    iconSize: IconSizes.l,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          // Keyed so the page keeps its element when the lane's slot above
          // it comes and goes.
          key: const ValueKey('mobile-navigation-menu-lane-page'),
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: pageTopInset),
              viewPadding: media.viewPadding.copyWith(
                top: media.viewPadding.top * (1 - shown),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
