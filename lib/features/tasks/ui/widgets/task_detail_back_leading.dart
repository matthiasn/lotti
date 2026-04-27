import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';

/// Shared desktop "back" leading for the task detail app bars.
///
/// Renders a [GlassBackButton] only when more than one task sits on the
/// `NavService.desktopTaskDetailStack` — i.e. a linked task is currently
/// layered on top of the base task selected from the list pane. The base
/// task hides the arrow on desktop because the list pane on the left
/// already exposes sibling tasks. Tapping the button pops the desktop
/// detail stack so the previous task is restored.
///
/// Used by both `TaskCompactAppBar` and `TaskExpandableAppBar` so the
/// affordance is visually identical regardless of whether the task has
/// cover art.
class TaskDetailDesktopBackLeading extends StatelessWidget {
  const TaskDetailDesktopBackLeading({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: getIt<NavService>().desktopTaskDetailStack,
      builder: (context, stack, _) {
        if (stack.length <= 1) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GlassBackButton(
            onPressed: () => getIt<NavService>().popDesktopTaskDetail(),
          ),
        );
      },
    );
  }
}
