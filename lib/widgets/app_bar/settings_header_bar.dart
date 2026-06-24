import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

/// Base height of every Settings header at standard text size (status-bar
/// inset excluded). Matches the desktop Settings V2 header height so the
/// two form factors share one vertical rhythm.
const double kSettingsHeaderHeight = 56;

/// Height the header content needs for the current text scale.
///
/// Returns [kSettingsHeaderHeight] at normal sizes and grows past it when
/// the OS text scale (and/or a subtitle) would otherwise overflow the
/// fixed bar — the header is never allowed to clip its title, mirroring
/// the min-height treatment of the settings rows. Used by both the sliver
/// header (to size its fixed extent) and the menu shell.
double settingsHeaderContentHeight(
  BuildContext context, {
  required bool hasSubtitle,
}) {
  final tokens = context.designTokens;
  final scaler = MediaQuery.textScalerOf(context);
  final titleStyle = tokens.typography.styles.heading.heading3;
  final captionStyle = tokens.typography.styles.others.caption;
  final titleHeight =
      scaler.scale(titleStyle.fontSize ?? 20) * (titleStyle.height ?? 1.3);
  final subtitleHeight = hasSubtitle
      ? scaler.scale(captionStyle.fontSize ?? 12) * (captionStyle.height ?? 1.3)
      : 0.0;
  const verticalPadding = 16.0;
  final content = titleHeight + subtitleHeight + verticalPadding;
  return content > kSettingsHeaderHeight ? content : kSettingsHeaderHeight;
}

/// Canonical content of every Settings header: an optional [BackWidget],
/// the page title in one fixed typography, and optional trailing actions.
///
/// Shared by the sliver header (`SettingsPageHeader`, used by the leaf /
/// list / editor pages) and the menu shell (`SettingsMobileShell`, used by
/// the drill-down root and branch hubs) so the title size, weight, colour,
/// the back-button glyph, and the leading inset are identical on every
/// settings surface — no per-page header drift.
///
/// It draws no background or divider itself; the host (a fixed sliver
/// delegate, or the shell's header container) owns the surface colour and
/// the bottom hairline so a header with a `bottom` accessory can place the
/// divider beneath the accessory rather than under the title.
class SettingsHeaderBar extends StatelessWidget {
  const SettingsHeaderBar({
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;

  /// Override for the back action. When null, the header pops the visible
  /// settings page stack (see [_handleBack]).
  final VoidCallback? onBack;
  final List<Widget>? actions;

  /// The default settings back action.
  ///
  /// The mobile settings surfaces are a Beamer page stack (root → branch →
  /// leaf), so the visible "back" is a page pop — exactly what the system back
  /// gesture does. Pop the local navigator when it can; only fall back to
  /// `NavService.beamBack()` (URL-history back) at the root, where there is no
  /// page to pop. The previous default went straight to `beamBack()`, which
  /// follows URL history rather than the visible stack and could no-op on the
  /// drill-down — so the button did nothing while the back gesture worked.
  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      getIt<NavService>().beamBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final showSubtitle = subtitle?.trim().isNotEmpty ?? false;
    return Padding(
      // Back button sits near the edge; a title without one aligns to the
      // standard content inset so it lines up with the body below it.
      padding: EdgeInsetsDirectional.only(
        start: showBackButton ? tokens.spacing.step2 : tokens.spacing.step4,
        end: tokens.spacing.step4,
      ),
      child: Row(
        children: [
          if (showBackButton)
            BackWidget(onPressed: onBack ?? () => _handleBack(context)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                if (showSubtitle)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
              ],
            ),
          ),
          if (actions != null) ...[
            SizedBox(width: tokens.spacing.step3),
            ...actions!,
          ],
        ],
      ),
    );
  }
}
