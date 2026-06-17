import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_filter.dart';
import 'package:lotti/features/habits/ui/widgets/habits_search.dart';
import 'package:lotti/features/habits/ui/widgets/habits_tool_button.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The Habits tab header — the calm title-plus-controls band that mirrors the
/// Time Analysis surface: the page title on the left and, on the right, the
/// status filter (due / later / done / all) beside the quiet tool cluster
/// (search, category filter) — all in one row on desktop, exactly like Time
/// Analysis's title + period controls.
///
/// On a narrow phone the status toggle drops to its own horizontally-scrollable
/// row beneath the title so the four segments never overflow. The header never
/// flashes or reflows when a tool is toggled (constant widths throughout).
class HabitsHeader extends ConsumerWidget {
  const HabitsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);

    final filter = HabitStatusSegmentedControl(
      filter: state.displayFilter,
      onValueChanged: controller.setDisplayFilter,
    );
    final search = HabitsToolButton(
      icon: Icons.search,
      active: state.showSearch,
      onPressed: controller.toggleShowSearch,
      semanticLabel: messages.searchHint,
    );

    // Toggling search swaps the title for the search field inline in the header
    // (it fills the space between the title and the controls) instead of
    // revealing a separate bar below the header.
    final leading = state.showSearch
        ? const HabitsSearchWidget(padding: EdgeInsets.zero)
        : Text(
            messages.settingsHabitsTitle,
            style: calmPageTitleStyle(tokens),
            overflow: TextOverflow.ellipsis,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Single row when there's room for the title/search + the four-segment
        // filter + both tools; otherwise the filter drops to its own row.
        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              Expanded(child: leading),
              SizedBox(width: tokens.spacing.step4),
              filter,
              SizedBox(width: tokens.spacing.step4),
              search,
              SizedBox(width: tokens.spacing.step2),
              const HabitsFilter(),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: leading),
                search,
                SizedBox(width: tokens.spacing.step2),
                const HabitsFilter(),
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: filter,
            ),
          ],
        );
      },
    );
  }
}
