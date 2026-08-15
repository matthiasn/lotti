import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
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
        final showBack = stack.length > 1;
        if (!showBack) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(left: context.designTokens.spacing.step2),
          child: GlassBackButton(
            onPressed: () => getIt<NavService>().popDesktopTaskDetail(),
          ),
        );
      },
    );
  }
}

/// Glass action used by the desktop task split to restore its hidden list.
class TaskDetailShowListButton extends StatelessWidget {
  const TaskDetailShowListButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.messages.listPaneShowTooltip;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GlassActionButton(
          onTap: onPressed,
          child: Icon(
            Icons.view_sidebar_rounded,
            size: IconSizes.m,
            color: context.designTokens.colors.text.onInteractiveAlert,
          ),
        ),
      ),
    );
  }
}
