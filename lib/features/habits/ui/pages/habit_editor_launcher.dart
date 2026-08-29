import 'package:flutter/material.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';

/// The width the editor panel aims for on desktop: two phone-width columns
/// side by side, so the whole form is on screen without scrolling.
const kHabitEditorPanelWidth = 800.0;

/// The vertical room the side sheet's own chrome takes above the editor's
/// content — its top bar with the title and close button. The embedded
/// editor sizes itself to the window minus this, so its action row sits at
/// the panel's foot. Measured against the sheet as configured here; a
/// slight undershoot only leaves a little air, an overshoot would overflow.
const kHabitEditorPanelChromeHeight = 80.0;

/// Opens the habit editor — for [habitId], or a new habit when null.
///
/// On a phone the editor is its own route, reached and left through the
/// navigator. On desktop it is a right-anchored panel over the page the user
/// is on: a form they will close in a moment should not navigate them away
/// from the list they were reading, and a page-wide route for it was a
/// phone-width column between two empty gutters.
void openHabitEditor(BuildContext context, {String? habitId}) {
  if (!isDesktopLayout(context)) {
    beamToNamed(
      habitId == null
          ? HabitsLocation.createPath
          : HabitsLocation.editPath(habitId),
    );
    return;
  }
  final messages = context.messages;
  ModalUtils.showSinglePageModal<void>(
    context: context,
    title: habitId == null
        ? messages.habitEditorCreateTitle
        : messages.habitEditorEditTitle,
    modalTypeBuilderOverride: (_) => const SizedWoltSideSheetType(
      widthFraction: 0.6,
      minWidth: 560,
      maxWidth: kHabitEditorPanelWidth,
    ),
    builder: (sheetContext) => HabitEditorPage(
      habitId: habitId,
      // The sheet nests a navigator of its own for its pages; the panel
      // itself is a route on the navigator it was shown from.
      onClose: () => Navigator.of(sheetContext, rootNavigator: true).pop(),
    ),
  );
}
