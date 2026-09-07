import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Whether the mobile navigation launcher owns the bottom action row on the
/// current surface.
///
/// The launcher floats one centred control over the page instead of docking
/// an edge-to-edge bar, which leaves the bottom-right corner — where a page
/// would otherwise float its own action button — reading as a second,
/// unrelated layer. While this is true a page hands its primary action to
/// the launcher (see [MobileNavigationLauncher.pageAction]) rather than
/// floating it above the launcher, so the two land on one row.
///
/// The desktop layout has no launcher at all: the sidebar replaces the
/// bottom navigation there, and floating actions keep their corner.
bool mobileNavigationLauncherOwnsPageActions(
  BuildContext context,
  WidgetRef ref,
) =>
    !isDesktopLayout(context) &&
    (ref.watch(configFlagProvider(enableMobileNavigationLauncherFlag)).value ??
        false);

/// A page-owned primary action docked beside the launcher's Navigate
/// control while that page is the active tab.
///
/// Deliberately data, not a widget: the launcher owns the whole row's
/// silhouette — one chip height, one radius, one glass treatment — so a
/// page contributes only what its action *is*, never how it looks.
///
/// The two constructors carry the page's own decision about wording, the
/// same one its floating button made. The task list words its create action
/// because the app makes tasks, entries, habits, goals and projects from one
/// glyph and the plus alone would not say which; the lists whose own title
/// already answers that keep the bare glyph.
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

/// The mobile navigation launcher: one floating glass row over the page.
///
/// The row holds the shell's Navigate control and, on pages that hand one
/// over, that page's primary action ([pageAction]) as an accent-filled peer
/// of the same height and silhouette. The pair is centred as a group, so a
/// page with an action reads as one deliberate cluster rather than a pill
/// with something bolted to its side, and leaving that page returns the
/// Navigate control to the centre on its own.
///
/// The surrounding area stays transparent so the page remains visible; the
/// shell owns the recording indicators riding above the row.
class MobileNavigationLauncher extends StatelessWidget {
  const MobileNavigationLauncher({
    required this.onNavigate,
    this.pageAction,
    super.key,
  });

  final VoidCallback onNavigate;

  /// The active page's primary action, or null when the page has none — the
  /// Navigate control is then centred alone.
  final MobileNavDockAction? pageAction;

  /// Gap between the two chips, matching the task action bar's rhythm so
  /// every glass row in the app spaces its controls identically.
  static double chipGap(BuildContext context) =>
      context.designTokens.spacing.step4;

  /// Height of one chip: a label line inside symmetric padding, never below
  /// the tap-target floor. Both chips share it, so the row has one baseline
  /// whether or not a page action is docked.
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

  /// Horizontal space the chip row gets, inside the launcher's own gutters
  /// and the window's safe-area insets.
  static double availableRowWidth(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return MediaQuery.sizeOf(context).width -
        insets.left -
        insets.right -
        context.designTokens.spacing.step3 * 2;
  }

  /// Whether both chips fit side by side with their labels intact.
  ///
  /// Two worded chips on a phone are comfortable at the default text size
  /// and impossible at the largest accessibility scales, where ellipsising
  /// both would leave two unreadable stubs. Below the threshold the page
  /// action drops to its glyph — still the same height, still the same
  /// accent, still announcing its full name — and the Navigate control
  /// keeps its word. It is the page action that gives because Navigate
  /// names the shell and has no icon-only reading, while a `+` beside a
  /// list still reads as "add".
  ///
  /// Only consulted for a [MobileNavDockAction.worded] action; a
  /// [MobileNavDockAction.glyph] one is round at every width.
  static bool labelsFit(BuildContext context, MobileNavDockAction action) =>
      DsGlassPill.intrinsicWidth(
            context,
            label: context.messages.navTabTitleNavigate,
          ) +
          chipGap(context) +
          DsGlassPill.intrinsicWidth(context, label: action.label) <=
      availableRowWidth(context);

  static double _labelLineHeight(BuildContext context) {
    final tokens = context.designTokens;
    final painter = TextPainter(
      text: TextSpan(
        text: context.messages.navTabTitleNavigate,
        style: tokens.typography.styles.subtitle.subtitle1,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final height = math.max(
      painter.height,
      tokens.typography.lineHeight.subtitle1,
    );
    painter.dispose();
    return height;
  }

  static double _bottomPadding(BuildContext context) => math.max(
    MediaQuery.paddingOf(context).bottom,
    context.designTokens.spacing.step6,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final action = pageAction;
    final height = chipHeight(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.paddingOf(context).left + tokens.spacing.step3,
        tokens.spacing.step2,
        MediaQuery.paddingOf(context).right + tokens.spacing.step3,
        _bottomPadding(context),
      ),
      child: Row(
        // Max, not min: the launcher spans the window (the shell positions
        // it edge to edge) and centres its chips inside that span. A
        // shrink-wrapped row would inherit whatever alignment its parent
        // happened to impose, which is how a "centred" control ends up
        // hugging the leading edge in a host that hands down loose
        // constraints.
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _LauncherGlassChip(
              radius: BorderRadius.circular(tokens.radii.badgesPills),
              blurred: true,
              child: DsGlassPill(
                label: context.messages.navTabTitleNavigate,
                icon: LottiIcons.menu,
                onTap: onNavigate,
                height: height,
              ),
            ),
          ),
          if (action != null) ...[
            SizedBox(width: chipGap(context)),
            Flexible(
              child: _LauncherPageActionChip(
                action: action,
                height: height,
                labeled: action.worded && labelsFit(context, action),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The page action as it rides the launcher's row: the interactive accent
/// on a chip the same height as the Navigate control beside it.
///
/// Filled rather than translucent — it is the page's primary action, and a
/// second glass chip would read as a pair of equals with nothing to choose
/// between them. The fill is opaque, so it skips the backdrop blur its
/// translucent neighbour needs.
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
      return _LauncherGlassChip(
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
    return _LauncherGlassChip(
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

/// One chip of the launcher row: the floating-surface shadow every chip
/// wears, and — for the translucent ones — the backdrop blur that makes the
/// page visible through the glass.
///
/// The blur has to live here rather than around the whole row: a filter
/// spanning both chips would also blur the transparent gap between them,
/// smearing the page content the launcher is supposed to leave alone.
class _LauncherGlassChip extends StatelessWidget {
  const _LauncherGlassChip({
    required this.radius,
    required this.blurred,
    required this.child,
  });

  final BorderRadius radius;
  final bool blurred;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: DsShadows.floatingSurface,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: blurred
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: DesignSystemGlassStrip.blurSigma,
                  sigmaY: DesignSystemGlassStrip.blurSigma,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}
