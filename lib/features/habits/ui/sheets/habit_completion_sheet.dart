import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_habit_watchers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_signal_row.dart';
import 'package:lotti/features/habits/ui/widgets/measurable_quick_record_chips.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:tinycolor2/tinycolor2.dart';
import 'package:url_launcher/url_launcher.dart';

/// The compact completion sheet: the habit's own signals in view, then the
/// outcome and Record.
///
/// One [HabitSignalRow] per leaf of the habit's `autoCompleteRule` replaces
/// the dashboard that used to be embedded here — a habit shows exactly the
/// data it depends on. Tapping a quick-record chip writes the measurement at
/// once; when that satisfies the rule the outcome flips to Success and a
/// banner says so, but the sheet stays open so a comment can still be added.
/// Recording writes a normal manual completion, which always outranks an
/// automatic one for the day.
class HabitCompletionSheet extends ConsumerStatefulWidget {
  const HabitCompletionSheet({
    required this.habitId,
    required this.themeData,
    this.dateString,
    super.key,
  });

  final String habitId;
  final String? dateString;
  final ThemeData themeData;

  /// Opens the sheet for [habitId] as the app's bottom sheet / desktop
  /// dialog, optionally for a past [dateString] (`yyyy-MM-dd`).
  static Future<void> show(
    BuildContext context, {
    required String habitId,
    String? dateString,
  }) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return ModalUtils.showBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      backgroundColor: Colors.transparent,
      builder: (context) => HabitCompletionSheet(
        habitId: habitId,
        themeData: Theme.of(context),
        dateString: dateString,
      ),
    );
  }

  @override
  ConsumerState<HabitCompletionSheet> createState() =>
      _HabitCompletionSheetState();
}

