import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
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

    return GlassActionButton(
      onTap: onPressed,
      semanticLabel: label,
      tooltip: label,
      child: Icon(
        LottiIcons.sidebar,
        size: IconSizes.m,
        color: dsTokensDark.colors.text.highEmphasis,
      ),
    );
  }
}

/// The desktop task split's "hide list" control, rendered at the top of the
/// task detail header rather than beside the task list's own title.
///
/// It lives here so the two halves of the same toggle sit in the same corner:
/// [TaskDetailShowListButton] already restores the list from the detail pane,
/// and the hide affordance used to sit a pane away, next to the list title —
/// where it also shifted that title sideways the moment a task was selected.
///
/// Renders nothing outside the desktop split, and nothing while the list is
/// already hidden (the show button occupies that corner then).
///
/// Deliberately glyph-aligned rather than box-aligned: zero padding with a
/// left alignment inside a full-size tap target puts the icon's own left edge
/// on the header's content rail, so it stacks cleanly above the category dot
/// of the breadcrumb below it.
class TaskDetailHideListButton extends StatelessWidget {
  const TaskDetailHideListButton({super.key});

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    if (splitController == null ||
        !splitController.listPaneVisible ||
        !splitController.canHideListPane) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    return IconButton(
      key: const ValueKey('tasks-hide-list-pane'),
      onPressed: splitController.hideListPane,
      tooltip: context.messages.listPaneHideTooltip,
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(
        minWidth: TapTargets.minimum,
        minHeight: TapTargets.minimum,
      ),
      icon: Icon(
        LottiIcons.sidebar,
        size: IconSizes.m,
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
