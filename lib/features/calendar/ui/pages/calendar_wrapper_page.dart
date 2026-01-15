import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/calendar/state/calendar_view_mode_controller.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Wrapper page that allows toggling between classic calendar and Daily OS views.
///
/// This maintains parallel implementation of both views while allowing
/// users to choose their preferred interface.
class CalendarWrapperPage extends ConsumerWidget {
  const CalendarWrapperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(calendarViewModeControllerProvider);

    return Stack(
      children: [
        // Main content based on view mode
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: viewMode == CalendarViewMode.classic
              ? const DayViewPage(key: ValueKey('classic'))
              : const DailyOsPage(key: ValueKey('daily_os')),
        ),

        // View mode toggle button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: _ViewModeToggle(
            currentMode: viewMode,
            onToggle: () {
              ref
                  .read(calendarViewModeControllerProvider.notifier)
                  .toggleViewMode();
            },
          ),
        ),
      ],
    );
  }
}

/// Toggle button for switching between view modes.
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({
    required this.currentMode,
    required this.onToggle,
  });

  final CalendarViewMode currentMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isClassic = currentMode == CalendarViewMode.classic;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSmall,
            vertical: AppTheme.spacingSmall / 2,
          ),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isClassic ? MdiIcons.calendarMonth : MdiIcons.sunCompass,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isClassic ? 'Daily OS' : 'Classic',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                MdiIcons.swapHorizontal,
                size: 14,
                color: context.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
