import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildDesignSystemWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Design System',
    children: [
      WidgetbookComponent(
        name: 'Buttons',
        useCases: [
          WidgetbookUseCase(
            name: 'Variant Matrix',
            builder: (context) => const _ButtonVariantMatrix(),
          ),
          WidgetbookUseCase(
            name: 'Size Scale',
            builder: (context) => const _ButtonSizeScale(),
          ),
        ],
      ),
    ],
  );
}

class _ButtonVariantMatrix extends StatelessWidget {
  const _ButtonVariantMatrix();

  @override
  Widget build(BuildContext context) {
    const variants = <DesignSystemButtonVariant>[
      DesignSystemButtonVariant.primary,
      DesignSystemButtonVariant.secondary,
      DesignSystemButtonVariant.tertiary,
      DesignSystemButtonVariant.danger,
      DesignSystemButtonVariant.dangerSecondary,
      DesignSystemButtonVariant.dangerTertiary,
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in _stateRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final variant in variants)
                        DesignSystemButton(
                          label: _labelForVariant(variant),
                          variant: variant,
                          leadingIcon: Icons.add,
                          trailingIcon: Icons.keyboard_arrow_down,
                          forcedState: entry.state,
                          onPressed: entry.enabled ? () {} : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ButtonSizeScale extends StatelessWidget {
  const _ButtonSizeScale();

  @override
  Widget build(BuildContext context) {
    const sizes = <DesignSystemButtonSize>[
      DesignSystemButtonSize.small,
      DesignSystemButtonSize.medium,
      DesignSystemButtonSize.large,
      DesignSystemButtonSize.jumbo,
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final size in sizes)
            DesignSystemButton(
              label: _labelForSize(size),
              size: size,
              leadingIcon: Icons.add,
              trailingIcon: Icons.keyboard_arrow_down,
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}

class _StateRow {
  const _StateRow({
    required this.label,
    required this.enabled,
    this.state,
  });

  final String label;
  final bool enabled;
  final DesignSystemButtonVisualState? state;
}

const _stateRows = <_StateRow>[
  _StateRow(label: 'Default', enabled: true),
  _StateRow(
    label: 'Hover',
    enabled: true,
    state: DesignSystemButtonVisualState.hover,
  ),
  _StateRow(
    label: 'Pressed',
    enabled: true,
    state: DesignSystemButtonVisualState.pressed,
  ),
  _StateRow(label: 'Disabled', enabled: false),
];

String _labelForVariant(DesignSystemButtonVariant variant) {
  return switch (variant) {
    DesignSystemButtonVariant.primary => 'Primary',
    DesignSystemButtonVariant.secondary => 'Secondary',
    DesignSystemButtonVariant.tertiary => 'Tertiary',
    DesignSystemButtonVariant.danger => 'Danger',
    DesignSystemButtonVariant.dangerSecondary => 'Danger secondary',
    DesignSystemButtonVariant.dangerTertiary => 'Danger tertiary',
  };
}

String _labelForSize(DesignSystemButtonSize size) {
  return switch (size) {
    DesignSystemButtonSize.small => 'Small',
    DesignSystemButtonSize.medium => 'Default',
    DesignSystemButtonSize.large => 'Large',
    DesignSystemButtonSize.jumbo => 'Jumbo',
  };
}
