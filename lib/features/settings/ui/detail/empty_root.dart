import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/settings_tree_constants.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Detail-pane content when no tree node is selected. Centered gear glyph + "Settings" headline + the
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
              LottiIcons.settings,
              size: SettingsTreeConstants.placeholderIconSize,
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
              context.messages.settingsTreeEmptyStateBody,
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
