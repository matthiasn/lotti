import 'dart:math' as math;

import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/components/navigation/ds_menu_glyph.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Whether the mobile navigation launcher owns the bottom action row on the
/// current surface.
///
/// The launcher floats its controls over the page instead of docking an
/// edge-to-edge bar, so a page that floated its own action button in the
/// bottom-trailing corner would put a second, unrelated control beside it.
/// While this is true a page hands its primary action to the launcher (see
/// [MobileNavigationLauncher.pageAction]) rather than floating it, so the
/// two land on one row.
///
/// True on every compact window. The desktop layout has no launcher — the
/// sidebar replaces it there — so floating actions keep their corner. This
/// is the one place a page needs to ask.
bool mobileNavigationLauncherOwnsPageActions(BuildContext context) =>
    !isDesktopLayout(context);

/// A page-owned primary action docked on the launcher's row, opposite the
/// menu button, while that page is the active tab.
///
/// Deliberately data, not a widget: the launcher owns the whole row's
/// silhouette — one chip height, one radius, one glass treatment — so a
/// page contributes only what its action *is*, never how it looks.
///
/// The two constructors carry the page's own decision about wording, the
/// same one its floating button made. The task and people lists word their
/// create actions because the app makes tasks, people, entries, habits, goals
/// and projects from one glyph and the plus alone would not say which; the
/// lists whose own title already answers that keep the bare glyph.
@immutable
class MobileNavDockAction {
  /// An action that shows [label] beside [icon] whenever the row has room
  /// for both words (see [MobileNavigationLauncher.labelsFit]).
  const MobileNavDockAction.worded({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  }) : worded = true;

  /// A glyph-only action: [label] names it for assistive tech and never
  /// renders. For the lists whose heading already says what gets added.
  const MobileNavDockAction.glyph({
    required this.label,
    required this.icon,
    required this.onPressed,
  }) : worded = false,
       semanticLabel = null;

  /// The action's name — rendered beside [icon] on a [worded] action, and
  /// announced by assistive tech either way.
  final String label;

  final IconData icon;
  final VoidCallback onPressed;

  /// Overrides [label] for screen readers. Null announces [label].
  final String? semanticLabel;

  /// Whether [label] rides beside the glyph when the row has room for it.
  final bool worded;
}

/// Stable keys for the launcher's controls.
@visibleForTesting
abstract final class MobileNavigationLauncherKeys {
  /// The menu button that opens the sidebar.
  static const Key menuButton = Key('mobile-navigation-menu-button');
}

/// The mobile navigation launcher: one floating row over the page.
///
/// A round menu button that opens the sidebar is pinned to the
/// bottom-leading corner, and the active page's primary action
/// ([pageAction]), on pages that hand one over, is pinned to the
/// bottom-trailing one as an accent-filled peer of the same height. Both
/// corners sit under the thumb, and the menu button never moves: it is in
/// the same place on every tab whether or not the page docks an action.
///
/// The menu button wears the accent as a ring and a glyph over the glass
/// fill — the task action bar's record button, so the app's round
/// lead-action buttons read as one family — and sits a wider gutter in from
/// the leading edge than the action does from the trailing one, where a
/// round control against the screen's rounded corner would otherwise read
/// as crowded.
///
/// The surrounding area stays transparent so the page remains visible; the
/// shell owns the activity island (running timer / recording) floating
/// above the row.
class MobileNavigationLauncher extends StatelessWidget {
  const MobileNavigationLauncher({
    required this.onOpenMenu,
    this.pageAction,
    super.key,
  });

  /// Opens the sidebar.
  final VoidCallback onOpenMenu;

  /// The active page's primary action, or null when the page has none — the
  /// menu button then stands alone in its corner.
  final MobileNavDockAction? pageAction;

  /// The least the menu button and the page action may sit apart, matching
  /// the task action bar's rhythm so every glass row in the app spaces its
  /// controls identically.
  static double chipGap(BuildContext context) =>
      context.designTokens.spacing.step4;

  /// Height of one chip: a label line inside symmetric padding, never below
  /// the tap-target floor. The menu button's diameter and the action's
  /// height, so the row has one baseline whether or not an action is docked.
  static double chipHeight(BuildContext context) {
    final tokens = context.designTokens;
    return math.max(
      TapTargets.minimum,
      _labelLineHeight(context) + tokens.spacing.step4 * 2,
    );
  }

  /// Vertical screen estate the launcher occupies. Shared with the shell so
  /// recordings and page actions clear it.
  static double barHeight(BuildContext context) =>
      chipHeight(context) +
      context.designTokens.spacing.step2 +
      _bottomPadding(context);

