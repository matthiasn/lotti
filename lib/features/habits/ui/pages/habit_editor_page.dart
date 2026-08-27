import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/state/habit_editor_providers.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_composite_picker.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_card.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_picker.dart';
import 'package:lotti/features/habits/ui/widgets/habit_category.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/features/settings/ui/widgets/form/settings_form_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_date_time_field.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';

/// Where the habit definition is written: a two-step wizard for a new
/// habit (name it, then say how it completes), one flat page when editing.
///
/// The definition itself lives in [HabitSettingsController]; this page owns
/// the signal card's form ([HabitSignalsForm]) and writes it back as the
/// habit's `autoCompleteRule` through [HabitFormMapping] on every change, so
/// Save persists exactly what the card shows. The dashboard picker is gone —
/// the signals are the association.
class HabitEditorPage extends ConsumerStatefulWidget {
  const HabitEditorPage({
    this.habitId,
    this.returnPath = habitsRootPath,
    super.key,
  });

  /// The habit being edited; `null` creates one. The new habit's id is
  /// minted once by the state, so a route rebuild that hands the element a
  /// fresh widget keeps editing — and saving — the same habit.
  final String? habitId;
  bool get isCreate => habitId == null;

  /// Where Save, Cancel and Delete lead — the habits page, or the settings
  /// list when opened from there.
  final String returnPath;

  static const habitsRootPath = '/habits';

  @override
  ConsumerState<HabitEditorPage> createState() => HabitEditorPageState();
}

enum _Step { name, signals }

class HabitEditorPageState extends ConsumerState<HabitEditorPage> {
  /// The id this editor writes under — the given one, or one minted here
  /// for the lifetime of the element.
  late final String habitId = widget.habitId ?? uuid.v1();
  _Step _step = _Step.name;
  HabitSignalsForm? _signals;
  bool _saving = false;
  List<MeasurableDataType> _measurables = const [];
  List<String> _workoutTypes = const [];

  HabitSettingsController get _controller =>
      ref.read(habitSettingsControllerProvider(habitId).notifier);

  HabitSignalsForm _formFrom(HabitSettingsState state) =>
      _signals ??= HabitFormMapping.fromRule(
        state.habitDefinition.autoCompleteRule,
      );

  void _setSignals(HabitSignalsForm form) {
    setState(() => _signals = form);
    _controller.setAutoCompleteRule(HabitFormMapping.toRule(form));
  }