class _HabitCompletionSheetState extends ConsumerState<HabitCompletionSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  late DateTime _started;
  bool _startReset = false;

  /// The outcome the [DsSegmentedToggle] currently selects. Defaults to
  /// success — the overwhelmingly common case — so the happy path is a
  /// single tap.
  HabitCompletionType _outcome = HabitCompletionType.success;

  /// Whether the user picked an outcome themselves; a chip that satisfies
  /// the rule only flips an outcome that was never touched.
  bool _outcomeChosen = false;

  /// Set once a chip tap satisfied the rule during this sheet.
  bool _autoSatisfied = false;

  /// Values recorded from chips during this sheet, by measurable id.
  final _recorded = <String, MeasurableQuickValue>{};

  /// Whether the completion being recorded is for the current day — from
  /// the date actually selected, so picking a past day in the field hides
  /// the signal controls (a chip would record a measurement *now* against a
  /// completion saved for another day).
  bool get _isToday => _started.ymd == clock.now().ymd;

  @override
  void initState() {
    super.initState();
    DateTime endOfDay() {
      final date = DateTime.parse(widget.dateString!);
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    final forToday =
        widget.dateString == null || clock.now().ymd == widget.dateString;
    _started = forToday ? clock.now() : endOfDay();
  }

  /// Opens the day's reflection for one of the goals watching this habit.
  ///
  /// The reflection is the goal's: it needs the goal's spec, its progress
  /// view (the sheet lists every dimension's evidence) and its history (so a
  /// judged day reopens showing what was recorded). The habit sheet only
  /// contributes the day — the one the user picked here, so reflecting on a
  /// backfilled day judges that day, not today.
  Future<void> _reflect(GoalHabitWatcher watcher) async {
    final agentId = watcher.identity.agentId;
    // A projection that reaches back to the picked day: the authored window
    // alone stops short of a backfilled day, and the reflection sheet would
    // then present that day's evidence as absent and invite a verdict on
    // nothing. Never shorter than a week, so a recent day keeps the goal's
    // usual picture around it.
    final progress = await ref.read(
      goalAgentProgressViewForSpanProvider((
        agentId: agentId,
        historyDays: reflectionSpanDays(from: _started, today: clock.now()),
      )).future,
    );
    final assessments = await ref.read(
      goalAssessmentHistoryProvider(agentId).future,
    );
    if (!mounted || progress == null) return;
    showGoalDayAssessmentSheet(
      context,
      agentId: agentId,
      spec: watcher.spec,
      progress: progress,
      assessments: assessments,
      day: _started,
    );
  }

  Future<void> _save() async {
    _formKey.currentState!.save();
    Navigator.pop(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final formData = _formKey.currentState?.value;
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );
    await getIt<PersistenceLogic>().createHabitCompletionEntry(
      data: HabitCompletionData(
        habitId: widget.habitId,
        dateTo: !_startReset ? clock.now() : _started,
        dateFrom: _started,
        completionType: _outcome,
      ),
      comment: formData!['comment'] as String,
      habitDefinition: habitDefinition,
    );
  }

  Future<void> _recordMeasurable(
    MeasurableDataType dataType,
    MeasurableQuickValue value,
  ) async {
    final now = clock.now();
    final saved = await getIt<PersistenceLogic>().createMeasurementEntry(
      data: MeasurementData(
        dateFrom: now,
        dateTo: now,
        value: value.value,
        choiceId: value.choiceId,
        dataTypeId: dataType.id,
      ),
      private: dataType.private ?? false,
    );
    if (!mounted) return;
    if (saved == null) {
      // The write failed (persistence logs it); the chip must not read as
      // recorded and the rule must not be re-evaluated as if it were.
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.messages.saveFailedRetry)),
        );
      return;
    }
    setState(() => _recorded[dataType.id] = value);
    await ref
        .read(habitSignalStatusProvider(widget.habitId).notifier)
        .refresh();
  }

  void _onStatus(HabitSignalStatus? status) {
    if (status == null || !status.verdict.satisfied || _autoSatisfied) return;
    if (_recorded.isEmpty) return; // only a chip tap flips the outcome
    setState(() {
      _autoSatisfied = true;
      if (!_outcomeChosen) _outcome = HabitCompletionType.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );
    if (habitDefinition == null) return const SizedBox.shrink();

    ref.listen(habitSignalStatusProvider(widget.habitId), (previous, next) {
      _onStatus(next.value);
    });
    final status = _isToday
        ? ref.watch(habitSignalStatusProvider(widget.habitId)).value
        : null;

    final form = _CompletionForm(
      formKey: _formKey,
      habitDefinition: habitDefinition,
      started: _started,
      outcome: _outcome,
      autoSatisfied: _autoSatisfied,
      signals: status == null
          ? const []
          : [
              for (final leaf in status.verdict.leaves)
                HabitSignalRow(
                  key: ValueKey('habit-signal-${leaf.rule.hashCode}'),
                  leaf: leaf,
                  status: status,
                  recordedValue: _recordedFor(leaf),
                  onRecordMeasurable: _recordMeasurable,
                  onMoreMeasurable: (dataType) => MeasurementCaptureModal.show(
                    context: context,
                    measurableDataType: dataType,
                  ),
                ),
            ],
      reflections: [
        for (final watcher
            in ref.watch(goalsWatchingHabitProvider(widget.habitId)).value ??
                const <GoalHabitWatcher>[])
          DesignSystemButton(
            key: ValueKey('habit-reflect-${watcher.identity.agentId}'),
            label: context.messages.habitReflectInGoal(
              watcher.spec.title,
            ),
            leadingIcon: LottiIcons.note,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            onPressed: () => _reflect(watcher),
          ),
      ],
      onOutcomeChanged: (value) => setState(() {
        _outcome = value;
        _outcomeChosen = true;
      }),
      onPickDate: (picked) => setState(() {
        _startReset = true;
        _started = picked;
      }),
      onClose: () => Navigator.pop(context),
      onEdit: () {
        Navigator.pop(context);
        beamToNamed(HabitsLocation.editPath(widget.habitId));
      },
      onRecord: _save,
    );

    return AppCommandScope(
      handlers: {
        AppCommandId.save: AppCommandHandler(invoke: (_) => _save()),
      },
      child: Theme(
        data: widget.themeData,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GestureDetector(
            // The form floats on a transparent sheet; a tap on the empty
            // space around it closes the sheet, as is conventional here.
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(onTap: () {}, child: form),
            ),
          ),
        ),
      ),
    );
  }

  MeasurableQuickValue? _recordedFor(HabitLeafVerdict leaf) =>
      switch (leaf.rule) {
        AutoCompleteRuleMeasurable(:final dataTypeId) => _recorded[dataTypeId],
        _ => null,
      };
}

/// The completion-capture card: habit name, optional description, the
/// signal rows, the date being recorded, an optional note, the outcome
/// segmented picker and the primary Record action.
class _CompletionForm extends StatelessWidget {
  const _CompletionForm({
    required this.formKey,
    required this.habitDefinition,
    required this.started,
    required this.outcome,
    required this.autoSatisfied,
    required this.signals,
    required this.reflections,
    required this.onOutcomeChanged,
    required this.onPickDate,
    required this.onClose,
    required this.onEdit,
    required this.onRecord,
  });

  final GlobalKey<FormBuilderState> formKey;
  final HabitDefinition habitDefinition;
  final DateTime started;
  final HabitCompletionType outcome;
  final bool autoSatisfied;
  final List<Widget> signals;

