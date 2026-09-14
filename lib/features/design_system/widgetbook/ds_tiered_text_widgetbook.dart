import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDsTieredTextWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Tiered text',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TieredTextOverviewPage(),
      ),
    ],
  );
}

/// The same ladder at three widths, so the shedding is visible side by
/// side: the full wording, then the person alone, then an ellipsis only on
/// the narrowest tier.
class _TieredTextOverviewPage extends StatelessWidget {
  const _TieredTextOverviewPage();

  static const _tiers = [
    'with Pip · last spoke Sat 1 Aug',
    'with Pip',
    'Pip',
  ];
  static const _statusTiers = [
    'Last run failed · 20 min ago',
    'Last run failed',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.designSystemTieredTextTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: tokens.spacing.step4),
          for (final width in const [480.0, 160.0, 24.0]) ...[
            Container(
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
              padding: EdgeInsets.all(tokens.spacing.step2),
              child: DsTieredText(tiers: _tiers, style: style),
            ),
            SizedBox(height: tokens.spacing.step3),
          ],
          // Two inks on one wording: the state word in its alert colour,
          // the detail after the separator in the meta ink.
          SizedBox(height: tokens.spacing.step4),
          for (final width in const [480.0, 120.0]) ...[
            Container(
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
              padding: EdgeInsets.all(tokens.spacing.step2),
              child: DsTieredText(
                tiers: _statusTiers,
                style: style.copyWith(color: tokens.colors.alert.error.ink),
                tailStyle: style.copyWith(color: tokens.colors.aiCard.metaText),
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
          ],
        ],
      ),
    );
  }
}
