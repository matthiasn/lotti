import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_filter.dart';
import 'package:lotti/features/habits/ui/widgets/habits_tool_button.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The Habits tab header — the calm title-plus-controls band that mirrors the
/// Time Analysis surface: a page title on the left, the quiet tool cluster
/// (search, category filter) on the right, and the status filter as a
/// design-system segmented toggle below.
///
/// The status toggle scrolls horizontally so the four segments never overflow
/// a narrow phone, and the header never flashes or reflows when a tool is
/// toggled (constant widths throughout).
class HabitsHeader extends ConsumerWidget {
  const HabitsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                messages.settingsHabitsTitle,
                style: calmPageTitleStyle(tokens),
              ),
            ),
            HabitsToolButton(
              icon: Icons.search,
              active: state.showSearch,
              onPressed: controller.toggleShowSearch,
              semanticLabel: messages.searchHint,
            ),
            SizedBox(width: tokens.spacing.step2),
            const HabitsFilter(),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HabitStatusSegmentedControl(
            filter: state.displayFilter,
            onValueChanged: controller.setDisplayFilter,
          ),
        ),
      ],
    );
  }
}
