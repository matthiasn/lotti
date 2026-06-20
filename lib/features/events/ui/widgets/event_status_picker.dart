import 'package:flutter/material.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Capitalizes the locale-independent all-caps `EventStatus.label` for display
/// (e.g. `TENTATIVE` → `Tentative`).
String eventStatusLabel(EventStatus status) {
  final lower = status.label.toLowerCase();
  return lower.isEmpty
      ? lower
      : '${lower[0].toUpperCase()}${lower.substring(1)}';
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
                  eventStatusLabel(status),
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
