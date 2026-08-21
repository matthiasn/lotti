import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';

/// The desktop task detail's leading controls, in the app bar's icon row.
///
/// Carries up to two glass actions, left to right:
///
/// 1. **Back** — only while more than one task sits on the
///    `NavService.desktopTaskDetailStack`, i.e. a linked task is layered on
///    top of the base task selected from the list pane. The base task hides
///    the arrow on desktop because the list pane already exposes siblings.
/// 2. **Hide list** — the split's focus-mode toggle, whenever a task is
///    selected and the list is still showing.
///
/// Both are glass buttons in the same corner of the same row as the bar's
/// trailing actions, so the toolbar reads as one row of controls whether or
/// not the task has cover art. [TaskDetailShowListButton] takes this corner
/// once the list is hidden, which makes the toggle one control in one place
/// rather than two affordances a pane apart.
///
/// Used by both `TaskCompactAppBar` and `TaskExpandableAppBar`; they size
/// their `leadingWidth` with [widthFor].
class TaskDetailDesktopLeading extends StatelessWidget {
  const TaskDetailDesktopLeading({super.key});

  /// Left inset before the first control, shared with [widthFor].
  static double _leftInset(DsTokens tokens) => tokens.spacing.step2;

  /// Gap between the two controls when both render.
  static double _gap(DsTokens tokens) => tokens.spacing.step1;

  static const double _backSize = 34;
  static const double _hideSize = 40;

  /// Whether the split currently offers to hide its list pane.
  static bool _canHideList(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    return splitController != null &&
        splitController.listPaneVisible &&
        splitController.canHideListPane;
  }

  /// The `leadingWidth` an app bar must reserve for this cluster.
  ///
  /// Reads the stack's current value rather than listening: on desktop the
  /// stack only ever changes together with the selected task, which rebuilds
  /// the whole detail pane — and with it the app bar that calls this.
  static double widthFor(BuildContext context) {
    final tokens = context.designTokens;
    final showBack =
        getIt<NavService>().desktopTaskDetailStack.value.length > 1;
    if (!showBack) return _leftInset(tokens) + _hideSize;
    return _leftInset(tokens) + _backSize + _gap(tokens) + _hideSize;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ValueListenableBuilder<List<String>>(
      valueListenable: getIt<NavService>().desktopTaskDetailStack,
      builder: (context, stack, _) {
        final showBack = stack.length > 1;
        return Padding(
          padding: EdgeInsets.only(left: _leftInset(tokens)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBack) ...[
                GlassBackButton(
                  onPressed: () => getIt<NavService>().popDesktopTaskDetail(),
                ),
                SizedBox(width: _gap(tokens)),
              ],
              if (_canHideList(context)) const TaskDetailHideListButton(),
            ],
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

/// Glass action that hides the desktop task split's list pane.
///
/// The counterpart of [TaskDetailShowListButton], in the same corner and the
/// same shape, so one glyph in one place moves the split both ways. Rendered
/// by [TaskDetailDesktopLeading], which owns the "is this offered at all"
/// decision and the width the bar reserves for it.
class TaskDetailHideListButton extends StatelessWidget {
  const TaskDetailHideListButton({super.key});

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    if (splitController == null) return const SizedBox.shrink();
    final label = context.messages.listPaneHideTooltip;

    return GlassActionButton(
      key: const ValueKey('tasks-hide-list-pane'),
      onTap: splitController.hideListPane,
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
