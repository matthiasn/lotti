import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_composite_picker.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_presentation.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The rule a workout row offers: any session, or a dimension threshold.
enum _WorkoutRule { any, duration, distance, energy }

/// The editor's signal card: the manual row, one row per associated signal
/// with its rule, the add row, and — with two or more signals — how they
/// combine.
class HabitSignalCard extends StatelessWidget {
  const HabitSignalCard({
    required this.form,
    required this.measurablesById,
    required this.onChanged,
    required this.onAddSignal,
    required this.onChangeComposite,
    super.key,
  });

  final HabitSignalsForm form;
  final Map<String, MeasurableDataType> measurablesById;
  final ValueChanged<HabitSignalsForm> onChanged;
  final VoidCallback onAddSignal;
  final VoidCallback onChangeComposite;

  void _replace(int index, HabitSignalForm signal) {
    final signals = [...form.signals]..[index] = signal;
    onChanged(form.copyWith(signals: signals));
  }

  void _remove(int index) {
    final signals = [...form.signals]..removeAt(index);
    onChanged(form.copyWith(signals: signals));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final divider = Divider(height: 1, color: tokens.colors.decorative.level01);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          children: [
            _Row(
              key: const ValueKey('habit-signal-manual-row'),
              icon: LottiIcons.confirmCircled,
              title: messages.habitEditorManualRowTitle,
              caption: messages.habitEditorManualRowCaption,
              checked: true,
              onToggle: null,
            ),
            for (final (index, signal) in form.signals.indexed) ...[
              divider,
              _Row(
                key: ValueKey(
                  'habit-signal-row-${signal.kind.name}-${signal.id}',
                ),
                icon: signal.kind.icon,
                title: habitSignalDisplayName(signal, measurablesById),
                caption: _caption(messages, signal),
                checked: true,
                checkKey: ValueKey(
                  'habit-signal-check-${signal.kind.name}-${signal.id}',
                ),
                onToggle: () => _remove(index),
                child: _RuleEditor(
                  signal: signal,
                  unit: habitSignalUnit(signal, measurablesById),
                  onChanged: (updated) => _replace(index, updated),
                ),
              ),
            ],
            divider,
            InkWell(
              key: const ValueKey('habit-signal-add-row'),
              onTap: onAddSignal,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step4,
                ),
                child: Row(
                  children: [
                    Icon(
                      LottiIcons.add,
                      size: IconSizes.m,
                      color: tokens.colors.interactive.enabled,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Text(
                      messages.habitEditorAddSignal,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.interactive.enabled),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (form.signals.length >= 2) ...[
          SizedBox(height: tokens.spacing.step3),
          _Card(
            children: [
              InkWell(
                key: const ValueKey('habit-signal-composite-row'),
                onTap: onChangeComposite,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step4,
                    vertical: tokens.spacing.step4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LottiIcons.tree,
                        size: IconSizes.m,
                        color: tokens.colors.interactive.enabled,
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              messages.habitEditorCompositeTitle,
                              style: tokens.typography.styles.subtitle.subtitle2
                                  .copyWith(
                                    color: tokens.colors.text.highEmphasis,
                                  ),
                            ),
                            Text(
                              habitCompositeLabel(
                                messages,
                                form.composite,
                                form.requiredCount,
                                form.signals.length,
                              ),
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: tokens.colors.text.mediumEmphasis,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        messages.habitEditorCompositeChange,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: tokens.colors.interactive.enabled),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _caption(AppLocalizations messages, HabitSignalForm signal) =>
      switch (signal.kind) {
        HabitSignalKind.measurable => messages.habitEditorPickerMeasurables,
        HabitSignalKind.health => messages.habitEditorPickerHealth,
        HabitSignalKind.workout => messages.habitEditorPickerWorkouts,
      };
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.caption,
    required this.checked,
    required this.onToggle,
    this.checkKey,
    this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool checked;

  /// Null for the fixed manual row.
  final VoidCallback? onToggle;
  final Key? checkKey;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: IconSizes.m,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                    Text(
                      caption,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Semantics(
                button: onToggle != null,
                checked: checked,
                child: InkWell(
                  key: checkKey,
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                  child: Container(
                    width: tokens.spacing.step6,
                    height: tokens.spacing.step6,
                    decoration: BoxDecoration(
                      color: checked ? accent : null,
                      borderRadius: BorderRadius.circular(tokens.radii.s),
                      border: checked
                          ? null
                          : Border.all(
                              color: tokens.colors.decorative.level02,
                              width: 2,
                            ),
                    ),
                    child: checked
                        ? Icon(
                            LottiIcons.confirm,
                            size: IconSizes.s,
                            color: tokens.colors.text.onInteractiveAlert,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          if (child != null) ...[
            SizedBox(height: tokens.spacing.step3),
            Padding(
              padding: EdgeInsets.only(left: tokens.spacing.step8),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

/// The per-row rule: a segmented mode plus a threshold for the bounded
/// modes. Workouts pick a dimension instead of a direction.
class _RuleEditor extends StatefulWidget {
  const _RuleEditor({
    required this.signal,
    required this.unit,
    required this.onChanged,
  });

  final HabitSignalForm signal;
  final String unit;
  final ValueChanged<HabitSignalForm> onChanged;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _threshold = TextEditingController(
    text: widget.signal.threshold?.toString() ?? '',
  );

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final signal = widget.signal;
    final bounded = signal.mode != HabitSignalMode.any;

    final Widget toggle = switch (signal.kind) {
      HabitSignalKind.workout => DsSegmentedToggle<_WorkoutRule>(
        expand: true,
        selected: switch ((signal.mode, signal.workoutValueType)) {
          (HabitSignalMode.any, _) => _WorkoutRule.any,
          (_, WorkoutValueType.duration) => _WorkoutRule.duration,
          (_, WorkoutValueType.distance) => _WorkoutRule.distance,
          (_, WorkoutValueType.energy) => _WorkoutRule.energy,
          (_, null) => _WorkoutRule.any,
        },
        onChanged: (rule) => widget.onChanged(
          rule == _WorkoutRule.any
              ? signal.copyWith(
                  mode: HabitSignalMode.any,
                  clearThreshold: true,
                  clearWorkoutValueType: true,
                )
              : signal.copyWith(
                  mode: HabitSignalMode.atLeast,
                  workoutValueType: switch (rule) {
                    _WorkoutRule.duration => WorkoutValueType.duration,
                    _WorkoutRule.distance => WorkoutValueType.distance,
                    _WorkoutRule.energy => WorkoutValueType.energy,
                    _WorkoutRule.any => null,
                  },
                ),
        ),
        segments: [
          DsSegment(_WorkoutRule.any, messages.habitEditorRuleAnyWorkout),
          DsSegment(
            _WorkoutRule.duration,
            messages.habitEditorRuleDurationAtLeast,
          ),
          DsSegment(
            _WorkoutRule.distance,
            messages.habitEditorRuleDistanceAtLeast,
          ),
          DsSegment(_WorkoutRule.energy, messages.habitEditorRuleEnergyAtLeast),
        ],
      ),
      _ => DsSegmentedToggle<HabitSignalMode>(
        expand: true,
        selected: signal.mode,
        onChanged: (mode) => widget.onChanged(
          mode == HabitSignalMode.any
              ? signal.copyWith(mode: mode, clearThreshold: true)
              : signal.copyWith(mode: mode),
        ),
        segments: [
          DsSegment(
            HabitSignalMode.any,
            signal.kind == HabitSignalKind.health
                ? messages.habitEditorRuleAnyReading
                : messages.habitEditorRuleAnyEntry,
          ),
          DsSegment(
            HabitSignalMode.atLeast,
            signal.kind == HabitSignalKind.health
                ? messages.habitEditorRuleDailyAtLeast
                : messages.habitEditorRuleTotalAtLeast,
          ),
          DsSegment(
            HabitSignalMode.atMost,
            signal.kind == HabitSignalKind.health
                ? messages.habitEditorRuleDailyAtMost
                : messages.habitEditorRuleTotalAtMost,
          ),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toggle,
        if (bounded) ...[
          SizedBox(height: tokens.spacing.step3),
          DesignSystemTextInput(
            key: ValueKey(
              'habit-signal-threshold-${signal.kind.name}-${signal.id}',
            ),
            controller: _threshold,
            size: DesignSystemTextInputSize.small,
            helperText: widget.unit.isEmpty ? null : widget.unit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (raw) {
              final value = num.tryParse(raw.trim().replaceAll(',', '.'));
              widget.onChanged(
                value == null
                    ? signal.copyWith(clearThreshold: true)
                    : signal.copyWith(threshold: value),
              );
            },
          ),
        ],
      ],
    );
  }
}
