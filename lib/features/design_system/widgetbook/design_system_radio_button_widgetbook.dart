import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemRadioButtonWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Radio buttons',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _RadioButtonOverviewPage(),
      ),
    ],
  );
}

class _RadioButtonOverviewPage extends StatelessWidget {
  const _RadioButtonOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _RadioButtonSection(
            title: 'Size Scale',
            child: _RadioButtonSizeScale(),
          ),
          SizedBox(height: 32),
          _RadioButtonSection(
            title: 'State Matrix',
            child: _RadioButtonStateMatrix(),
          ),
        ],
      ),
    );
  }
}

class _RadioButtonSection extends StatelessWidget {
  const _RadioButtonSection({
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

class _RadioButtonSizeScale extends StatelessWidget {
  const _RadioButtonSizeScale();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.defaultSize,
            label: 'Radio button',
            showTooltipIcon: true,
            selected: false,
          ),
        ),
        _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.large,
            label: 'Radio button',
            showTooltipIcon: true,
            selected: false,
          ),
        ),
        _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.defaultSize,
            selected: true,
          ),
        ),
        _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.large,
            selected: true,
          ),
        ),
      ],
    );
  }
}

class _RadioButtonStateMatrix extends StatelessWidget {
  const _RadioButtonStateMatrix();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RadioButtonMatrixRow(
          label: 'Default',
          children: [
            for (final config in _radioButtonMatrixConfigs)
              _RadioButtonPreviewTile(
                config: config,
              ),
          ],
        ),
        _RadioButtonMatrixRow(
          label: 'Hover',
          children: [
            for (final config in _radioButtonMatrixConfigs)
              _RadioButtonPreviewTile(
                config: config.copyWith(
                  forcedState: DesignSystemRadioButtonVisualState.hover,
                ),
              ),
          ],
        ),
        _RadioButtonMatrixRow(
          label: 'Disabled',
          children: [
            for (final config in _radioButtonMatrixConfigs)
              _RadioButtonPreviewTile(
                config: config.copyWith(enabled: false),
              ),
          ],
        ),
      ],
    );
  }
}

class _RadioButtonMatrixRow extends StatelessWidget {
  const _RadioButtonMatrixRow({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _RadioButtonPreviewConfig {
  const _RadioButtonPreviewConfig({
    required this.size,
    required this.selected,
    this.label,
    this.showTooltipIcon = false,
    this.enabled = true,
    this.forcedState,
  });

  final DesignSystemRadioButtonSize size;
  final bool selected;
  final String? label;
  final bool showTooltipIcon;
  final bool enabled;
  final DesignSystemRadioButtonVisualState? forcedState;

  _RadioButtonPreviewConfig copyWith({
    DesignSystemRadioButtonSize? size,
    bool? selected,
    String? label,
    bool? showTooltipIcon,
    bool? enabled,
    DesignSystemRadioButtonVisualState? forcedState,
  }) {
    return _RadioButtonPreviewConfig(
      size: size ?? this.size,
      selected: selected ?? this.selected,
      label: label ?? this.label,
      showTooltipIcon: showTooltipIcon ?? this.showTooltipIcon,
      enabled: enabled ?? this.enabled,
      forcedState: forcedState ?? this.forcedState,
    );
  }
}

const _radioButtonMatrixConfigs = <_RadioButtonPreviewConfig>[
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.defaultSize,
    selected: false,
    label: 'Radio button',
    showTooltipIcon: true,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.defaultSize,
    selected: false,
    label: 'Radio button',
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.defaultSize,
    selected: false,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.defaultSize,
    selected: true,
    label: 'Radio button',
    showTooltipIcon: true,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.defaultSize,
    selected: true,
    label: 'Radio button',
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.defaultSize,
    selected: true,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.large,
    selected: false,
    label: 'Radio button',
    showTooltipIcon: true,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.large,
    selected: false,
    label: 'Radio button',
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.large,
    selected: false,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.large,
    selected: true,
    label: 'Radio button',
    showTooltipIcon: true,
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.large,
    selected: true,
    label: 'Radio button',
  ),
  _RadioButtonPreviewConfig(
    size: DesignSystemRadioButtonSize.large,
    selected: true,
  ),
];

class _RadioButtonPreviewTile extends StatelessWidget {
  const _RadioButtonPreviewTile({
    required this.config,
  });

  final _RadioButtonPreviewConfig config;

  @override
  Widget build(BuildContext context) {
    return DesignSystemRadioButton(
      selected: config.selected,
      size: config.size,
      label: config.label,
      showTooltipIcon: config.showTooltipIcon,
      forcedState: config.forcedState,
      onPressed: config.enabled ? _noop : null,
    );
  }
}

void _noop() {}
