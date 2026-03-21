import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemProgressBarWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Progress bar',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ProgressBarOverviewPage(),
      ),
    ],
  );
}

class _ProgressBarOverviewPage extends StatelessWidget {
  const _ProgressBarOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _ProgressBarSection(
            title: context.messages.designSystemVariantMatrixTitle,
            child: const _ProgressBarVariantMatrix(),
          ),
        ],
      ),
    );
  }
}

class _ProgressBarSection extends StatelessWidget {
  const _ProgressBarSection({
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

class _ProgressBarVariantMatrix extends StatelessWidget {
  const _ProgressBarVariantMatrix();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final style in DesignSystemProgressBarStyle.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelForStyle(context, style),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    for (final variant in _progressBarVariants(context, style))
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              variant.label,
                              style: descriptionStyle,
                            ),
                            const SizedBox(height: 16),
                            DesignSystemProgressBar(
                              value: variant.value,
                              style: style,
                              label: variant.headerLabel,
                              progressText: variant.progressText,
                              trailingIcon: variant.trailingIcon,
                              semanticsLabel: variant.semanticsLabel,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProgressBarVariant {
  const _ProgressBarVariant({
    required this.label,
    required this.value,
    required this.semanticsLabel,
    this.headerLabel,
    this.progressText,
    this.trailingIcon,
  });

  final String label;
  final double value;
  final String semanticsLabel;
  final String? headerLabel;
  final String? progressText;
  final IconData? trailingIcon;
}

List<_ProgressBarVariant> _progressBarVariants(
  BuildContext context,
  DesignSystemProgressBarStyle style,
) {
  final defaultLabel = context.messages.designSystemProgressBarSampleLabel;
  final questLabel = context.messages.designSystemProgressBarQuestLabel;
  final progressText = switch (style) {
    DesignSystemProgressBarStyle.defaultStyle => '70%',
    DesignSystemProgressBarStyle.chunky => '60%',
  };
  final progressValue = switch (style) {
    DesignSystemProgressBarStyle.defaultStyle => 0.7,
    DesignSystemProgressBarStyle.chunky => 0.6,
  };
  final questProgressText = switch (style) {
    DesignSystemProgressBarStyle.defaultStyle => '45/60',
    DesignSystemProgressBarStyle.chunky => '60%',
  };

  return [
    _ProgressBarVariant(
      label: context.messages.designSystemProgressBarLabelAndPercentageLabel,
      value: progressValue,
      semanticsLabel: defaultLabel,
      headerLabel: defaultLabel,
      progressText: progressText,
      trailingIcon: Icons.star_outline_rounded,
    ),
    _ProgressBarVariant(
      label: context.messages.designSystemProgressBarLabelOnlyLabel,
      value: progressValue,
      semanticsLabel: defaultLabel,
      headerLabel: defaultLabel,
    ),
    _ProgressBarVariant(
      label: context.messages.designSystemProgressBarPercentageOnlyLabel,
      value: progressValue,
      semanticsLabel: defaultLabel,
      progressText: progressText,
      trailingIcon: Icons.star_outline_rounded,
    ),
    _ProgressBarVariant(
      label: context.messages.designSystemProgressBarOffLabel,
      value: progressValue,
      semanticsLabel: defaultLabel,
    ),
    _ProgressBarVariant(
      label: context.messages.designSystemProgressBarQuestBarLabel,
      value: progressValue,
      semanticsLabel: questLabel,
      headerLabel: questLabel,
      progressText: questProgressText,
      trailingIcon: Icons.star_outline_rounded,
    ),
  ];
}

String _labelForStyle(
  BuildContext context,
  DesignSystemProgressBarStyle style,
) {
  return switch (style) {
    DesignSystemProgressBarStyle.defaultStyle =>
      context.messages.designSystemDefaultLabel,
    DesignSystemProgressBarStyle.chunky =>
      context.messages.designSystemProgressBarChunkyLabel,
  };
}
