import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A single mobile navigation launcher on backdrop-blurred glass.
/// The transparent surrounding area leaves
/// the page visible; the shell owns the recording indicators above the button.
class MobileNavigationLauncher extends StatelessWidget {
  const MobileNavigationLauncher({required this.onNavigate, super.key});

  final VoidCallback onNavigate;

  /// Height of the large, padded design-system button plus safe-area spacing.
  /// Shared with the shell so recordings and page actions clear the launcher.
  static double barHeight(BuildContext context) {
    final tokens = context.designTokens;
    final labelPainter = TextPainter(
      text: TextSpan(
        text: context.messages.navTabTitleNavigate,
        style: tokens.typography.styles.subtitle.subtitle1,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final labelHeight = math.max(
      labelPainter.height,
      tokens.typography.lineHeight.subtitle1,
    );
    labelPainter.dispose();
    return math.max(
          TapTargets.minimum,
          labelHeight + tokens.spacing.step4 * 2,
        ) +
        tokens.spacing.step2 +
        _bottomPadding(context);
  }

  static double _bottomPadding(BuildContext context) => math.max(
    MediaQuery.paddingOf(context).bottom,
    context.designTokens.spacing.step6,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.paddingOf(context).left + tokens.spacing.step3,
        tokens.spacing.step2,
        MediaQuery.paddingOf(context).right + tokens.spacing.step3,
        _bottomPadding(context),
      ),
      child: Center(
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.xl),
            boxShadow: DsShadows.floatingSurface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.xl),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: DesignSystemGlassStrip.blurSigma,
                sigmaY: DesignSystemGlassStrip.blurSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: DesignSystemGlassStrip.overlayColors(tokens),
                  ),
                ),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radii.xl),
                    border: dsGlassChipBorder(tokens),
                  ),
                  child: DesignSystemButton(
                    label: context.messages.navTabTitleNavigate,
                    onPressed: onNavigate,
                    leadingIcon: LottiIcons.menu,
                    variant: DesignSystemButtonVariant.secondary,
                    size: DesignSystemButtonSize.large,
                    tapTargetSize: MaterialTapTargetSize.padded,
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
