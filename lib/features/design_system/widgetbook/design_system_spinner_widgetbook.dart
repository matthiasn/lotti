import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemSpinnerWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Spinner & loaders',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _SpinnerOverviewPage(),
      ),
    ],
  );
}

class _SpinnerOverviewPage extends StatelessWidget {
  const _SpinnerOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _SpinnerSection(
            title: context.messages.designSystemSpinnerSpinnersTitle,
            child: const _SpinnerVariants(),
          ),
          const SizedBox(height: 32),
          _SpinnerSection(
            title: context.messages.designSystemSpinnerSkeletonsTitle,
            child: const _SkeletonVariants(),
          ),
        ],
      ),
    );
  }
}

class _SpinnerSection extends StatelessWidget {
  const _SpinnerSection({
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

class _SpinnerVariants extends StatelessWidget {
  const _SpinnerVariants();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Wrap(
      spacing: 48,
      runSpacing: 24,
      children: [
        ...DesignSystemSpinnerStyle.values.map((style) {
          final label = _labelForStyle(context, style);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DesignSystemSpinner(
                style: style,
                semanticsLabel: label,
              ),
              const SizedBox(height: 8),
              Text(label, style: descriptionStyle),
            ],
          );
        }),
      ],
    );
  }
}

class _SkeletonVariants extends StatelessWidget {
  const _SkeletonVariants();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...DesignSystemSkeletonAnimation.values.expand((animation) {
          final label = _labelForAnimation(context, animation);
          return [
            Text(label, style: descriptionStyle),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: DesignSystemSkeleton(
                animation: animation,
                semanticsLabel: label,
              ),
            ),
            const SizedBox(height: 16),
          ];
        }),
      ],
    );
  }
}

String _labelForStyle(
  BuildContext context,
  DesignSystemSpinnerStyle style,
) {
  final messages = context.messages;
  return switch (style) {
    DesignSystemSpinnerStyle.plain => messages.designSystemSpinnerPlainLabel,
    DesignSystemSpinnerStyle.track => messages.designSystemSpinnerTrackLabel,
  };
}

String _labelForAnimation(
  BuildContext context,
  DesignSystemSkeletonAnimation animation,
) {
  final messages = context.messages;
  return switch (animation) {
    DesignSystemSkeletonAnimation.wave =>
      messages.designSystemSpinnerSkeletonWaveLabel,
    DesignSystemSkeletonAnimation.pulse =>
      messages.designSystemSpinnerSkeletonPulseLabel,
  };
}
