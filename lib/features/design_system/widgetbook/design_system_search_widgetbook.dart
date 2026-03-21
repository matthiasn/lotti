import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemSearchWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Search',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _SearchOverviewPage(),
      ),
    ],
  );
}

class _SearchOverviewPage extends StatelessWidget {
  const _SearchOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _SearchSection(
            title: context.messages.designSystemSizeScaleTitle,
            child: _SearchExamples(
              hintText: context.messages.designSystemSearchHintLabel,
            ),
          ),
          const SizedBox(height: 32),
          _SearchSection(
            title: context.messages.designSystemFilledLabel,
            child: _FilledSearchExamples(
              hintText: context.messages.designSystemSearchHintLabel,
              initialText: context.messages.designSystemSearchFilledText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
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

class _SearchExamples extends StatelessWidget {
  const _SearchExamples({
    required this.hintText,
  });

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _SearchSizeTile(
          label: context.messages.designSystemSmallLabel,
          child: SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: hintText,
              size: DesignSystemSearchSize.small,
              onSearchPressed: (_) {},
            ),
          ),
        ),
        _SearchSizeTile(
          label: context.messages.designSystemMediumLabel,
          child: SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: hintText,
              onSearchPressed: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}

class _FilledSearchExamples extends StatelessWidget {
  const _FilledSearchExamples({
    required this.hintText,
    required this.initialText,
  });

  final String hintText;
  final String initialText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _SearchSizeTile(
          label: context.messages.designSystemSmallLabel,
          child: SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: hintText,
              initialText: initialText,
              size: DesignSystemSearchSize.small,
              onSearchPressed: (_) {},
            ),
          ),
        ),
        _SearchSizeTile(
          label: context.messages.designSystemMediumLabel,
          child: SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: hintText,
              initialText: initialText,
              onSearchPressed: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchSizeTile extends StatelessWidget {
  const _SearchSizeTile({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
