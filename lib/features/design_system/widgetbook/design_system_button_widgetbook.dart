import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_avatar_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_badge_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_branding_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_breadcrumbs_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_calendar_picker_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_caption_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_checkbox_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_chip_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_context_menu_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_divider_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_dropdown_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_header_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_list_item_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_navigation_sidebar_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_navigation_tab_bar_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_progress_bar_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_radio_button_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_scrollbar_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_search_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_spinner_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_split_button_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_tab_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_text_input_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_textarea_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_time_picker_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toast_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toggle_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_tooltip_icon_widgetbook.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_typography_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildDesignSystemWidgetbookFolder() {
  final children =
      <WidgetbookNode>[
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
        buildDesignSystemAvatarWidgetbookComponent(),
        buildDesignSystemBrandingWidgetbookComponent(),
        buildDesignSystemBadgeWidgetbookComponent(),
        buildDesignSystemChipWidgetbookComponent(),
        buildDesignSystemCaptionWidgetbookComponent(),
        buildDesignSystemBreadcrumbsWidgetbookComponent(),
        buildDesignSystemHeaderWidgetbookComponent(),
        buildDesignSystemSearchWidgetbookComponent(),
        buildDesignSystemToastWidgetbookComponent(),
        buildDesignSystemDividerWidgetbookComponent(),
        buildDesignSystemDropdownWidgetbookComponent(),
        buildDesignSystemSplitButtonWidgetbookComponent(),
        buildDesignSystemTabWidgetbookComponent(),
        buildDesignSystemListItemWidgetbookComponent(),
        buildDesignSystemNavigationSidebarWidgetbookComponent(),
        buildDesignSystemNavigationTabBarWidgetbookComponent(),
        buildDesignSystemCalendarPickerWidgetbookComponent(),
        buildDesignSystemProgressBarWidgetbookComponent(),
        buildDesignSystemToggleWidgetbookComponent(),
        buildDesignSystemRadioButtonWidgetbookComponent(),
        buildDesignSystemCheckboxWidgetbookComponent(),
        buildDesignSystemSpinnerWidgetbookComponent(),
        buildDesignSystemTimePickerWidgetbookComponent(),
        buildDesignSystemTextareaWidgetbookComponent(),
        buildDesignSystemScrollbarWidgetbookComponent(),
        buildDesignSystemTextInputWidgetbookComponent(),
        buildDesignSystemTooltipIconWidgetbookComponent(),
        buildDesignSystemContextMenuWidgetbookComponent(),
      ]..sort(
        (left, right) => left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        ),
      );

  return WidgetbookFolder(
    name: 'Design System',
    children: children,
  );
}

class _ButtonOverviewPage extends StatelessWidget {
  const _ButtonOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          _ButtonSection(
            title: 'Size Scale',
            child: _ButtonSizeScale(),
          ),
          SizedBox(height: 32),
          _ButtonSection(
            title: 'Variant Matrix',
            child: _ButtonVariantMatrix(),
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

class _ButtonVariantMatrix extends StatelessWidget {
  const _ButtonVariantMatrix();

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    for (final variant in DesignSystemButtonVariant.values)
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
    DesignSystemButtonSize.medium => 'Medium',
    DesignSystemButtonSize.large => 'Large',
    DesignSystemButtonSize.jumbo => 'Jumbo',
  };
}
