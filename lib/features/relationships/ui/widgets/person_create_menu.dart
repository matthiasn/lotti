import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the person page's create menu can add.
enum PersonCreateChoice { note, task, photos, checkIn }

/// The person page's create menu — the bar's **+** (design panel
/// 2026-10-15): everything that can go on the person's timeline besides
/// speaking, in full sentences that name the person, so no row has to be
/// decoded. A sheet on a phone and a dialog on a wide window, like the app's
/// other action menus.
///
/// Returns the choice, or null when the menu was dismissed; the page runs
/// the flow once the menu is gone, so no sheet ever stacks on this one.
Future<PersonCreateChoice?> showPersonCreateMenu({
  required BuildContext context,
  required String personName,
}) {
  final messages = context.messages;
  return DsActionModal.show<PersonCreateChoice>(
    context: context,
    title: messages.relationshipAddToTimeline(personName),
    builder: (sheetContext) {
      DsActionRow row(PersonCreateChoice choice, IconData icon, String title) =>
          DsActionRow(
            key: ValueKey('person-create-${choice.name}'),
            icon: icon,
            title: title,
            tone: DsActionRowTone.accent,
            onTap: () => Navigator.of(sheetContext).pop(choice),
          );
      return DsActionModalList(
        children: [
          row(
            PersonCreateChoice.note,
            LottiIcons.note,
            messages.relationshipAddNote(personName),
          ),
          row(
            PersonCreateChoice.task,
            LottiIcons.addTask,
            messages.relationshipCreateTask(personName),
          ),
          row(
            PersonCreateChoice.photos,
            LottiIcons.addPhoto,
            messages.relationshipAddPhotos,
          ),
          row(
            PersonCreateChoice.checkIn,
            LottiIcons.forum,
            messages.relationshipLogCheckIn,
          ),
        ],
      );
    },
  );
}
