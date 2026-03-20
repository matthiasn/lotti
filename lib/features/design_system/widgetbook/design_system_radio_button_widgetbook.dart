import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
        children: [
          _RadioButtonSection(
            title: context.messages.designSystemSizeScaleTitle,
            child: const _RadioButtonSizeScale(),
          ),
          const SizedBox(height: 32),
          _RadioButtonSection(
            title: context.messages.designSystemStateMatrixTitle,
            child: const _RadioButtonStateMatrix(),
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
    final label = context.messages.designSystemRadioButtonLabel;

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.defaultSize,
            label: label,
            showTooltipIcon: true,
            selected: false,
          ),
        ),
        _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.large,
            label: label,
            showTooltipIcon: true,
            selected: false,
          ),
        ),
        const _RadioButtonPreviewTile(
          config: _RadioButtonPreviewConfig(
            size: DesignSystemRadioButtonSize.defaultSize,
            selected: true,
          ),
        ),
        const _RadioButtonPreviewTile(
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
    final configs = _radioButtonMatrixConfigs(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RadioButtonMatrixRow(
          label: context.messages.designSystemDefaultLabel,
          children: [
            for (final config in configs)
              _RadioButtonPreviewTile(
                config: config,
              ),
          ],
        ),
        _RadioButtonMatrixRow(
          label: context.messages.designSystemHoverLabel,
          children: [
            for (final config in configs)
              _RadioButtonPreviewTile(
                config: config.copyWith(
                  forcedState: DesignSystemRadioButtonVisualState.hover,
                ),
              ),
          ],
        ),
        _RadioButtonMatrixRow(
          label: context.messages.designSystemDisabledLabel,
          children: [
            for (final config in configs)
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

List<_RadioButtonPreviewConfig> _radioButtonMatrixConfigs(
  BuildContext context,
) {
  final label = context.messages.designSystemRadioButtonLabel;

  return [
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.defaultSize,
      selected: false,
      label: label,
      showTooltipIcon: true,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.defaultSize,
      selected: false,
      label: label,
    ),
    const _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.defaultSize,
      selected: false,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.defaultSize,
      selected: true,
      label: label,
      showTooltipIcon: true,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.defaultSize,
      selected: true,
      label: label,
    ),
    const _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.defaultSize,
      selected: true,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.large,
      selected: false,
      label: label,
      showTooltipIcon: true,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.large,
      selected: false,
      label: label,
    ),
    const _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.large,
      selected: false,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.large,
      selected: true,
      label: label,
      showTooltipIcon: true,
    ),
    _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.large,
      selected: true,
      label: label,
    ),
    const _RadioButtonPreviewConfig(
      size: DesignSystemRadioButtonSize.large,
      selected: true,
    ),
  ];
}

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
