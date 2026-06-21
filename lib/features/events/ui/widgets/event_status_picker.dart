import 'package:flutter/material.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The localized display label for an [EventStatus]. (Replaces the previous
/// locale-independent capitalization of the all-caps `EventStatus.label`.)
String eventStatusLabel(BuildContext context, EventStatus status) {
  final messages = context.messages;
  return switch (status) {
    EventStatus.tentative => messages.eventsStatusTentative,
    EventStatus.planned => messages.eventsStatusPlanned,
    EventStatus.ongoing => messages.eventsStatusOngoing,
    EventStatus.completed => messages.eventsStatusCompleted,
    EventStatus.cancelled => messages.eventsStatusCancelled,
    EventStatus.postponed => messages.eventsStatusPostponed,
    EventStatus.rescheduled => messages.eventsStatusRescheduled,
    EventStatus.missed => messages.eventsStatusMissed,
  };
}

/// Opens a modal listing every [EventStatus] and resolves to the chosen one, or
/// `null` when dismissed. Reuses the app's single-page modal chrome.
Future<EventStatus?> showEventStatusPicker({
  required BuildContext context,
  required EventStatus current,
}) {
  return ModalUtils.showSinglePageModal<EventStatus>(
    context: context,
    builder: (modalContext) => _EventStatusList(current: current),
  );
}

class _EventStatusList extends StatelessWidget {
  const _EventStatusList({required this.current});

  final EventStatus current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final status in EventStatus.values)
          _EventStatusRow(
            status: status,
            selected: status == current,
            onTap: () => Navigator.of(context).pop(status),
          ),
      ],
    );
  }
}

class _EventStatusRow extends StatelessWidget {
  const _EventStatusRow({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final EventStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;

    return Material(
      color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  eventStatusLabel(context, status),
                  style: tokens.typography.styles.body.bodyLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
