import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_badge_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_calendar_picker_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_checkbox_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_chip_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_dropdown_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_progress_bar_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_radio_button_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_split_button_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_tab_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toggle_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_typography_widgetbook.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildDesignSystemWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Design System',
    children: [
      buildDesignSystemTypographyWidgetbookComponent(),
      WidgetbookComponent(
        name: 'Buttons',
        useCases: [
          WidgetbookUseCase(
            name: 'Overview',
            builder: (context) => const _ButtonOverviewPage(),
          ),
        ],
      ),
      buildDesignSystemBadgeWidgetbookComponent(),
      buildDesignSystemChipWidgetbookComponent(),
      buildDesignSystemDropdownWidgetbookComponent(),
      buildDesignSystemSplitButtonWidgetbookComponent(),
      buildDesignSystemTabWidgetbookComponent(),
      buildDesignSystemCalendarPickerWidgetbookComponent(),
      buildDesignSystemProgressBarWidgetbookComponent(),
      buildDesignSystemToggleWidgetbookComponent(),
      buildDesignSystemRadioButtonWidgetbookComponent(),
      buildDesignSystemCheckboxWidgetbookComponent(),
    ],
  );
}

class _ButtonOverviewPage extends StatelessWidget {
  const _ButtonOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _ButtonSection(
            title: context.messages.designSystemSizeScaleTitle,
            child: const _ButtonSizeScale(),
          ),
          const SizedBox(height: 32),
          _ButtonSection(
            title: context.messages.designSystemVariantMatrixTitle,
            child: const _ButtonVariantMatrix(),
          ),
        ],
      ),
    );
  }
}

class _ButtonSection extends StatelessWidget {
  const _ButtonSection({
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

class _ButtonSizeScale extends StatelessWidget {
  const _ButtonSizeScale();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final size in DesignSystemButtonSize.values)
            DesignSystemButton(
              label: _labelForSize(context, size),
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

class _ButtonVariantMatrix extends StatelessWidget {
  const _ButtonVariantMatrix();

  @override
  Widget build(BuildContext context) {
    final stateRows = _stateRows(context);
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in stateRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: descriptionStyle,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final variant in DesignSystemButtonVariant.values)
                      DesignSystemButton(
                        label: _labelForVariant(context, variant),
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

List<_StateRow> _stateRows(BuildContext context) {
  final messages = context.messages;
  return [
    _StateRow(label: messages.designSystemDefaultLabel, enabled: true),
    _StateRow(
      label: messages.designSystemHoverLabel,
      enabled: true,
      state: DesignSystemButtonVisualState.hover,
    ),
    _StateRow(
      label: messages.designSystemPressedLabel,
      enabled: true,
      state: DesignSystemButtonVisualState.pressed,
    ),
    _StateRow(label: messages.designSystemDisabledLabel, enabled: false),
  ];
}

String _labelForVariant(
  BuildContext context,
  DesignSystemButtonVariant variant,
) {
  final messages = context.messages;
  return switch (variant) {
    DesignSystemButtonVariant.primary =>
      messages.designSystemButtonPrimaryLabel,
    DesignSystemButtonVariant.secondary =>
      messages.designSystemButtonSecondaryLabel,
    DesignSystemButtonVariant.tertiary =>
      messages.designSystemButtonTertiaryLabel,
    DesignSystemButtonVariant.danger => messages.designSystemButtonDangerLabel,
    DesignSystemButtonVariant.dangerSecondary =>
      messages.designSystemButtonDangerSecondaryLabel,
    DesignSystemButtonVariant.dangerTertiary =>
      messages.designSystemButtonDangerTertiaryLabel,
  };
}

String _labelForSize(BuildContext context, DesignSystemButtonSize size) {
  final messages = context.messages;
  return switch (size) {
    DesignSystemButtonSize.small => messages.designSystemSmallLabel,
    DesignSystemButtonSize.medium => messages.designSystemMediumLabel,
    DesignSystemButtonSize.large => messages.designSystemLargeLabel,
    DesignSystemButtonSize.jumbo => messages.designSystemJumboLabel,
  };
}
