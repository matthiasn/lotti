import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/utils/consts.dart';

/// Wrapper page that shows either classic calendar or Daily OS view based on
/// the config flag.
class CalendarWrapperPage extends ConsumerWidget {
  const CalendarWrapperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyOsEnabledAsync =
        ref.watch(configFlagProvider(enableDailyOsFlag));

    return dailyOsEnabledAsync.when(
      data: (dailyOsEnabled) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: dailyOsEnabled
              ? const DailyOsPage(key: ValueKey('daily_os'))
              : const DayViewPage(key: ValueKey('classic')),
        );
      },
      loading: () => const DayViewPage(),
      error: (_, __) => const DayViewPage(),
    );
  }
}
