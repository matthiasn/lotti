import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/event_status_colors.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The localized display label for an [EventStatus].
String eventStatusLabel(BuildContext context, EventStatus status) =>
    status.localizedLabel(context);

/// The icon that stands for an [EventStatus] in the status picker, drawn in
/// the status's [EventStatusColors.colorForBrightness] the way the task and
/// project pickers draw theirs.
IconData eventStatusIcon(EventStatus status) => switch (status) {
  EventStatus.tentative => LottiIcons.help,
  EventStatus.planned => LottiIcons.calendar,
  EventStatus.ongoing => LottiIcons.playCircled,
  EventStatus.completed => LottiIcons.confirmCircled,
  EventStatus.cancelled => LottiIcons.closeCircled,
  EventStatus.postponed => LottiIcons.pauseCircled,
  EventStatus.rescheduled => LottiIcons.replay,
  EventStatus.missed => LottiIcons.warning,
};

/// Opens the adaptive event-status picker and resolves to the chosen status,
/// or `null` when it is dismissed or the already-current status is tapped —
/// so re-picking the current status writes nothing.
///
/// It shares the task and project status pickers' chrome — a titled
/// single-page modal (bottom sheet on compact widths, dialog on wider ones)
/// with full-width [DesignSystemSelectionRow]s — so every status picker in the
/// app looks and behaves alike.
Future<EventStatus?> showEventStatusPicker({
  required BuildContext context,
  required EventStatus current,
}) {
  return ModalUtils.showSinglePageModal<EventStatus>(
    context: context,
    title: context.messages.eventsStatusPickerTitle,
    padding: EdgeInsets.zero,
    builder: (modalContext) => EventStatusModalContent(current: current),
  );
}

/// Modal body listing every [EventStatus] as an icon-led selection row, with a
/// trailing check on [current]. Tapping a row pops the route with that status,
/// or with `null` when it is [current], which leaves nothing to change.
class EventStatusModalContent extends StatelessWidget {
  const EventStatusModalContent({required this.current, super.key});

  final EventStatus current;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final brightness = Theme.of(context).brightness;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in EventStatus.values)
            DesignSystemSelectionRow(
              key: ValueKey('event-status-${status.name}'),
              title: eventStatusLabel(context, status),
              type: DesignSystemSelectionRowType.singleSelect,
              selected: status == current,
              leading: Icon(
                eventStatusIcon(status),
                color: status.colorForBrightness(brightness),
                size: tokens.spacing.step6,
              ),
              onTap: () => Navigator.of(
                context,
              ).pop(status == current ? null : status),
            ),
        ],
      ),
    );
  }
}
