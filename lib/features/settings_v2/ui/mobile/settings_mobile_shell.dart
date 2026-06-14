import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/app_bar/settings_header_bar.dart';

/// Fixed chrome for the mobile settings menu surfaces (the drill-down root
/// and the branch hubs).
///
/// Wraps the shared [SettingsHeaderBar] in a fixed bar above the body, so
/// the menu wears the exact same header — title typography, back glyph,
/// insets, height, and hairline — as the leaf / list / editor pages
/// (which render [SettingsHeaderBar] via the sliver `SettingsPageHeader`).
/// The body scrolls underneath; the title never shrinks.
class SettingsMobileShell extends StatelessWidget {
  const SettingsMobileShell({
    required this.title,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;
  final bool showBack;

  /// Defaults to `NavService.beamBack()` via the shared header bar.
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SafeArea sits inside the DecoratedBox so the background and
          // bottom hairline span the full screen width (edge-to-edge,
          // matching the sliver SettingsPageHeader) while the bar content
          // stays inset from notches.
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level01,
              border: Border(
                bottom: BorderSide(color: tokens.colors.decorative.level01),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: settingsHeaderContentHeight(
                  context,
                  hasSubtitle: false,
                ),
                child: SettingsHeaderBar(
                  title: title,
                  showBackButton: showBack,
                  onBack: onBack,
                  actions: actions,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
