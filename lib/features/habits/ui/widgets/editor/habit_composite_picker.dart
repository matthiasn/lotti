import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The label the card and the picker both use for a composite choice.
String habitCompositeLabel(
  AppLocalizations messages,
  HabitCompositeRule rule,
  int required,
  int total,
) => switch (rule) {
  HabitCompositeRule.any => messages.habitEditorCompositeAny,
  HabitCompositeRule.all => messages.habitEditorCompositeAll,
  HabitCompositeRule.atLeast => messages.habitEditorCompositeAtLeast(
    required,
    total,
  ),
};

/// Chooses how the habit's signals combine; stays open until Done. Every
/// tap applies to the page at once but renders from local mirrors.
class HabitCompositePicker extends StatefulWidget {
  const HabitCompositePicker({
    required this.value,
    required this.requiredCount,
    required this.signalCount,
    required this.onChanged,
    super.key,
  });

  final HabitCompositeRule value;
  final int requiredCount;
  final int signalCount;
  final void Function(HabitCompositeRule rule, int requiredCount) onChanged;

  @override
  State<HabitCompositePicker> createState() => _HabitCompositePickerState();
}

class _HabitCompositePickerState extends State<HabitCompositePicker> {
  late HabitCompositeRule _rule = widget.value;
  late int _required = widget.requiredCount.clamp(1, widget.signalCount);

  void _apply(HabitCompositeRule rule, int required) {
    setState(() {
      _rule = rule;
      _required = required;
    });
    widget.onChanged(rule, required);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.habitEditorCompositeTitle,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            for (final rule in HabitCompositeRule.values)
              DesignSystemSelectionRow(
                key: ValueKey('habit-composite-${rule.name}'),
                title: habitCompositeLabel(
                  messages,
                  rule,
                  _required,
                  widget.signalCount,
                ),
                selected: _rule == rule,
                type: DesignSystemSelectionRowType.singleSelect,
                secondaryLine:
                    rule == HabitCompositeRule.atLeast && _rule == rule
                    ? DesignSystemStepper(
                        label: '$_required / ${widget.signalCount}',
                        decrementTooltip: messages.goalFormDecreaseTarget,
                        incrementTooltip: messages.goalFormIncreaseTarget,
                        decrementKey: const ValueKey(
                          'habit-composite-decrease',
                        ),
                        incrementKey: const ValueKey(
                          'habit-composite-increase',
                        ),
                        onDecrement: _required > 1
                            ? () => _apply(rule, _required - 1)
                            : null,
                        onIncrement: _required < widget.signalCount
                            ? () => _apply(rule, _required + 1)
                            : null,
                      )
                    : null,
                onTap: () => _apply(rule, _required),
              ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              key: const ValueKey('habit-composite-done'),
              label: messages.doneButton,
              onPressed: () {
                widget.onChanged(_rule, _required);
                Navigator.of(context).pop();
              },
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
