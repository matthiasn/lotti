import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemInlineCalloutWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Inline Callout',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _InlineCalloutOverviewPage(),
      ),
    ],
  );
}

class _InlineCalloutOverviewPage extends StatelessWidget {
  const _InlineCalloutOverviewPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: ListView(
        children: [
          const DesignSystemInlineCallout(
            icon: Icons.warning_rounded,
            text:
                'Sync is paused: one device is excluded from key sharing '
                'until you verify or remove it.',
          ),
          SizedBox(height: tokens.spacing.step4),
          const DesignSystemInlineCallout(
            icon: Icons.lock_outline_rounded,
            text:
                'This code is a key to your account — show it only to your '
                'own new device.',
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemInlineCallout(
            icon: Icons.info_outline_rounded,
            tone: tokens.colors.alert.info.defaultColor,
            text:
                'An informational tone: the border and glyph carry the '
                'hue, the message stays high-emphasis.',
          ),
        ],
      ),
    );
  }
}
