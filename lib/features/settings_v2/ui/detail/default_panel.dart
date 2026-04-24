import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/detail/disable_v2_button.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Fallback detail-pane body for a leaf whose `panel` id isn't yet
/// registered in `kSettingsPanels` (spec §4 "DefaultPanel"). Shows
/// the node's icon + title and a "panel not yet implemented"
/// headline, with the leaf id as a developer hint.
///
/// Includes the [DisableV2Button] — if the user drilled into a
/// real leaf but the registry entry hasn't landed yet, the escape
/// hatch is still reachable without having to navigate back to
/// the empty root first.
class DefaultPanel extends StatelessWidget {
  const DefaultPanel({required this.node, super.key});

  final SettingsNode node;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textHi = tokens.colors.text.highEmphasis;
    final textMid = tokens.colors.text.mediumEmphasis;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction_rounded,
                    size: SettingsV2Constants.placeholderIconSize,
                    color: textMid,
                  ),
                  SizedBox(height: tokens.spacing.step4),
                  Text(
                    context.messages.settingsV2UnimplementedTitle,
                    style: tokens.typography.styles.heading.heading3.copyWith(
                      color: textHi,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Text(
                    node.title,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: textMid,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    node.panel ?? node.id,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const DisableV2Button(),
        ],
      ),
    );
  }
}
