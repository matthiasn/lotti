import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_ai_assistant_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemAiIconWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'AI Icon',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _AiIconOverviewPage(),
      ),
    ],
  );
}

class _AiIconOverviewPage extends StatelessWidget {
  const _AiIconOverviewPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(
            messages.designSystemNavigationAiAssistantSectionTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 32,
            runSpacing: 24,
            children: [
              _AiIconPreview(
                label: 'Interactive',
                tokens: tokens,
                child: DesignSystemAiAssistantButton(
                  assetName: 'assets/design_system/ai_assistant_variant_1.png',
                  semanticLabel:
                      messages.designSystemNavigationAiAssistantSectionTitle,
                  onPressed: widgetbookNoop,
                ),
              ),
              _AiIconPreview(
                label: 'Variant 2',
                tokens: tokens,
                child: DesignSystemAiAssistantButton(
                  assetName: 'assets/design_system/ai_assistant_variant_2.png',
                  semanticLabel:
                      messages.designSystemNavigationAiAssistantSectionTitle,
                  onPressed: widgetbookNoop,
                ),
              ),
              _AiIconPreview(
                label: 'Disabled',
                tokens: tokens,
                child: DesignSystemAiAssistantButton(
                  assetName: 'assets/design_system/ai_assistant_variant_1.png',
                  semanticLabel:
                      messages.designSystemNavigationAiAssistantSectionTitle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiIconPreview extends StatelessWidget {
  const _AiIconPreview({
    required this.label,
    required this.tokens,
    required this.child,
  });

  final String label;
  final DsTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Center(child: child),
        ),
      ],
    );
  }
}
