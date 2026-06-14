import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';

/// Fixed chrome for the mobile settings surfaces.
///
/// Deliberately the opposite of the legacy `SettingsPageHeader`: a flat,
/// fixed-height bar with a hairline underline — no large collapsing
/// title, no scroll-driven font scaling. The title stays put; the body
/// scrolls underneath it. Shared by both mobile tree renderers (the
/// drill-down stack and the inline-expand list) and the leaf panel host
/// so every mobile settings level wears identical chrome.
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

  /// Defaults to popping the current route. Detail hosts can override to
  /// beam to an explicit target.
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
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: SettingsV2Constants.headerHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.background.level01,
                  border: Border(
                    bottom: BorderSide(color: tokens.colors.decorative.level01),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: showBack
                        ? tokens.spacing.step2
                        : tokens.spacing.step5,
                    end: tokens.spacing.step4,
                  ),
                  child: Row(
                    children: [
                      if (showBack)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          iconSize: SettingsV2Constants.chevronSize,
                          color: tokens.colors.text.mediumEmphasis,
                          onPressed:
                              onBack ?? () => Navigator.of(context).pop(),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.heading.heading3
                              .copyWith(color: tokens.colors.text.highEmphasis),
                        ),
                      ),
                      if (actions != null) ...[
                        SizedBox(width: tokens.spacing.step3),
                        ...actions!,
                      ],
                    ],
                  ),
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
