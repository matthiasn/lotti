import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Type · started · duration as one chip row (design 2026-09-13): each chip
/// reads its current value and opens the picker for it. Wraps, so large
/// text and a long locale get a second row rather than a truncated chip.
class CheckInContextChips extends StatelessWidget {
  const CheckInContextChips({
    required this.type,
    required this.startedLabel,
    required this.durationLabel,
    required this.onPickType,
    required this.onPickStart,
    required this.onPickDuration,
    this.enabled = true,
    super.key,
  });

  final CheckInInteractionType type;

  /// `Now · 14:55`, or the day and the time.
  final String startedLabel;

  /// `0:23` / `11 min`, or the *Duration* prompt when there is none yet.
  final String durationLabel;
  final VoidCallback onPickType;
  final VoidCallback onPickStart;
  final VoidCallback onPickDuration;

  /// False while the recorder or the transcript owns the field: the chips
  /// stay visible so the context is never lost, and go quiet.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final typeLabel = checkInInteractionLabel(context, type);
    return Wrap(
      key: const ValueKey('check-in-context-chips'),
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        DesignSystemChip(
          key: const ValueKey('check-in-type'),
          label: typeLabel,
          leadingIcon: checkInInteractionIcon(type),
          trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
          // Not `selected`: in the chip grammar that means "chosen among
          // peers", which the sentiment row uses; here every chip holds a
          // value, and the glyph says which.
          size: DesignSystemChipSize.touch,
          semanticsLabel: messages.checkInTypeChipSemantics(typeLabel),
          onPressed: enabled ? onPickType : null,
        ),
        DesignSystemChip(
          key: const ValueKey('check-in-started'),
          label: startedLabel,
          trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
          size: DesignSystemChipSize.touch,
          semanticsLabel: messages.checkInTimeChipSemantics(startedLabel),
          onPressed: enabled ? onPickStart : null,
        ),
        DesignSystemChip(
          key: const ValueKey('check-in-duration'),
          label: durationLabel,
          trailing: const Icon(LottiIcons.chevronDown, size: IconSizes.s),
          size: DesignSystemChipSize.touch,
          semanticsLabel: messages.checkInDurationChipSemantics(durationLabel),
          onPressed: enabled ? onPickDuration : null,
        ),
      ],
    );
  }
}

/// The interaction-type picker behind the first chip: every kind as an
/// action row, the current one marked. Resolves to the chosen kind, or
/// null when dismissed.
Future<CheckInInteractionType?> showCheckInTypePicker({
  required BuildContext context,
  required CheckInInteractionType current,
}) => DsActionModal.show<CheckInInteractionType>(
  context: context,
  title: context.messages.checkInInteractionLabel,
  builder: (sheetContext) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final type in CheckInInteractionType.values)
        DsActionRow(
          key: ValueKey('check-in-type-${type.name}'),
          title: checkInInteractionLabel(sheetContext, type),
          icon: checkInInteractionIcon(type),
          onTap: () => Navigator.of(sheetContext).pop(type),
        ),
    ],
  ),
);
