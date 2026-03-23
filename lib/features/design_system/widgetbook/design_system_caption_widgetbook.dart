import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/design_system_caption.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemCaptionWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Caption',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _CaptionOverviewPage(),
      ),
    ],
  );
}

class _CaptionOverviewPage extends StatelessWidget {
  const _CaptionOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _CaptionSection(
            title: context.messages.designSystemCaptionVariantsTitle,
            child: const _CaptionVariantMatrix(),
          ),
        ],
      ),
    );
  }
}

class _CaptionSection extends StatelessWidget {
  const _CaptionSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _CaptionVariantMatrix extends StatelessWidget {
  const _CaptionVariantMatrix();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final messages = context.messages;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        for (final iconPos in DesignSystemCaptionIconPosition.values)
          for (final hasActions in [false, true])
            SizedBox(
              width: 472,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_labelForIconPosition(context, iconPos)}, '
                    '${hasActions ? messages.designSystemCaptionWithActionsLabel : messages.designSystemCaptionWithoutActionsLabel}',
                    style: descriptionStyle,
                  ),
                  const SizedBox(height: 8),
                  DesignSystemCaption(
                    title: messages.designSystemCaptionTitleSample,
                    description: messages.designSystemCaptionDescriptionSample,
                    iconPosition: iconPos,
                    icon: iconPos != DesignSystemCaptionIconPosition.none
                        ? Icons.info_rounded
                        : null,
                    primaryAction: hasActions
                        ? DesignSystemButton(
                            label: 'Button label',
                            onPressed: () {},
                          )
                        : null,
                    secondaryAction: hasActions
                        ? DesignSystemButton(
                            label: 'Button label',
                            variant: DesignSystemButtonVariant.secondary,
                            onPressed: () {},
                          )
                        : null,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

String _labelForIconPosition(
  BuildContext context,
  DesignSystemCaptionIconPosition position,
) {
  final messages = context.messages;
  return switch (position) {
    DesignSystemCaptionIconPosition.none =>
      messages.designSystemCaptionNoIconLabel,
    DesignSystemCaptionIconPosition.left =>
      messages.designSystemCaptionIconLeftLabel,
    DesignSystemCaptionIconPosition.top =>
      messages.designSystemCaptionIconTopLabel,
  };
}
