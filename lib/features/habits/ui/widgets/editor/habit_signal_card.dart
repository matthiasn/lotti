import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    this.foot,
    super.key,
  });

  final HabitSignalsForm form;
  final Map<String, MeasurableDataType> measurablesById;
  final ValueChanged<HabitSignalsForm> onChanged;
  final VoidCallback onAddSignal;
  final VoidCallback onChangeComposite;

  /// An optional last row inside the card, under "Add a signal" — a setting
  /// that belongs to the signals as a group, such as the notify choice.
  final Widget? foot;

  void _replace(int index, HabitSignalForm signal) {
    final signals = [...form.signals]..[index] = signal;
    onChanged(form.copyWith(signals: signals));
  }

  void _remove(int index) {
    final signals = [...form.signals]..removeAt(index);
    onChanged(
      form.copyWith(
        signals: signals,
        // "At least 3 of 2" must never be shown: the count follows the rows.
        requiredCount: form.requiredCount.clamp(
          1,
          signals.isEmpty ? 1 : signals.length,
        ),
      ),
    );
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
              onToggle: null,
            ),
            for (final (index, signal) in form.signals.indexed) ...[
              divider,
              _Row(
                key: ValueKey(
                  'habit-signal-row-${signal.kind.name}-${signal.id}',
                ),
                icon: signal.kind.icon,
                title: habitSignalDisplayName(
                  messages,
                  signal,
                  measurablesById,
                ),
                caption: _caption(messages, signal),
                checkKey: ValueKey(
                  'habit-signal-check-${signal.kind.name}-${signal.id}',
                ),
                onToggle: () => _remove(index),
                child: _RuleEditor(
                  signal: signal,
                  unit: habitSignalUnit(messages, signal, measurablesById),
                  choiceOnly:
                      signal.kind == HabitSignalKind.measurable &&
                      (measurablesById[signal.id]?.isChoice ?? false),
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
                    // An inline affordance, not a call to action: the
                    // accent stays on the glyph, the label reads as body so
                    // Save remains the one loud element on the page.
                    Text(
                      messages.habitEditorAddSignal,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (foot case final foot?) ...[divider, foot],
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
    // The same card recipe as the settings sections around it — one card
    // grammar on the page, so the signals read as a group and not as rows
    // floating on the panel background.
    return Material(
      color: tokens.colors.background.level02,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        side: BorderSide(color: tokens.colors.decorative.level01),
      ),
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
    required this.onToggle,
    this.checkKey,
    this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String caption;

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
                checked: true,
                child: InkWell(
                  key: checkKey,
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                  child: Container(
                    width: tokens.spacing.step6,
                    height: tokens.spacing.step6,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(tokens.radii.s),
                    ),
                    child: Icon(
                      LottiIcons.confirm,
                      size: IconSizes.s,
                      color: tokens.colors.text.onInteractiveAlert,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (child != null) ...[
            SizedBox(height: tokens.spacing.step3),
            // Aligned to the title's left edge — the leading icon plus its
            // gap, the same two numbers the row above uses — so the rule
            // reads as the row's own detail and starts on the title's rail.
            Padding(
              padding: EdgeInsets.only(
                left: IconSizes.m + tokens.spacing.step3,
              ),
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
    this.choiceOnly = false,
  });

  final HabitSignalForm signal;
  final String unit;
  final ValueChanged<HabitSignalForm> onChanged;

  /// A choice measurable has no quantity to bound: the only rule it can
  /// satisfy is "any entry today", so the mode toggle and threshold give
  /// way to that one line.
  final bool choiceOnly;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _threshold = TextEditingController(
    text: widget.signal.threshold?.toString() ?? '',
  );

  @override
  void didUpdateWidget(_RuleEditor old) {
    super.didUpdateWidget(old);
    // The element is reused per (kind, id); when the parent hands in a
    // different threshold the field must follow it, not keep stale text.
    if (old.signal.threshold != widget.signal.threshold) {
      final text = widget.signal.threshold?.toString() ?? '';
      if (_threshold.text != text) _threshold.text = text;
    }
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  /// Model and field move together: "any" clears both, a bounded mode
  /// takes whatever the field already shows as the threshold — so the rule
  /// that is saved is always the one on screen.
  void _switchMode({
    required HabitSignalMode mode,
    WorkoutValueType? workoutValueType,
  }) {
    final signal = widget.signal;
    if (mode == HabitSignalMode.any) {
      _threshold.clear();
      widget.onChanged(
        signal.copyWith(
          mode: mode,
          clearThreshold: true,
          clearWorkoutValueType: signal.kind == HabitSignalKind.workout,
        ),
      );
      return;
    }
    final shown = num.tryParse(_threshold.text.trim().replaceAll(',', '.'));
    widget.onChanged(
      signal.copyWith(
        mode: mode,
        threshold: shown,
        clearThreshold: shown == null,
        workoutValueType: workoutValueType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final signal = widget.signal;
    final bounded = signal.mode != HabitSignalMode.any;

    if (widget.choiceOnly) {
      return Text(
        messages.habitEditorRuleAnyEntry,
        key: ValueKey('habit-signal-choice-any-${signal.id}'),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      );
    }

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
        // Picking a dimension keeps the direction a persisted rule had;
        // "≤" is never silently shown as "≥".
        onChanged: (rule) => _switchMode(
          mode: rule == _WorkoutRule.any
              ? HabitSignalMode.any
              : (signal.mode == HabitSignalMode.any
                    ? HabitSignalMode.atLeast
                    : signal.mode),
          workoutValueType: switch (rule) {
            _WorkoutRule.duration => WorkoutValueType.duration,
            _WorkoutRule.distance => WorkoutValueType.distance,
            _WorkoutRule.energy => WorkoutValueType.energy,
            _WorkoutRule.any => null,
          },
        ),
        segments: [
          DsSegment(_WorkoutRule.any, messages.habitEditorRuleAnyWorkout),
          DsSegment(_WorkoutRule.duration, messages.habitEditorRuleDuration),
          DsSegment(_WorkoutRule.distance, messages.habitEditorRuleDistance),
          DsSegment(_WorkoutRule.energy, messages.habitEditorRuleEnergy),
        ],
      ),
      _ => DsSegmentedToggle<HabitSignalMode>(
        expand: true,
        selected: signal.mode,
        onChanged: (mode) => _switchMode(mode: mode),
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
          if (signal.kind == HabitSignalKind.workout) ...[
            SizedBox(height: tokens.spacing.step2),
            DsSegmentedToggle<HabitSignalMode>(
              key: ValueKey('habit-signal-direction-${signal.id}'),
              expand: true,
              selected: signal.mode,
              onChanged: (mode) =>
                  widget.onChanged(signal.copyWith(mode: mode)),
              segments: [
                DsSegment(
                  HabitSignalMode.atLeast,
                  messages.habitEditorRuleAtLeast,
                ),
                DsSegment(
                  HabitSignalMode.atMost,
                  messages.habitEditorRuleAtMost,
                ),
              ],
            ),
          ],
          SizedBox(height: tokens.spacing.step3),
          Text(
            messages.habitEditorValueBasisLabel,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          DsSegmentedToggle<HabitSignalValueBasis>(
            key: ValueKey('habit-signal-value-basis-${signal.id}'),
            expand: true,
            selected: signal.valueBasis,
            onChanged: (valueBasis) =>
                widget.onChanged(signal.copyWith(valueBasis: valueBasis)),
            segments: [
              DsSegment(
                HabitSignalValueBasis.today,
                messages.habitEditorValueBasisToday,
              ),
              DsSegment(
                HabitSignalValueBasis.sevenDayAverage,
                messages.habitEditorValueBasisSevenDayAverage,
              ),
              DsSegment(
                HabitSignalValueBasis.todayOrSevenDayAverage,
                messages.habitEditorValueBasisEither,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          // The unit rides beside the number it qualifies — "1000 ml" —
          // rather than as helper text under the field, where it read as a
          // stray word.
          Row(
            children: [
              Expanded(
                child: DesignSystemTextInput(
                  key: ValueKey(
                    'habit-signal-threshold-${signal.kind.name}-${signal.id}',
                  ),
                  // The unit rides beside the field visually; a screen
                  // reader still needs it in the field's own name.
                  semanticsLabel: widget.unit.isEmpty ? null : widget.unit,
                  controller: _threshold,
                  size: DesignSystemTextInputSize.small,
                  // A bounded mode without a number would save as "any entry";
                  // say so until there is one.
                  errorText: signal.threshold == null
                      ? messages.habitEditorThresholdRequired
                      : null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (raw) {
                    final value = num.tryParse(raw.trim().replaceAll(',', '.'));
                    widget.onChanged(
                      value == null
                          ? signal.copyWith(clearThreshold: true)
                          : signal.copyWith(threshold: value),
                    );
                  },
                ),
              ),
              if (widget.unit.isNotEmpty) ...[
                SizedBox(width: tokens.spacing.step2),
                // Bounded, so a long user-entered unit or a large text scale
                // truncates the unit rather than overflowing the row.
                Flexible(
                  child: Text(
                    widget.unit,
                    key: ValueKey(
                      'habit-signal-unit-${signal.kind.name}-${signal.id}',
                    ),
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