  /// One action per goal watching this habit, opening that goal's
  /// reflection for the day being recorded. Empty for a habit no goal
  /// watches, and the row is then not rendered at all.
  final List<Widget> reflections;
  final ValueChanged<HabitCompletionType> onOutcomeChanged;
  final ValueChanged<DateTime> onPickDate;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: dsCardSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.xl),
        ),
        side: BorderSide(color: tokens.colors.decorative.level01),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          minWidth: isMobile ? MediaQuery.of(context).size.width : 250,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step6,
            tokens.spacing.step4,
            tokens.spacing.step4,
            tokens.spacing.step5,
          ),
          child: FormBuilder(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habitDefinition.name,
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('habit-sheet-edit'),
                      padding: EdgeInsets.all(tokens.spacing.step3),
                      tooltip: messages.habitEditorEditTitle,
                      icon: const Icon(LottiIcons.edit),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      padding: EdgeInsets.all(tokens.spacing.step3),
                      icon: Semantics(
                        label: messages.habitCloseCompletionLabel,
                        child: const Icon(LottiIcons.close),
                      ),
                      onPressed: onClose,
                    ),
                  ],
                ),
                if (habitDefinition.description.isNotEmpty)
                  HabitDescription(habitDefinition),
                for (final signal in signals) ...[
                  SizedBox(height: tokens.spacing.step3),
                  signal,
                ],
                if (reflections.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step3),
                  // The goals' own judgement of this day, reachable from the
                  // habit: the day squares wear those verdicts, so the place
                  // that records them has to be one tap from here.
                  Wrap(
                    key: const ValueKey('habit-sheet-reflections'),
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step1,
                    children: reflections,
                  ),
                ],
                if (autoSatisfied) ...[
                  SizedBox(height: tokens.spacing.step3),
                  Container(
                    key: const ValueKey('habit-sheet-auto-banner'),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step4,
                      vertical: tokens.spacing.step3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.colors.surface.selected,
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LottiIcons.aiSpark,
                          size: IconSizes.s,
                          color: tokens.colors.interactive.enabled,
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(
                          child: Text(
                            messages.habitSheetAutoCompletedBanner,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step4),
                DateTimeField(
                  dateTime: started,
                  labelText: messages.addHabitDateLabel,
                  setDateTime: onPickDate,
                ),
                SizedBox(height: tokens.spacing.step4),
                FormBuilderTextField(
                  initialValue: '',
                  key: const Key('habit_comment_field'),
                  decoration: createDialogInputDecoration(
                    labelText: messages.addHabitCommentLabel,
                    themeData: Theme.of(context),
                  ),
                  minLines: 1,
                  maxLines: 10,
                  keyboardAppearance: Theme.of(context).brightness,
                  name: 'comment',
                ),
                SizedBox(height: tokens.spacing.step5),
                SizedBox(
                  width: double.infinity,
                  child: DsSegmentedToggle<HabitCompletionType>(
                    expand: true,
                    selected: outcome,
                    onChanged: onOutcomeChanged,
                    // Positive-first reading order: the pre-selected Success
                    // leads, the negative "Missed" is tucked last.
                    segments: [
                      DsSegment(
                        HabitCompletionType.success,
                        messages.completeHabitSuccessButton,
                      ),
                      DsSegment(
                        HabitCompletionType.skip,
                        messages.completeHabitSkipButton,
                      ),
                      DsSegment(
                        HabitCompletionType.fail,
                        messages.completeHabitFailButton,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                DesignSystemButton(
                  key: const Key('habit_save'),
                  label: messages.habitsRecordButton,
                  onPressed: onRecord,
                  fullWidth: true,
                  size: DesignSystemButtonSize.large,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The habit's description with tappable links.
class HabitDescription extends StatelessWidget {
  const HabitDescription(this.habitDefinition, {super.key});

  final HabitDefinition? habitDefinition;

  @override
  Widget build(BuildContext context) {
    Future<void> onOpen(LinkableElement link) async {
      final uri = Uri.tryParse(link.url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        getIt<DomainLogger>().log(
          LogDomain.habits,
          'Could not launch $uri',
          subDomain: 'Click Link in Description',
        );
        DevLogger.warning(
          name: 'HabitCompletionSheet',
          message: 'Could not launch $uri',
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(top: context.designTokens.spacing.step2),
      child: Linkify(
        onOpen: onOpen,
        text: '${habitDefinition?.description}',
        style: habitCompletionHeaderStyle.copyWith(fontSize: fontSizeMedium),
        linkStyle: habitCompletionHeaderStyle.copyWith(
          fontSize: fontSizeMedium,
          color: Theme.of(context).primaryColor.darken(25),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// How many days of history a reflection opened for [from] needs so that
/// the day itself is inside the projection: the days back to today plus the
/// day, never fewer than seven.
int reflectionSpanDays({required DateTime from, required DateTime today}) {
  final back = DateUtils.dateOnly(
    today,
  ).difference(DateUtils.dateOnly(from)).inDays;
  return math.max(7, back + 1);
}