  Future<void> _save() async {
    if (_saving) return;
    final signals = _signals;
    if (signals != null && !signals.isComplete) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.habitEditorThresholdRequired,
      );
      return;
    }
    setState(() => _saving = true);
    bool saved;
    try {
      saved = await _controller.onSavePressed();
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.settingsSaveFailedToast,
        );
      }
      saved = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    if (widget.isCreate) {
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.habitEditorCreatedToast,
      );
    }
    beamToNamed(widget.returnPath);
  }

  void _continue(HabitSettingsState state) {
    final form = state.formKey.currentState;
    if (form == null) return;
    form.save();
    if (!form.validate()) return;
    setState(() => _step = _Step.signals);
  }

  Future<void> _delete() async {
    const deleteKey = 'deleteKey';
    final messages = context.messages;
    final result = await showModalActionSheet<String>(
      context: context,
      title: messages.habitDeleteQuestion,
      actions: [
        ModalSheetAction(
          icon: LottiIcons.warning,
          label: messages.habitDeleteConfirm,
          key: deleteKey,
          isDestructiveAction: true,
        ),
      ],
    );
    if (result == deleteKey) {
      await _controller.delete();
      beamToNamed(widget.returnPath);
    }
  }

  void _applyExample(HabitSettingsState state, _Example example) {
    state.formKey.currentState?.fields['name']?.didChange(example.name);
    _controller.setDirty();
    final signal = example.signal;
    if (signal == null) return;
    final form = _formFrom(state);
    if (form.signals.any((s) => s.kind == signal.kind && s.id == signal.id)) {
      return;
    }
    _setSignals(form.copyWith(signals: [...form.signals, signal]));
  }

  Future<void> _openPicker(HabitSettingsState state) =>
      ModalUtils.showSinglePageModal<void>(
        context: context,
        builder: (_) => HabitSignalPicker(
          measurables: _measurables,
          workoutTypes: _workoutTypes,
          selected: {
            for (final s in _formFrom(state).signals) (s.kind, s.id),
          },
          onToggle: (kind, id, {required selected}) {
            final form = _formFrom(state);
            if (selected) {
              _setSignals(
                form.copyWith(
                  signals: [...form.signals, _defaultSignal(kind, id)],
                ),
              );
            } else {
              _setSignals(
                form.copyWith(
                  signals: [
                    for (final s in form.signals)
                      if (s.kind != kind || s.id != id) s,
                  ],
                ),
              );
            }
          },
        ),
      );

  Future<void> _openComposite(HabitSettingsState state) {
    final form = _formFrom(state);
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      builder: (_) => HabitCompositePicker(
        value: form.composite,
        requiredCount: form.requiredCount,
        signalCount: form.signals.length,
        onChanged: (rule, required) => _setSignals(
          _formFrom(state).copyWith(composite: rule, requiredCount: required),
        ),
      ),
    );
  }

  /// Record-based by default; steps start at the customary daily target.
  static HabitSignalForm _defaultSignal(HabitSignalKind kind, String id) =>
      id == GoalHealthDataTypes.steps
      ? const HabitSignalForm(
          kind: HabitSignalKind.health,
          id: GoalHealthDataTypes.steps,
          mode: HabitSignalMode.atLeast,
          threshold: 6000,
        )
      : HabitSignalForm(kind: kind, id: id);

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    if (!widget.isCreate) {
      final habitAsync = ref.watch(habitByIdProvider(habitId));
      // A loaded editor stays on screen through a background reload or a
      // transient stream error; only a habit that never arrived gets the
      // shell.
      if (habitAsync.value == null) {
        return EmptyScaffoldWithTitle(messages.habitEditorEditTitle);
      }
    }

    final measurablesAsync = ref.watch(measurableDataTypesStreamProvider);
    if (measurablesAsync.value case final loaded?) {
      _measurables = [
        for (final m in loaded)
          if (m.deletedAt == null) m,
      ];
    }
    if (ref.watch(workoutTypesProvider).value case final loaded?) {
      _workoutTypes = loaded;
    }
    final measurablesById = {for (final m in _measurables) m.id: m};

    final state = ref.watch(habitSettingsControllerProvider(habitId));
    final signals = _formFrom(state);
    final item = state.habitDefinition;
    final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);
    final alertAtTime = item.habitSchedule.mapOrNull(
      daily: (d) => d.alertAtTime,
    );
    final onSignalsStep = !widget.isCreate || _step == _Step.signals;

    final primary = DesignSystemButton(
      key: const ValueKey('habit-editor-primary'),
      label: !widget.isCreate
          ? messages.saveButton
          : onSignalsStep
          ? messages.habitEditorCreateAction
          : messages.habitEditorContinue,
      onPressed: onSignalsStep ? _save : () => _continue(state),
      isLoading: _saving,
      size: DesignSystemButtonSize.large,
      fullWidth: true,
    );

    final title = widget.isCreate
        ? messages.habitEditorCreateTitle
        : messages.habitEditorEditTitle;

    return AppCommandScope(
      handlers: {
        AppCommandId.save: AppCommandHandler(
          invoke: (_) {
            if (onSignalsStep) _save();
          },
        ),
      },
      child: PopScope(
        canPop: !widget.isCreate || _step == _Step.name,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _step = _Step.name);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () {
                if (widget.isCreate && _step == _Step.signals) {
                  setState(() => _step = _Step.name);
                } else {
                  beamToNamed(widget.returnPath);
                }
              },
            ),
            title: Text(title),
          ),
          body: SafeArea(
            child: DetailContentWidth(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kActionListContentMaxWidth,
                  ),
                  child: Column(
                    children: [
                      if (widget.isCreate)
                        Padding(
                          padding: EdgeInsets.only(top: tokens.spacing.step4),
                          child: _StepProgress(step: _step),
                        ),
                      Expanded(
                        child: FormBuilder(
                          key: state.formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: _controller.setDirty,
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.step4,
                              vertical: tokens.spacing.step5,
                            ),
                            children: [
                              // The name step stays mounted (offstage) on the
                              // signals step so the form keeps its values.
                              Offstage(
                                offstage: widget.isCreate && onSignalsStep,
                                child: _NameSection(
                                  item: item,
                                  isCreate: widget.isCreate,
                                  onExample: (example) =>
                                      _applyExample(state, example),
                                ),
                              ),
                              if (onSignalsStep) ...[
                                if (widget.isCreate) ...[
                                  Text(
                                    messages.habitEditorSignalsHeading,
                                    style: tokens
                                        .typography
                                        .styles
                                        .heading
                                        .heading2
                                        .copyWith(
                                          color:
                                              tokens.colors.text.highEmphasis,
                                        ),
                                  ),
                                  SizedBox(height: tokens.spacing.step2),
                                  Text(
                                    messages.habitEditorSignalsSubtitle,
                                    style: tokens
                                        .typography
                                        .styles
                                        .body
                                        .bodyMedium
                                        .copyWith(
                                          color:
                                              tokens.colors.text.mediumEmphasis,
                                        ),
                                  ),
                                ] else
                                  SettingsFormSection(
                                    title: messages.habitEditorSignalsHeading,
                                    children: const [],
                                  ),
                                SizedBox(height: tokens.spacing.step4),
                                HabitSignalCard(
                                  form: signals,
                                  measurablesById: measurablesById,
                                  onChanged: _setSignals,
                                  onAddSignal: () => _openPicker(state),
                                  onChangeComposite: () =>
                                      _openComposite(state),
                                ),
                                SizedBox(height: tokens.spacing.step5),
                                SettingsFormSection(
                                  title: messages.habitEditorSectionSettings,
                                  children: [
                                    SelectCategoryWidget(
                                      habitId: habitId,
                                    ),
                                    SettingsDateTimeField(
                                      dateTime: item.activeFrom,
                                      labelText: messages.habitActiveFromLabel,
                                      setDateTime: _controller.setActiveFrom,
                                      mode: CupertinoDatePickerMode.date,
                                    ),
                                    SettingsDateTimeField(
                                      dateTime: showFrom,
                                      labelText: messages.habitShowFromLabel,
                                      setDateTime: _controller.setShowFrom,
                                      mode: CupertinoDatePickerMode.time,
                                    ),
                                    SettingsDateTimeField(
                                      dateTime: alertAtTime,
                                      labelText: messages.habitShowAlertAtLabel,
                                      setDateTime: _controller.setAlertAtTime,
                                      clear: _controller.clearAlertAtTime,
                                      mode: CupertinoDatePickerMode.time,
                                    ),
                                    DesignSystemSelectionRow(
                                      key: const ValueKey(
                                        'habit-editor-notify',
                                      ),
                                      title: messages.habitEditorNotifyTitle,
                                      subtitle:
                                          messages.habitEditorNotifyCaption,
                                      type: DesignSystemSelectionRowType
                                          .multiSelect,
                                      selected: item.autoCompleteNotify,
                                      showSelectedBackground: false,
                                      onTap: () =>
                                          _controller.setAutoCompleteNotify(
                                            notify: !item.autoCompleteNotify,
                                          ),
                                    ),
                                  ],
                                ),
                                if (!widget.isCreate) ...[
                                  SettingsFormSection(
                                    title: messages.habitSectionOptionsTitle,
                                    children: [
                                      FormSwitch(
                                        name: 'priority',
                                        key: const Key('habit_priority'),
                                        semanticsLabel: messages.favoriteLabel,
                                        initialValue: item.priority,
                                        title: messages.favoriteLabel,
                                        icon: LottiIcons.star,
                                      ),
                                      FormSwitch(
                                        name: 'private',
                                        initialValue: item.private,
                                        title: messages.privateLabel,
                                        subtitle:
                                            messages.privateSwitchDescription,
                                        icon: LottiIcons.lock,
                                      ),
                                      FormSwitch(
                                        name: 'active',
                                        key: const Key('habit_active'),
                                        initialValue: item.active,
                                        title: messages.activeLabel,
                                        subtitle: messages
                                            .habitActiveSwitchDescription,
                                        icon: LottiIcons.visible,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: tokens.spacing.step4),
                                  DesignSystemButton(
                                    key: const ValueKey('habit-editor-delete'),
                                    label: messages.deleteButton,
                                    onPressed: _delete,
                                    variant: DesignSystemButtonVariant.tertiary,
                                    leadingIcon: LottiIcons.delete,
                                    fullWidth: true,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          tokens.spacing.step4,
                          tokens.spacing.step3,
                          tokens.spacing.step4,
                          tokens.spacing.step4,
                        ),
                        child: primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One example pill: the name it fills in and the signal it pre-checks.
class _Example {
  const _Example(this.name, this.signal);
  final String name;
  final HabitSignalForm? signal;
}

/// Step 1 (create) / the top of the edit page: name, description, and — when
/// creating — example pills that teach auto-completion by doing.
class _NameSection extends StatelessWidget {
  const _NameSection({
    required this.item,
    required this.isCreate,
    required this.onExample,
  });

  final HabitDefinition item;
  final bool isCreate;
  final ValueChanged<_Example> onExample;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final examples = [
      _Example(
        messages.habitEditorExampleBloodPressure,
        const HabitSignalForm(
          kind: HabitSignalKind.health,
          id: GoalHealthDataTypes.bloodPressureSystolic,
        ),
      ),
      _Example(
        messages.habitEditorExampleSteps,
        const HabitSignalForm(
          kind: HabitSignalKind.health,
          id: GoalHealthDataTypes.steps,
          mode: HabitSignalMode.atLeast,
          threshold: 6000,
        ),
      ),
      _Example(
        messages.habitEditorExampleStrength,
        const HabitSignalForm(
          kind: HabitSignalKind.workout,
          id: 'functionalStrengthTraining',
        ),
      ),
      _Example(messages.habitEditorExampleMedication, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCreate) ...[
          Text(
            messages.habitEditorNameHeading,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.habitEditorNameSubtitle,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
        ],
        SettingsFormTextField(
          key: const Key('habit_name_field'),
          initialValue: item.name,
          labelText: messages.settingsHabitsNameLabel,
          name: 'name',
          semanticsLabel: messages.settingsHabitsNameLabel,
          autofocus: isCreate,
        ),
        SettingsFormTextField(
          key: const Key('habit_description_field'),
          initialValue: item.description,
          labelText: messages.settingsHabitsDescriptionLabel,
          fieldRequired: false,
          multiline: true,
          name: 'description',
          semanticsLabel: messages.settingsHabitsDescriptionLabel,
        ),
        if (isCreate) ...[
          SizedBox(height: tokens.spacing.step4),
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              for (final example in examples)
                DsPill(
                  key: ValueKey(
                    'habit-editor-example-${examples.indexOf(example)}',
                  ),
                  variant: DsPillVariant.filled,
                  bordered: true,
                  label: example.name,
                  onTap: () => onExample(example),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.habitEditorExamplesHint,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final position = _Step.values.indexOf(step);
    final label = context.messages.habitEditorStepProgress(
      position + 1,
      _Step.values.length,
    );
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final candidate in _Step.values) ...[
                  AnimatedContainer(
                    duration: MotionDurations.short4,
                    width: candidate == step
                        ? tokens.spacing.step5
                        : tokens.spacing.step2,
                    height: tokens.spacing.step2,
                    decoration: BoxDecoration(
                      color: _Step.values.indexOf(candidate) <= position
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.lowEmphasis,
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                    ),
                  ),
                  if (candidate != _Step.values.last)
                    SizedBox(width: tokens.spacing.step2),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
