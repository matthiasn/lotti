import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';

/// Builds the table-specific content for an [ImpactTableCard].
typedef ImpactTableCardChildrenBuilder =
    List<Widget> Function(
      BuildContext context,
      TextStyle headerStyle,
      TextStyle numberStyle,
    );

/// Shared shell for AI Impact breakdown tables.
///
/// The model and location tables use the same card chrome, title treatment,
/// header typography, and mono numeric typography. Keeping those details here
/// prevents the related breakdown tables from drifting apart.
class ImpactTableCard extends StatelessWidget {
  const ImpactTableCard({
    required this.title,
    required this.childrenBuilder,
    super.key,
  });

  /// Card title displayed above the table rows.
  final String title;

  /// Builds the table header and row widgets.
  final ImpactTableCardChildrenBuilder childrenBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final headerStyle = calmEyebrowStyle(
      tokens,
      color: tokens.colors.text.mediumEmphasis,
    );
    final numberStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      base: tokens.typography.styles.body.bodySmall,
      color: tokens.colors.text.highEmphasis,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: insightsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.cardItemSpacing),
            ...childrenBuilder(context, headerStyle, numberStyle),
          ],
        ),
      ),
    );
  }
}
