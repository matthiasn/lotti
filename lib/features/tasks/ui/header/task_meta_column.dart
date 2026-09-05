import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The details column's width.
///
/// Wide enough for a stacked label + value row to hold a date, a project
/// name or two label names without truncating; narrow enough that the task
/// column beside it keeps the larger share of a laptop window.
const double kTaskMetaColumnWidth = 320;

/// The narrowest host pane that earns the details column.
///
/// Measured against the **pane the task is rendered in**, not the window: the
/// navigation sidebar can be collapsed, and a window width alone would answer
/// the wrong question by up to 256 points. At this floor the task column
/// still keeps 960 − 320 = 640 points, which is the measure a task's title,
/// AI card and checklists were designed to read at; below it the metadata
/// goes back to the fly-out rather than squeezing the work it describes.
const double kTaskMetaColumnMinHostWidth = 960;

/// The persistent task-details column: the [TaskMetaSection] mounted as a
/// peer surface on the right of a focused task, instead of a fly-out over it.
///
/// Shown only when the task list is collapsed (the reader has chosen one
/// task) *and* the pane is at least [kTaskMetaColumnMinHostWidth] wide. It
/// carries its own title, a hairline left rule against the task column, and
/// scrolls independently — metadata a reader glances at should not move when
/// the task beside it scrolls.
class TaskMetaColumn extends StatelessWidget {
  const TaskMetaColumn({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    // The column is a sibling of the task page's Scaffold, not a child of
    // it, so it has to bring its own Material: without one the rows have no
    // default text style to inherit (Flutter flags it with yellow underlines)
    // and the row ink has no surface to paint on.
    return Material(
      color: TaskShowcasePalette.page(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: TaskShowcasePalette.border(context)),
          ),
        ),
        child: SizedBox(
          width: kTaskMetaColumnWidth,
          child: SafeArea(
            left: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step5,
                    tokens.spacing.step5,
                    tokens.spacing.step5,
                    tokens.spacing.step3,
                  ),
                  child: Text(
                    context.messages.taskMetaSheetTitle,
                    style: tokens.typography.styles.others.overline.copyWith(
                      color: TaskShowcasePalette.mediumText(context),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.step4,
                      0,
                      tokens.spacing.step4,
                      tokens.spacing.step5,
                    ),
                    child: TaskMetaSection(
                      taskId: taskId,
                      density: TaskMetaDensity.narrow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks the subtree in which the details column is already on screen.
///
/// The task header reads this to drop its "Details" trigger: two surfaces
/// offering the same metadata, one of them permanently visible behind the
/// other, is the duplication this column exists to remove.
class TaskMetaColumnScope extends InheritedWidget {
  const TaskMetaColumnScope({
    required this.visible,
    required super.child,
    super.key,
  });

  final bool visible;

  /// Whether a details column is mounted above [context].
  static bool isVisible(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TaskMetaColumnScope>()
          ?.visible ??
      false;

  @override
  bool updateShouldNotify(TaskMetaColumnScope oldWidget) =>
      visible != oldWidget.visible;
}
