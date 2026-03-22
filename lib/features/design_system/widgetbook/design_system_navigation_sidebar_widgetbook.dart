import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_time_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemNavigationSidebarWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Navigation Sidebar',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _NavigationSidebarOverviewPage(),
      ),
    ],
  );
}

class _NavigationSidebarOverviewPage extends StatelessWidget {
  const _NavigationSidebarOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WidgetbookSection(
              title: context.messages.designSystemNavigationSidebarSectionTitle,
              child: const _SidebarShowcase(),
            ),
            const SizedBox(height: 32),
            WidgetbookSection(
              title: context
                  .messages
                  .designSystemNavigationDailyFilterSectionTitle,
              child: const _DailyFilterShowcase(),
            ),
            const SizedBox(height: 32),
            WidgetbookSection(
              title: context
                  .messages
                  .designSystemNavigationAiAssistantSectionTitle,
              child: const _AiAssistantShowcase(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCase extends StatelessWidget {
  const _PreviewCase({
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
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SidebarShowcase extends StatelessWidget {
  const _SidebarShowcase();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _PreviewCase(
          label: context.messages.designSystemNavigationExpandedLabel,
          child: _SidebarFrame(
            brightness: brightness,
            expanded: true,
          ),
        ),
        _PreviewCase(
          label: context.messages.designSystemNavigationCollapsedLabel,
          child: _SidebarFrame(
            brightness: brightness,
            expanded: false,
          ),
        ),
      ],
    );
  }
}

class _SidebarFrame extends StatelessWidget {
  const _SidebarFrame({
    required this.brightness,
    required this.expanded,
  });

  final Brightness brightness;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = _SidebarPalette.fromTokens(
      context.designTokens,
      brightness,
    );

    return Container(
      width: expanded ? 320 : 76,
      height: 900,
      padding: EdgeInsets.fromLTRB(
        context.designTokens.spacing.step5,
        context.designTokens.spacing.step6,
        context.designTokens.spacing.step5,
        context.designTokens.spacing.step6,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(context.designTokens.radii.s),
        border: Border.all(color: palette.border),
      ),
      child: expanded
          ? _ExpandedSidebarContent(palette: palette)
          : _CollapsedSidebarContent(palette: palette),
    );
  }
}

class _ExpandedSidebarContent extends StatelessWidget {
  const _ExpandedSidebarContent({required this.palette});

  final _SidebarPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarLogoRow(
          palette: palette,
          expanded: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 288,
          height: 56,
          child: Stack(
            children: [
              DesignSystemButton(
                label: context.messages.designSystemNavigationNewLabel,
                size: DesignSystemButtonSize.medium,
                leadingIcon: Icons.add_rounded,
                trailingIcon: Icons.keyboard_arrow_down_rounded,
                onPressed: widgetbookNoop,
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: _AiAssistantFab(variant: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final destination in widgetbookNavigationDestinations(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _SidebarNavItem(
              destination: destination,
              palette: palette,
            ),
          ),
        const SizedBox(height: 24),
        _SidebarCalendarPreview(mode: palette.calendarMode),
      ],
    );
  }
}

class _CollapsedSidebarContent extends StatelessWidget {
  const _CollapsedSidebarContent({required this.palette});

  final _SidebarPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarLogoRow(
          palette: palette,
          expanded: false,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 100,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: DesignSystemButton(
                  label: '',
                  leadingIcon: Icons.add_rounded,
                  semanticsLabel:
                      context.messages.designSystemNavigationNewLabel,
                  onPressed: widgetbookNoop,
                ),
              ),
              const Positioned(
                top: 0,
                left: 54,
                child: _AiAssistantFab(variant: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarLogoRow extends StatelessWidget {
  const _SidebarLogoRow({
    required this.palette,
    required this.expanded,
  });

  final _SidebarPalette palette;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(
            Icons.menu_rounded,
            size: 24,
            color: palette.iconColor,
          ),
          if (expanded) ...[
            const SizedBox(width: 16),
            const DesignSystemBrandLogo(),
          ],
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.destination,
    required this.palette,
  });

  final WidgetbookNavigationDestination destination;
  final _SidebarPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: destination.active,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widgetbookNoop,
          child: Ink(
            width: 288,
            height: 48,
            decoration: BoxDecoration(
              color: destination.active
                  ? palette.activeFill
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                context.designTokens.radii.m,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.designTokens.spacing.step5,
              ),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    size: 20,
                    color: palette.iconColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    destination.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarCalendarPreview extends StatelessWidget {
  const _SidebarCalendarPreview({required this.mode});

  final DesignSystemTimeCalendarPickerMode mode;

  @override
  Widget build(BuildContext context) {
    return DesignSystemInteractiveTimeCalendarPicker(
      mode: mode,
      presentation: DesignSystemTimeCalendarPickerPresentation.compact,
      initialSelectedDate: DateTime(2025, 4, 17),
      currentDate: DateTime(2025, 4),
    );
  }
}

class _SidebarPalette {
  const _SidebarPalette({
    required this.surface,
    required this.border,
    required this.iconColor,
    required this.primaryTextColor,
    required this.activeFill,
    required this.calendarMode,
  });

  factory _SidebarPalette.fromTokens(DsTokens tokens, Brightness brightness) {
    return _SidebarPalette(
      surface: tokens.colors.background.level02,
      border: tokens.colors.decorative.level01,
      iconColor: tokens.colors.text.mediumEmphasis,
      primaryTextColor: tokens.colors.text.highEmphasis,
      activeFill: tokens.colors.surface.active,
      calendarMode: brightness == Brightness.dark
          ? DesignSystemTimeCalendarPickerMode.dark
          : DesignSystemTimeCalendarPickerMode.light,
    );
  }

  final Color surface;
  final Color border;
  final Color iconColor;
  final Color primaryTextColor;
  final Color activeFill;
  final DesignSystemTimeCalendarPickerMode calendarMode;
}

class _DailyFilterShowcase extends StatelessWidget {
  const _DailyFilterShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _PreviewCase(
          label: context.messages.designSystemNavigationExpandedLabel,
          child: const _DailyFilterCard(open: true),
        ),
        _PreviewCase(
          label: context.messages.designSystemNavigationCollapsedLabel,
          child: const _DailyFilterCard(open: false),
        ),
      ],
    );
  }
}

class _DailyFilterCard extends StatelessWidget {
  const _DailyFilterCard({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: 288,
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: tokens.spacing.step4,
            offset: Offset(0, tokens.spacing.step2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.messages.designSystemNavigationFilterByBlockLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 20,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ],
          ),
          if (open) ...[
            SizedBox(height: tokens.spacing.step5),
            _DailyFilterChip(
              label: context.messages.designSystemNavigationHolidayLabel,
              fillColor: const Color(0x3D9500FF),
              borderColor: const Color(0xFF9500FF),
            ),
            SizedBox(height: tokens.spacing.step3),
            _DailyFilterChip(
              label: context.messages.designSystemNavigationLottiTasksLabel,
              fillColor: tokens.colors.alert.info.defaultColor.withValues(
                alpha: 0.24,
              ),
              borderColor: tokens.colors.alert.info.defaultColor,
            ),
            SizedBox(height: tokens.spacing.step3),
            _DailyFilterChip(
              label: context.messages.designSystemNavigationHikingLabel,
              fillColor: tokens.colors.alert.warning.defaultColor.withValues(
                alpha: 0.24,
              ),
              borderColor: tokens.colors.alert.warning.defaultColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyFilterChip extends StatelessWidget {
  const _DailyFilterChip({
    required this.label,
    required this.fillColor,
    required this.borderColor,
  });

  final String label;
  final Color fillColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step3,
        tokens.spacing.step1,
        tokens.spacing.step5,
        tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}

class _AiAssistantShowcase extends StatelessWidget {
  const _AiAssistantShowcase();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.step6),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AiAssistantFab(variant: 1),
          SizedBox(width: 24),
          _AiAssistantFab(variant: 2),
        ],
      ),
    );
  }
}

class _AiAssistantFab extends StatelessWidget {
  const _AiAssistantFab({required this.variant});

  final int variant;

  @override
  Widget build(BuildContext context) {
    final icon = switch (variant) {
      1 => Icons.auto_awesome_rounded,
      _ => Icons.auto_awesome_mosaic_rounded,
    };

    return Semantics(
      button: true,
      label: context.messages.designSystemNavigationAiAssistantSectionTitle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widgetbookNoop,
              child: Ink(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFF7300FF),
                      Color(0xFF0066FF),
                      Color(0xFF00E6CC),
                      Color(0xFFFF66B3),
                      Color(0xFFFF9900),
                      Color(0xFFE60080),
                      Color(0xFF7300FF),
                    ],
                  ),
                  border: Border.all(
                    color: context.designTokens.colors.decorative.level01,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x594D33CC),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Color(0x264D33CC),
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: _AiAssistantBadge(),
          ),
        ],
      ),
    );
  }
}

class _AiAssistantBadge extends StatelessWidget {
  const _AiAssistantBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF0500),
            Color(0xFF990300),
          ],
        ),
      ),
    );
  }
}
