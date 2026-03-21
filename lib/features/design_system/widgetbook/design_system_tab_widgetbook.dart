import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTabWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Tabs',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TabOverviewPage(),
      ),
    ],
  );
}

class _TabOverviewPage extends StatelessWidget {
  const _TabOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _TabSection(
            title: context.messages.designSystemSizeScaleTitle,
            child: const _TabSizeScale(),
          ),
          const SizedBox(height: 32),
          _TabSection(
            title: context.messages.designSystemStateMatrixTitle,
            child: const _TabStateMatrix(),
          ),
        ],
      ),
    );
  }
}

class _TabSection extends StatelessWidget {
  const _TabSection({
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

class _TabSizeScale extends StatelessWidget {
  const _TabSizeScale();

  @override
  Widget build(BuildContext context) {
    final label = context.messages.designSystemTabPendingLabel;

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DesignSystemTab(
          selected: false,
          size: DesignSystemTabSize.small,
          label: label,
          counter: '10',
          trailingIcon: Icons.close_rounded,
          onPressed: _noop,
        ),
        DesignSystemTab(
          selected: false,
          size: DesignSystemTabSize.defaultSize,
          label: label,
          counter: '10',
          trailingIcon: Icons.close_rounded,
          onPressed: _noop,
        ),
      ],
    );
  }
}

class _TabStateMatrix extends StatelessWidget {
  const _TabStateMatrix();

  @override
  Widget build(BuildContext context) {
    final rows = _tabStateRows(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final size in DesignSystemTabSize.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelForSize(context, size),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final row in rows)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          DesignSystemTab(
                            selected: row.selected,
                            size: size,
                            label: context.messages.designSystemTabPendingLabel,
                            counter: '10',
                            trailingIcon: Icons.close_rounded,
                            forcedState: row.state,
                            onPressed: row.enabled ? _noop : null,
                          ),
                        ],
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

class _TabStateRow {
  const _TabStateRow({
    required this.label,
    required this.enabled,
    required this.selected,
    this.state,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final DesignSystemTabVisualState? state;
}

List<_TabStateRow> _tabStateRows(BuildContext context) {
  return [
    _TabStateRow(
      label: context.messages.designSystemDefaultLabel,
      enabled: true,
      selected: false,
    ),
    _TabStateRow(
      label: context.messages.designSystemHoverLabel,
      enabled: true,
      selected: false,
      state: DesignSystemTabVisualState.hover,
    ),
    _TabStateRow(
      label: context.messages.designSystemPressedLabel,
      enabled: true,
      selected: false,
      state: DesignSystemTabVisualState.pressed,
    ),
    _TabStateRow(
      label: context.messages.designSystemActivatedLabel,
      enabled: true,
      selected: true,
    ),
    _TabStateRow(
      label: context.messages.designSystemDisabledLabel,
      enabled: false,
      selected: false,
    ),
  ];
}

String _labelForSize(BuildContext context, DesignSystemTabSize size) {
  return switch (size) {
    DesignSystemTabSize.small => context.messages.designSystemSmallLabel,
    DesignSystemTabSize.defaultSize =>
      context.messages.designSystemDefaultLabel,
  };
}

void _noop() {}
