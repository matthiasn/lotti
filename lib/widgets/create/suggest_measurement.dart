import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One-tap quick-value chips for a measurable.
///
/// Shows the measurable's most popular recent values (ranked by frequency) as
/// design-system chips. Tapping a chip immediately logs that value and closes
/// the modal — the fastest path for a returning logger — so the row sits
/// directly under the value field (it reads as "tap to fill the amount") and
/// stays visible while typing. Each chip appends the unit (e.g. "500 ml") so it
/// is self-describing. Renders nothing until the suggestion controller has
/// values (a brand-new measurable simply shows no chips).
class MeasurementSuggestions extends ConsumerWidget {
  const MeasurementSuggestions({
    required this.measurableDataType,
    required this.onSelect,
    super.key,
  });

  final MeasurableDataType measurableDataType;

  /// Called with the chosen value when a quick-value chip is tapped.
  final void Function(num value) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularValues = ref
        .watch(measurableSuggestionsControllerProvider(measurableDataType.id))
        .value;

    if (popularValues == null || popularValues.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final unit = measurableDataType.unitName;
    final trailingZeros = RegExp(r'([.]*0)(?!.*\d)');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: tokens.spacing.step3),
        Text(
          context.messages.measurementQuickAddLabel,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: popularValues.map((value) {
            final number = value.toDouble().toString().replaceAll(
              trailingZeros,
              '',
            );
            final label = unit.isEmpty ? number : '$number $unit';
            return DesignSystemChip(
              label: label,
              // The bolt cues that the chip is a one-tap instant log (it saves
              // and closes), not a value that merely fills the field.
              leadingIcon: Icons.bolt_rounded,
              semanticsLabel: label,
              onPressed: () => onSelect(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
