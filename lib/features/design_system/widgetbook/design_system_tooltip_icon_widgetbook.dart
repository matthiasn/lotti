import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/tooltip_icons/design_system_tooltip_icon.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTooltipIconWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Tooltip icon',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TooltipIconOverviewPage(),
      ),
    ],
  );
}

class _TooltipIconOverviewPage extends StatelessWidget {
  const _TooltipIconOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _TooltipIconSection(
            title: context.messages.designSystemTooltipIconVariantsTitle,
            child: const _TooltipIconVariants(),
          ),
        ],
      ),
    );
  }
}

class _TooltipIconSection extends StatelessWidget {
  const _TooltipIconSection({
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

class _TooltipIconVariants extends StatelessWidget {
  const _TooltipIconVariants();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final messages = context.messages;

    return Wrap(
      spacing: 48,
      runSpacing: 24,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignSystemTooltipIcon(
              message: messages.designSystemTooltipIconMessageSample,
            ),
            const SizedBox(height: 8),
            Text(
              messages.designSystemDefaultLabel,
              style: descriptionStyle,
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignSystemTooltipIcon(
              message: messages.designSystemTooltipIconMessageSample,
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 8),
            Text(
              messages.designSystemInfoLabel,
              style: descriptionStyle,
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignSystemTooltipIcon(
              message: messages.designSystemTooltipIconMessageSample,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 8),
            Text(
              messages.designSystemWarningLabel,
              style: descriptionStyle,
            ),
          ],
        ),
      ],
    );
  }
}
