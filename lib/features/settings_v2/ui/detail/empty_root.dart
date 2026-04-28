import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Detail-pane content when no tree node is selected (spec §4
/// "EmptyRoot"). Centered gear glyph + "Settings" headline + the
/// "pick a section" sub-copy.
class EmptyRoot extends StatelessWidget {
  const EmptyRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textHi = tokens.colors.text.highEmphasis;
    final textMid = tokens.colors.text.mediumEmphasis;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_outlined,
              size: SettingsV2Constants.placeholderIconSize,
              color: textMid,
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              context.messages.navTabTitleSettings,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: textHi,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              context.messages.settingsV2EmptyStateBody,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
