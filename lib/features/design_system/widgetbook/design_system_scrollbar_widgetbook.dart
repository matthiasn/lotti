import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemScrollbarWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Scrollbar',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ScrollbarOverviewPage(),
      ),
    ],
  );
}

class _ScrollbarOverviewPage extends StatelessWidget {
  const _ScrollbarOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _ScrollbarSection(
            title: context.messages.designSystemScrollbarSizesTitle,
            child: const _ScrollbarSizes(),
          ),
        ],
      ),
    );
  }
}

class _ScrollbarSection extends StatelessWidget {
  const _ScrollbarSection({
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

class _ScrollbarSizes extends StatelessWidget {
  const _ScrollbarSizes();

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
      children: [
        for (final size in DesignSystemScrollbarSize.values)
          SizedBox(
            width: 200,
            height: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  size == DesignSystemScrollbarSize.small
                      ? messages.designSystemSmallLabel
                      : messages.designSystemDefaultLabel,
                  style: descriptionStyle,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DesignSystemScrollbar(
                    size: size,
                    child: ListView.builder(
                      itemCount: 20,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('Item ${index + 1}'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