  /// Gutter between the window's leading safe-area edge and the menu button.
  static double leadingGutter(BuildContext context) =>
      context.designTokens.spacing.step5;

  /// Gutter between the page action and the window's trailing safe-area
  /// edge.
  static double trailingGutter(BuildContext context) =>
      context.designTokens.spacing.step3;

  /// Horizontal space the row gets, inside the launcher's own gutters and
  /// the window's safe-area insets.
  static double availableRowWidth(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return MediaQuery.sizeOf(context).width -
        insets.left -
        insets.right -
        leadingGutter(context) -
        trailingGutter(context);
  }

  /// Whether the worded page action fits on the row beside the menu button
  /// with its label intact.
  ///
  /// At the largest accessibility text scales a worded action would be
  /// ellipsised to an unreadable stub. Below the threshold it drops to its
  /// glyph — still the same height, still the same accent, still announcing
  /// its full name — since a `+` beside a list still reads as "add".
  ///
  /// Only consulted for a [MobileNavDockAction.worded] action; a
  /// [MobileNavDockAction.glyph] one is round at every width.
  static bool labelsFit(BuildContext context, MobileNavDockAction action) =>
      chipHeight(context) +
          chipGap(context) +
          DsGlassPill.intrinsicWidth(context, label: action.label) <=
      availableRowWidth(context);

  /// One line of the chips' label style at the ambient text scale, never
  /// shorter than the style's own line height.
  static double _labelLineHeight(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.subtitle.subtitle1;
    return math.max(
      MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!,
      tokens.typography.lineHeight.subtitle1,
    );
  }

  static double _bottomPadding(BuildContext context) => math.max(
    MediaQuery.paddingOf(context).bottom,
    context.designTokens.spacing.step6,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final height = chipHeight(context);
    final action = pageAction;
    // The safe-area insets are physical; the gutters follow the reading
    // direction.
    final insets = MediaQuery.paddingOf(context);
    final ltr = Directionality.of(context) == TextDirection.ltr;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        (ltr ? insets.left : insets.right) + leadingGutter(context),
        tokens.spacing.step2,
        (ltr ? insets.right : insets.left) + trailingGutter(context),
        _bottomPadding(context),
      ),
      child: Row(
        children: [
          // Translucent glass, blurred: the row floats over scrolling
          // content, which the blur keeps legible behind the two strokes.
          DsGlassChipSurface(
            radius: BorderRadius.circular(height / 2),
            blurred: true,
            child: DsGlassRoundButton.glyph(
              key: MobileNavigationLauncherKeys.menuButton,
              glyph: const DsMenuGlyph(),
              semanticLabel: context.messages.navSidebarOpenLabel,
              onPressed: onOpenMenu,
              iconColor: tokens.colors.interactive.enabled,
              outlineColor: tokens.colors.interactive.enabled,
              diameter: height,
              iconSize: IconSizes.l,
            ),
          ),
          if (action != null) ...[
            // The gap is the least the two may sit apart; the action takes
            // whatever the row has left and hugs its trailing end.
            SizedBox(width: chipGap(context)),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                // One chip tall, not as tall as the host allows: an
                // unfactored Align fills any bounded height it is handed.
                heightFactor: 1,
                child: _LauncherPageActionChip(
                  action: action,
                  height: height,
                  labeled: action.worded && labelsFit(context, action),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The page action as it rides the launcher's row: the interactive accent
/// on a chip the same height as the menu button across from it.
///
/// Filled rather than outlined — it is the page's primary action, and the
/// row holds only one filled shape. The fill is opaque, so it skips the
/// backdrop blur the translucent menu button needs.
class _LauncherPageActionChip extends StatelessWidget {
  const _LauncherPageActionChip({
    required this.action,
    required this.height,
    required this.labeled,
  });

  final MobileNavDockAction action;
  final double height;
  final bool labeled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fill = tokens.colors.interactive.enabled;
    final foreground = tokens.colors.text.onInteractiveAlert;
    if (!labeled) {
      return DsGlassChipSurface(
        radius: BorderRadius.circular(height / 2),
        blurred: false,
        child: DsGlassRoundButton(
          icon: action.icon,
          semanticLabel: action.semanticLabel ?? action.label,
          onPressed: action.onPressed,
          backgroundColor: fill,
          iconColor: foreground,
          diameter: height,
        ),
      );
    }
    return DsGlassChipSurface(
      radius: BorderRadius.circular(tokens.radii.badgesPills),
      blurred: false,
      child: DsGlassPill(
        label: action.label,
        icon: action.icon,
        onTap: action.onPressed,
        fillColor: fill,
        foregroundColor: foreground,
        semanticLabel: action.semanticLabel,
        height: height,
      ),
    );
  }
}
