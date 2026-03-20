import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemToggleWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Toggle',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ToggleOverviewPage(),
      ),
    ],
  );
}

class _ToggleOverviewPage extends StatelessWidget {
  const _ToggleOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _ToggleSection(
            title: 'Size Scale',
            child: _ToggleSizeScale(),
          ),
          SizedBox(height: 32),
          _ToggleSection(
            title: 'Variant Matrix',
            child: _ToggleVariantMatrix(),
          ),
        ],
      ),
    );
  }
}

class _ToggleSection extends StatelessWidget {
  const _ToggleSection({
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

class _ToggleSizeScale extends StatelessWidget {
  const _ToggleSizeScale();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TogglePreview(
          config: _TogglePreviewConfig(
            size: DesignSystemToggleSize.small,
            label: 'Small',
            value: false,
            tooltipIcon: Icons.info_outline_rounded,
          ),
        ),
        _TogglePreview(
          config: _TogglePreviewConfig(
            size: DesignSystemToggleSize.defaultSize,
            label: 'Default',
            value: false,
            tooltipIcon: Icons.info_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _ToggleVariantMatrix extends StatelessWidget {
  const _ToggleVariantMatrix();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final size in DesignSystemToggleSize.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelForSize(size),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final row in _toggleRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final variant in _toggleVariants)
                              _TogglePreview(
                                config: _TogglePreviewConfig(
                                  size: size,
                                  value: variant.value,
                                  label: variant.label,
                                  tooltipIcon: variant.tooltipIcon,
                                  enabled: row.enabled,
                                  forcedState: row.state,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TogglePreview extends StatelessWidget {
  const _TogglePreview({
    required this.config,
  });

  final _TogglePreviewConfig config;

  @override
  Widget build(BuildContext context) {
    return DesignSystemToggle(
      size: config.size,
      value: config.value,
      label: config.label,
      tooltipIcon: config.tooltipIcon,
      enabled: config.enabled,
      forcedState: config.forcedState,
      onChanged: _noopToggle,
    );
  }
}

class _TogglePreviewConfig {
  const _TogglePreviewConfig({
    required this.size,
    required this.value,
    this.label,
    this.tooltipIcon,
    this.enabled = true,
    this.forcedState,
  });

  final DesignSystemToggleSize size;
  final bool value;
  final String? label;
  final IconData? tooltipIcon;
  final bool enabled;
  final DesignSystemToggleVisualState? forcedState;
}

class _ToggleStateRow {
  const _ToggleStateRow({
    required this.label,
    required this.enabled,
    this.state,
  });

  final String label;
  final bool enabled;
  final DesignSystemToggleVisualState? state;
}

class _ToggleVariant {
  const _ToggleVariant({
    required this.value,
    this.label,
    this.tooltipIcon,
  });

  final bool value;
  final String? label;
  final IconData? tooltipIcon;
}

const _toggleRows = <_ToggleStateRow>[
  _ToggleStateRow(label: 'Default', enabled: true),
  _ToggleStateRow(
    label: 'Hover',
    enabled: true,
    state: DesignSystemToggleVisualState.hover,
  ),
  _ToggleStateRow(label: 'Disabled', enabled: false),
];

const _toggleVariants = <_ToggleVariant>[
  _ToggleVariant(value: false),
  _ToggleVariant(value: true),
  _ToggleVariant(value: false, label: 'Toggle label'),
  _ToggleVariant(value: true, label: 'Toggle label'),
  _ToggleVariant(
    value: false,
    label: 'Toggle label',
    tooltipIcon: Icons.info_outline_rounded,
  ),
  _ToggleVariant(
    value: true,
    label: 'Toggle label',
    tooltipIcon: Icons.info_outline_rounded,
  ),
];

String _labelForSize(DesignSystemToggleSize size) {
  return switch (size) {
    DesignSystemToggleSize.small => 'Small',
    DesignSystemToggleSize.defaultSize => 'Default',
  };
}

void _noopToggle(bool value) {}
