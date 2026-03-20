import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemCheckboxWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Checkbox',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _CheckboxOverviewPage(),
      ),
    ],
  );
}

class _CheckboxOverviewPage extends StatelessWidget {
  const _CheckboxOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _CheckboxSection(
            title: 'Combination Scale',
            child: _CheckboxCombinationScale(),
          ),
          SizedBox(height: 32),
          _CheckboxSection(
            title: 'State Matrix',
            child: _CheckboxStateMatrix(),
          ),
        ],
      ),
    );
  }
}

class _CheckboxSection extends StatelessWidget {
  const _CheckboxSection({
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

class _CheckboxCombinationScale extends StatelessWidget {
  const _CheckboxCombinationScale();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _CheckboxPreviewTile(
          config: _CheckboxPreviewConfig(
            label: 'Checkbox label',
            value: false,
          ),
        ),
        _CheckboxPreviewTile(
          config: _CheckboxPreviewConfig(
            label: 'Checkbox label',
            value: true,
          ),
        ),
        _CheckboxPreviewTile(
          config: _CheckboxPreviewConfig(
            label: 'Checkbox label',
            value: null,
          ),
        ),
        _CheckboxPreviewTile(
          config: _CheckboxPreviewConfig(
            label: 'Checkbox label',
            value: false,
            enabled: false,
          ),
        ),
        _CheckboxPreviewTile(
          config: _CheckboxPreviewConfig(
            value: false,
          ),
        ),
        _CheckboxPreviewTile(
          config: _CheckboxPreviewConfig(
            value: true,
          ),
        ),
      ],
    );
  }
}

class _CheckboxStateMatrix extends StatelessWidget {
  const _CheckboxStateMatrix();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckboxStateRow(
          label: 'Enabled',
          config: _CheckboxRowConfig(),
        ),
        _CheckboxStateRow(
          label: 'Hover',
          config: _CheckboxRowConfig(
            state: DesignSystemCheckboxVisualState.hover,
          ),
        ),
        _CheckboxStateRow(
          label: 'Pressed',
          config: _CheckboxRowConfig(
            state: DesignSystemCheckboxVisualState.pressed,
          ),
        ),
        _CheckboxStateRow(
          label: 'Disabled',
          config: _CheckboxRowConfig(enabled: false),
        ),
      ],
    );
  }
}

class _CheckboxStateRow extends StatelessWidget {
  const _CheckboxStateRow({
    required this.label,
    required this.config,
  });

  final String label;
  final _CheckboxRowConfig config;

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
            children: [
              _CheckboxPreviewTile(
                config: _CheckboxPreviewConfig(
                  label: 'Checkbox label',
                  value: false,
                  enabled: config.enabled,
                  state: config.state,
                ),
              ),
              _CheckboxPreviewTile(
                config: _CheckboxPreviewConfig(
                  label: 'Checkbox label',
                  value: true,
                  enabled: config.enabled,
                  state: config.state,
                ),
              ),
              _CheckboxPreviewTile(
                config: _CheckboxPreviewConfig(
                  label: 'Checkbox label',
                  value: null,
                  enabled: config.enabled,
                  state: config.state,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckboxRowConfig {
  const _CheckboxRowConfig({
    this.state,
    this.enabled = true,
  });

  final DesignSystemCheckboxVisualState? state;
  final bool enabled;
}

class _CheckboxPreviewConfig {
  const _CheckboxPreviewConfig({
    required this.value,
    this.label,
    this.enabled = true,
    this.state,
  });

  final bool? value;
  final String? label;
  final bool enabled;
  final DesignSystemCheckboxVisualState? state;
}

class _CheckboxPreviewTile extends StatelessWidget {
  const _CheckboxPreviewTile({
    required this.config,
  });

  final _CheckboxPreviewConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemCheckbox(
          value: config.value,
          label: config.label,
          forcedState: config.state,
          onChanged: config.enabled ? (_) {} : null,
        ),
        const SizedBox(height: 8),
        Text(
          _previewLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String get _previewLabel {
    final valueLabel = switch (config.value) {
      true => 'Checked',
      false => 'Unchecked',
      null => 'Indeterminate',
    };
    final stateLabel = switch (config.state) {
      DesignSystemCheckboxVisualState.hover => ' / Hover',
      DesignSystemCheckboxVisualState.pressed => ' / Pressed',
      null || DesignSystemCheckboxVisualState.idle => '',
    };
    final enabledLabel = config.enabled ? '' : ' / Disabled';
    return '$valueLabel$stateLabel$enabledLabel';
  }
}
