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
/// their `leadingWidth` with [widthFor] and pass [glass] to match the bar the
/// cluster is sitting in.
class TaskDetailDesktopLeading extends StatelessWidget {
  const TaskDetailDesktopLeading({this.glass = false, super.key});

  /// Whether the controls sit over cover art.
  ///
  /// The glass treatment is for a photograph behind the glyph, not for the
  /// bar in general: on the plain compact bar the trailing actions are bare
  /// glyphs, so a tinted circle beside them reads as a different species of
  /// control rather than a sibling of the two icons at the other end of the
  /// same row.
  final bool glass;

  /// Left inset before the first control, shared with [widthFor].
  static double _leftInset(DsTokens tokens) => tokens.spacing.step2;

  /// Gap between the two controls when both render.
  static double _gap(DsTokens tokens) => tokens.spacing.step1;

  static const double _backSize = 34;
  static const double _glassHideSize = 40;

  /// A stock [IconButton]'s tap target, which is what the plain variant is.
  static const double _plainHideSize = kMinInteractiveDimension;

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
  static double widthFor(BuildContext context, {bool glass = false}) {
    final tokens = context.designTokens;
    final hideSize = glass ? _glassHideSize : _plainHideSize;
    final showBack =
        getIt<NavService>().desktopTaskDetailStack.value.length > 1;
    if (!showBack) return _leftInset(tokens) + hideSize;
    return _leftInset(tokens) + _backSize + _gap(tokens) + hideSize;
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
              if (_canHideList(context)) TaskDetailHideListButton(glass: glass),
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

/// Hides the desktop task split's list pane.
///
/// The counterpart of [TaskDetailShowListButton], in the same corner, so one
/// glyph in one place moves the split both ways. Rendered by
/// [TaskDetailDesktopLeading], which owns the "is this offered at all"
/// decision and the width the bar reserves for it.
///
/// Takes the shape of the row it joins: a bare glyph beside the compact bar's
/// bare trailing actions, and the glass treatment only where there is cover
/// art behind it. Either way the ink is centred on the glyph.
class TaskDetailHideListButton extends StatelessWidget {
  const TaskDetailHideListButton({this.glass = false, super.key});

  /// Whether the button sits over cover art. See
  /// [TaskDetailDesktopLeading.glass].
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    if (splitController == null) return const SizedBox.shrink();
    final label = context.messages.listPaneHideTooltip;

    if (glass) {
      return GlassActionButton(
        key: const ValueKey('tasks-hide-list-pane'),
        onTap: splitController.hideListPane,
        semanticLabel: label,
        tooltip: label,
        child: const Icon(
          LottiIcons.sidebar,
          // Matches the glass actions at the other end of the same bar: the
          // glyph is white over a photograph regardless of theme.
          size: IconSizes.l,
          color: Colors.white,
        ),
      );
    }

    // The compact bar's own action treatment, verbatim — same glyph size,
    // same medium emphasis, same stock ripple — so the row reads as one set
    // of controls from end to end.
    return IconButton(
      key: const ValueKey('tasks-hide-list-pane'),
      onPressed: splitController.hideListPane,
      tooltip: label,
      icon: Icon(
        LottiIcons.sidebar,
        color: context.designTokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
