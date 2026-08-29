import 'package:flutter/material.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';

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
  // The navigator the sheet is pushed on — resolved here, from the same
  // context Wolt resolves it from, so a close pops exactly that route.
  // Re-deriving it inside the sheet found a different navigator on the
  // desktop tabs, which each run a nested one.
  final navigator = Navigator.of(context, rootNavigator: true);
  ModalUtils.showSinglePageModal<void>(
    context: context,
    // On the root navigator, explicitly: the desktop tabs each run a nested
    // Beamer navigator, and a sheet pushed there dims only the tab. The
    // scrim is meant to cover the whole window, and [navigator] above is
    // the same root, so the close pops the sheet and nothing else.
    useRootNavigator: true,
    title: habitId == null
        ? messages.habitEditorCreateTitle
        : messages.habitEditorEditTitle,
    // One reviewed width (see [kHabitEditorPanelWidth]), clamped to the
    // window by the sheet type on narrow desktops.
    modalTypeBuilderOverride: (_) => const SizedWoltSideSheetType(
      widthFraction: 1,
      minWidth: kHabitEditorPanelWidth,
      maxWidth: kHabitEditorPanelWidth,
    ),
    builder: (_) => HabitEditorPage(habitId: habitId, onClose: navigator.pop),
  );
}
