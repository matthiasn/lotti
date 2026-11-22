import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the goal page's create menu can add.
enum GoalCreateChoice { writeCheckIn, reflectToday, logToday }

/// The goal page's create menu — the bar's **+**: everything that can be
/// added to a goal besides speaking, each row a full phrase so none has to
/// be decoded. A sheet on a phone and a dialog on a wide window, like the
/// person page's and the app's other action menus.
///
/// [canReflect] and [canLogToday] gate the rows that need something the
/// goal may not have: a day to judge, a habit to tick off. Writing a
/// check-in is always there.
///
/// Returns the choice, or null when the menu was dismissed; the page runs
/// the flow once the menu is gone, so no sheet ever stacks on this one.
Future<GoalCreateChoice?> showGoalCreateMenu({
  required BuildContext context,
  required bool canReflect,
  required bool canLogToday,
}) {
  final messages = context.messages;
  return DsActionModal.show<GoalCreateChoice>(
    context: context,
    title: messages.goalAddMenuTitle,
    builder: (sheetContext) {
      DsActionRow row(GoalCreateChoice choice, IconData icon, String title) =>
          DsActionRow(
            key: ValueKey('goal-create-${choice.name}'),
            icon: icon,
            title: title,
            onTap: () => Navigator.of(sheetContext).pop(choice),
          );
      return DsActionModalList(
        children: [
          // The check-in first: saying what is going on is what the page is
          // for, and this is the way to do it without the mic.
          row(
            GoalCreateChoice.writeCheckIn,
            LottiIcons.edit,
            messages.goalAddWriteCheckIn,
          ),
          if (canLogToday)
            row(
              GoalCreateChoice.logToday,
              LottiIcons.confirmCircled,
              messages.goalLogTodayTitle,
            ),
          if (canReflect)
            row(
              GoalCreateChoice.reflectToday,
              LottiIcons.note,
              messages.goalAssessmentReflectToday,
            ),
        ],
      );
    },
  );
}
