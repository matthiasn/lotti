import 'package:lotti/classes/event_status.dart';
import 'package:lotti/themes/colors.dart';
import 'package:material_ui/material_ui.dart';

/// The colour an event status shows in, per brightness.
///
/// Drawn from the task status icon palette (`taskIconColor*`, with the deeper
/// `taskIconColorDark*` shades on light surfaces) so the event status picker,
/// pill and cards read like the task status picker in both themes. Five hues
/// cover eight statuses; the picker's per-status icons keep shared hues
/// apart. Presentation, so it lives with the palette rather than on the
/// model: `lib/classes` ranks below the shared UI layer and may not import it.
extension EventStatusColors on EventStatus {
  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return switch (this) {
      EventStatus.tentative =>
        isLight ? taskIconColorDarkGrey : taskIconColorGrey,
      // Rescheduled is planned again, so it shares Planned's blue.
      EventStatus.planned || EventStatus.rescheduled =>
        isLight ? taskIconColorDarkBlue : taskIconColorBlue,
      // Postponed is on hold, as the task picker's On Hold is orange.
      EventStatus.ongoing || EventStatus.postponed =>
        isLight ? taskIconColorDarkOrange : taskIconColorOrange,
      EventStatus.completed =>
        isLight ? taskIconColorDarkGreen : taskIconColorGreen,
      EventStatus.cancelled ||
      EventStatus.missed => isLight ? taskIconColorDarkRed : taskIconColorRed,
    };
  }
}
