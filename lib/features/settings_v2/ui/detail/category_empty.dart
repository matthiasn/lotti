import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Detail-pane content when a branch node is selected but no leaf
/// has been picked yet (spec §4 "CategoryEmpty"). Uses the branch's
/// own icon + title + description, followed by the "pick a sub-
/// setting" helper line.
///
/// Does not include the `DisableV2Button`: a user at this state has
/// already interacted with the tree and has an obvious way back to
/// the empty root (collapse the branch).
class CategoryEmpty extends StatelessWidget {
  const CategoryEmpty({required this.node, super.key});

  final SettingsNode node;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textHi = tokens.colors.text.highEmphasis;
    final textMid = tokens.colors.text.mediumEmphasis;
    final textLo = tokens.colors.text.lowEmphasis;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              node.icon,
              size: SettingsV2Constants.placeholderIconSize,
              color: textMid,
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              node.title,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: textHi,
              ),
            ),
            if (node.desc.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              Text(
                node.desc,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: textMid,
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.step3),
            Text(
              context.messages.settingsV2CategoryEmptyBody,
              style: tokens.typography.styles.others.caption.copyWith(
                color: textLo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
