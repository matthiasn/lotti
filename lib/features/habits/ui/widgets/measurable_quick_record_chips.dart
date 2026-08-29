import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// What a quick chip records: a number for a numeric measurable, or one
/// occurrence (`value: 1`) of `choiceId` for a choice measurable — the same
/// two shapes `MeasurementData` takes.
typedef MeasurableQuickValue = ({num value, String? choiceId});

/// The measurable's most-logged values as one-tap chips, plus a "+" that
/// opens the full measurement capture.
///
/// Three chips at most for a numeric measurable — the completion sheet is
/// compact — drawn from the same ranking the measurement dialog's quick-add
/// uses, so the values a user sees here are the ones they already log. A
/// choice measurable offers every active choice instead, in the user's own
/// order: the set is the vocabulary, not a suggestion. The chip whose value
/// was just recorded reads as selected.
class MeasurableQuickRecordChips extends ConsumerWidget {
  const MeasurableQuickRecordChips({
    required this.dataType,
    required this.onRecord,
    required this.onMore,
    this.recordedValue,
    super.key,
  });

  final MeasurableDataType dataType;
  final ValueChanged<MeasurableQuickValue> onRecord;
  final VoidCallback onMore;

  /// The value recorded from this row during this sheet, if any.
  final MeasurableQuickValue? recordedValue;

  static const maxChips = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = tokens.colors.interactive.enabled;
    final List<Widget> valueChips;
    if (dataType.isChoice) {
      valueChips = [
        for (final choice in dataType.activeChoices)
          DsPill(
            key: ValueKey('habit-quick-record-${dataType.id}-${choice.id}'),
            variant: DsPillVariant.outline,
            color: accent,
            selected: choice.id == recordedValue?.choiceId,
            label: choice.title,
            onTap: () => onRecord((value: 1, choiceId: choice.id)),
          ),
      ];
    } else {
      final suggestions =
          ref
              .watch(measurableSuggestionsControllerProvider(dataType.id))
              .value ??
          const <num>[];
      valueChips = [
        for (final value in suggestions.take(maxChips))
          DsPill(
            key: ValueKey('habit-quick-record-${dataType.id}-$value'),
            variant: DsPillVariant.outline,
            color: accent,
            selected:
                recordedValue?.choiceId == null &&
                value == recordedValue?.value,
            label: '$value ${dataType.unitName}'.trim(),
            onTap: () => onRecord((value: value, choiceId: null)),
          ),
      ];
    }
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        ...valueChips,
        DsPill(
          key: ValueKey('habit-quick-record-more-${dataType.id}'),
          variant: DsPillVariant.outline,
          color: accent,
          leading: Icon(LottiIcons.add, size: IconSizes.s, color: accent),
          label: messages.habitSignalRecordOther,
          onTap: onMore,
        ),
      ],
    );
  }
}
