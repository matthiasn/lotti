import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
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

/// The list-pane toggle's glyph, in whichever treatment the surface behind it
/// calls for.
///
/// Glass is for a photograph behind the glyph — nothing else. Over cover art
/// it is a tinted circle with a white glyph, matching the cover-art bar's own
/// actions; everywhere else it is the plain toolbar action treatment, so the
/// toggle reads as a sibling of the icons at the other end of the row rather
/// than as a different species of control.
class _ListPaneToggleGlyph extends StatelessWidget {
  const _ListPaneToggleGlyph({
    required this.onPressed,
    required this.tooltip,
    required this.glass,
    required this.buttonKey,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final bool glass;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    if (glass) {
      return GlassActionButton(
        key: buttonKey,
        onTap: onPressed,
        semanticLabel: tooltip,
        tooltip: tooltip,
        child: const Icon(
          LottiIcons.sidebar,
          // White over a photograph regardless of theme, like every other
          // glass action on the cover-art bar.
          size: IconSizes.l,
          color: Colors.white,
        ),
      );
    }

    return IconButton(
      key: buttonKey,
      onPressed: onPressed,
      tooltip: tooltip,
      // The glyph carries the name, not just the hover tooltip: this is an
      // icon-only control, and the glass variant announces itself through
      // `GlassActionButton`'s own semantics label. Both directions of the
      // toggle should read the same to assistive tech.
      icon: Icon(
        LottiIcons.sidebar,
        semanticLabel: tooltip,
        color: context.designTokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

/// Restores the desktop task split's hidden list.
///
/// Sits in the same corner as [TaskDetailHideListButton] and wears the same
/// treatment, so the toggle is one control that happens to point both ways.
/// It floats over the task rather than living in the app bar, because
/// `TasksRootPage` owns it: with the list hidden it has to stay reachable even
/// when the task itself never loads and the bar has no actions of its own.
///
/// [taskId] decides the treatment: a task with cover art puts an image
/// directly behind this corner, which is the one place glass belongs.
class TaskDetailShowListButton extends ConsumerWidget {
  const TaskDetailShowListButton({
    required this.onPressed,
    this.taskId,
    super.key,
  });

  final VoidCallback onPressed;

  /// The task under this button, or null while none is resolved — in which
  /// case there is no cover art behind it either.
  final String? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ListPaneToggleGlyph(
      buttonKey: const ValueKey('tasks-show-list-pane-button'),
      onPressed: onPressed,
      tooltip: context.messages.listPaneShowTooltip,
      glass: taskHasCoverArt(ref, taskId),
    );
  }
}

/// Whether [taskId] resolves to a task carrying cover art, i.e. whether an
/// image sits behind the detail pane's top-left corner.
bool taskHasCoverArt(WidgetRef ref, String? taskId) {
  if (taskId == null) return false;
  final entry = ref.watch(entryControllerProvider(taskId)).value?.entry;
  return entry is Task && entry.data.coverArtId != null;
}

/// Hides the desktop task split's list pane.
///
/// The counterpart of [TaskDetailShowListButton], in the same corner and the
/// same treatment, so one glyph in one place moves the split both ways.
/// Rendered by [TaskDetailDesktopLeading], which owns the "is this offered at
/// all" decision, the width the bar reserves for it, and — since it is the app
/// bar that knows whether the task has cover art behind it — [glass].
class TaskDetailHideListButton extends StatelessWidget {
  const TaskDetailHideListButton({this.glass = false, super.key});

  /// Whether the button sits over cover art. See
  /// [TaskDetailDesktopLeading.glass].
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    if (splitController == null) return const SizedBox.shrink();

    return _ListPaneToggleGlyph(
      buttonKey: const ValueKey('tasks-hide-list-pane'),
      onPressed: splitController.hideListPane,
      tooltip: context.messages.listPaneHideTooltip,
      glass: glass,
    );
  }
}
