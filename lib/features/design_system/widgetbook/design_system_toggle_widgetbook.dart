import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
        children: [
          _ToggleSection(
            title: context.messages.designSystemSizeScaleTitle,
            child: const _ToggleSizeScale(),
          ),
          const SizedBox(height: 32),
          _ToggleSection(
            title: context.messages.designSystemVariantMatrixTitle,
            child: const _ToggleVariantMatrix(),
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
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TogglePreview(
          config: _TogglePreviewConfig(
            size: DesignSystemToggleSize.small,
            label: context.messages.designSystemSmallLabel,
            value: false,
            tooltipIcon: Icons.info_outline_rounded,
          ),
        ),
        _TogglePreview(
          config: _TogglePreviewConfig(
            size: DesignSystemToggleSize.defaultSize,
            label: context.messages.designSystemDefaultLabel,
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
    final rows = _toggleRows(context);
    final variants = _toggleVariants(context);

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
                  _labelForSize(context, size),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final row in rows)
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
                            for (final variant in variants)
                              _TogglePreview(
                                config: _TogglePreviewConfig(
                                  size: size,
                                  value: variant.value,
                                  label: variant.label,
                                  semanticsLabel: variant.semanticsLabel,
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
      semanticsLabel: config.semanticsLabel,
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
    this.semanticsLabel,
    this.tooltipIcon,
    this.enabled = true,
    this.forcedState,
  });

  final DesignSystemToggleSize size;
  final bool value;
  final String? label;
  final String? semanticsLabel;
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
    this.semanticsLabel,
    this.tooltipIcon,
  });

  final bool value;
  final String? label;
  final String? semanticsLabel;
  final IconData? tooltipIcon;
}

List<_ToggleStateRow> _toggleRows(BuildContext context) {
  return [
    _ToggleStateRow(
      label: context.messages.designSystemDefaultLabel,
      enabled: true,
    ),
    _ToggleStateRow(
      label: context.messages.designSystemHoverLabel,
      enabled: true,
      state: DesignSystemToggleVisualState.hover,
    ),
    _ToggleStateRow(
      label: context.messages.designSystemDisabledLabel,
      enabled: false,
    ),
  ];
}

List<_ToggleVariant> _toggleVariants(BuildContext context) {
  final semanticsLabel = context.messages.designSystemToggleLabel;

  return [
    _ToggleVariant(
      value: false,
      semanticsLabel: semanticsLabel,
    ),
    _ToggleVariant(
      value: true,
      semanticsLabel: semanticsLabel,
    ),
    _ToggleVariant(
      value: false,
      label: semanticsLabel,
    ),
    _ToggleVariant(
      value: true,
      label: semanticsLabel,
    ),
    _ToggleVariant(
      value: false,
      label: semanticsLabel,
      tooltipIcon: Icons.info_outline_rounded,
    ),
    _ToggleVariant(
      value: true,
      label: semanticsLabel,
      tooltipIcon: Icons.info_outline_rounded,
    ),
  ];
}

String _labelForSize(BuildContext context, DesignSystemToggleSize size) {
  return switch (size) {
    DesignSystemToggleSize.small => context.messages.designSystemSmallLabel,
    DesignSystemToggleSize.defaultSize =>
      context.messages.designSystemDefaultLabel,
  };
}

void _noopToggle(bool value) {}
