import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The urgency marker a saved view carries when the open tasks it matches
/// include an overdue one (red) or, failing that, one due today (orange) —
/// the same two tones, in the same order of precedence, as the smart views
/// above the task list. A view with neither carries nothing.
///
/// A 12px disc (`spacing.step4`) beside the count, larger than the 8px
/// category dot that leads the row, so the two never read as one channel:
///
/// ```text
///  •  Habitat checks          ●  7     ← red: something in it is overdue
///  •  Sardine cargo           ●  3     ← orange: something is due today
///  •  Blocked                    2     ← nothing urgent, no marker
/// ```
///
/// The marker is decoration for sighted readers; hosts append
/// [savedFilterDueMarkerSemantics] to the row's own label so a screen reader
/// hears the same fact.
class SavedFilterDueMarker extends StatelessWidget {
  const SavedFilterDueMarker({required this.urgency, super.key});

  /// Null (still loading) and [DueDateUrgency.normal] both render nothing.
  final DueDateUrgency? urgency;

  @override
  Widget build(BuildContext context) {
    final color = switch (urgency) {
      DueDateUrgency.overdue => TaskShowcasePalette.error(context),
      DueDateUrgency.dueToday => TaskShowcasePalette.warning(context),
      DueDateUrgency.normal || null => null,
    };
    if (color == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: SizedBox.square(dimension: context.designTokens.spacing.step4),
    );
  }
}

/// The spoken form of [SavedFilterDueMarker], or null when it shows nothing.
String? savedFilterDueMarkerSemantics(
  AppLocalizations messages,
  DueDateUrgency? urgency,
) => switch (urgency) {
  DueDateUrgency.overdue => messages.tasksSavedFilterOverdueMarker,
  DueDateUrgency.dueToday => messages.tasksSavedFilterDueTodayMarker,
  DueDateUrgency.normal || null => null,
};
