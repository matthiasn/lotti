import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar_buttons.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/timer_navigation.dart';

/// Sticky action bar pinned to the bottom of the task details page.
///
/// Replaces the floating action button with an edge-to-edge glass strip
/// (top hairline + backdrop blur + soft top→bottom gradient) that
/// surfaces the most-frequent task actions:
///
/// * a primary "Track time" pill. Idle: tap starts a new timer. While a
///   timer is running on this task: tapping the pill body navigates to
///   the running timer entry (mirrors the sidebar timer card); only the
///   inset stop circle stops the timer.
/// * round affordances (add checklist, import image, record audio) and the
///   labeled "Add" trigger, which opens the create-entry sheet for the long
///   tail (linked task / event / paste image / capture screenshot — the
///   latter desktop-only inside that sheet)
///
/// The action row is a single [Row] with width-based priority drop: on
/// narrow viewports the lower-priority trailing icons (image, then
/// checklist) are hidden once the inner width falls below
/// [minWidthForImageButton] / [minWidthForChecklistButton] instead of
/// overflowing the right edge.
class TaskActionBar extends ConsumerStatefulWidget {
  const TaskActionBar({
    required this.task,
    this.topSlot,
    this.compact = false,
    super.key,
  });

  final Task task;
  final Widget? topSlot;

  /// Drops the checklist, microphone and image affordances from the visible
  /// row and demotes the Track time pill to its subdued tonal treatment, so
  /// the bar collapses to the primary plus the Add trigger.
  ///
  /// True while the task page shows its first-run block. Every action here
  /// then has exactly one other home — the card words the checklist, note
  /// and voice offers, and the Add sheet (which stands its duplicated rows
  /// down while the card shows) carries the labeled "Import an image" row.
  /// Keeping the bar's image circle beside the very "+" that opens that
  /// sheet put one action in two adjacent homes, the exact
  /// overlapping-membership defect this flag exists to prevent.
  ///
  /// An *active* recording overrides this: the mic is the only way to see and
  /// stop a session in progress, so a live one is never hidden.
  final bool compact;

  /// Stable test key for the Track time pill body — the outer tap zone.
  /// Idle: tapping starts a timer. Tracking-this-task: tapping
  /// navigates to the running timer entry.
  @visibleForTesting
  static const Key trackTimeKey = ValueKey('task-action-bar-track-time');

  /// Key for the inset stop button that appears inside the pill while
  /// tracking. Tapping it stops the timer. Referenced at runtime by the
  /// extracted [TrackTimePill] and also used as a stable test key.
  static const Key trackTimeStopKey = ValueKey(
    'task-action-bar-track-time-stop',
  );

  /// Stable test key for the checklist icon button.
  @visibleForTesting
  static const Key checklistKey = ValueKey('task-action-bar-checklist');

  /// Stable test key for the import-image icon button.
  @visibleForTesting
  static const Key imageKey = ValueKey('task-action-bar-image');

  /// Stable test key for the audio icon button.
  @visibleForTesting
  static const Key audioKey = ValueKey('task-action-bar-audio');

  /// Stable test key for the "more actions" icon button.
  @visibleForTesting
  static const Key moreKey = ValueKey('task-action-bar-more');

  /// Stable test key for the optional activity area above the action row.
  @visibleForTesting
  static const Key topSlotKey = ValueKey('task-action-bar-top-slot');

  /// Round-button diameter and pill height. The design system has no
  /// dedicated icon-button-size token; this matches `tokens.spacing.step9`
  /// (48), the standard hit-target. Referenced at runtime by the extracted
  /// [TrackTimePill].
  static const double buttonSize = 48;

  /// Icon glyph size inside both the pill and round buttons. Referenced at
  /// runtime by the extracted [TrackTimePill].
  static const double iconSize = 20;

  /// Stop control size inside the Track time pill. Referenced at runtime by
  /// the extracted [TrackTimePill].
  static const double pillStopButtonSize = 32;

  /// Stop glyph size inside the Track time pill's stop control. Referenced
  /// at runtime by the extracted [TrackTimePill].
  static const double pillStopIconSize = 18;

  /// Minimum [LayoutBuilder] inner width at which the checklist
  /// affordance is included. Checklist is dropped second (after image)
  /// when the row would otherwise overflow.
  ///
  /// Both thresholds price the Add trigger as its labeled pill (roughly a
  /// 40px premium over the old bare circle): the label is the trigger's
  /// honesty, so it is the round buttons that give way to width pressure,
  /// never the word. The narrowest real rows (a 390 phone) still hold the
  /// Track time pill, the mic and the labeled Add.
  @visibleForTesting
  static const double minWidthForChecklistButton = 468;

  /// Minimum [LayoutBuilder] inner width at which the image affordance
  /// is included. Image is dropped first (before checklist) when the
  /// row would otherwise overflow. Both stay reachable via the Add menu.
  @visibleForTesting
  static const double minWidthForImageButton = 528;

  /// Minimum [LayoutBuilder] inner width at which the Add trigger renders
  /// as its labeled pill; below it the bare "+" circle returns. Priced for
  /// the widest translated idle pill (Portuguese), like the other
  /// thresholds. The label would ideally never give way, but on a phone the
  /// row cannot hold Track time, the mic AND the labeled pill — and the mic
  /// is one of the bar's two lead actions, so it is the label that yields.
  @visibleForTesting
  static const double minWidthForLabeledAdd = 434;

  @override
  ConsumerState<TaskActionBar> createState() => _TaskActionBarState();
}

class _TaskActionBarState extends ConsumerState<TaskActionBar> {
  final TimeService _timeService = getIt<TimeService>();
  StreamSubscription<JournalEntity?>? _subscription;
  JournalEntity? _running;

  @override
  void initState() {
    super.initState();
    _running = _timeService.getCurrent();
    _subscription = _timeService.getStream().listen((event) {
      if (!mounted) return;
      setState(() => _running = event);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// True when the live timer is recording against *this* task. We compare
  /// against [TimeService.linkedFrom] (the parent the timer was started
  /// for) rather than the timer entry's own id.
  bool get _isTrackingThisTask {
    if (_running == null) return false;
    return _timeService.linkedFrom?.meta.id == widget.task.meta.id;
  }

  /// Idle-state handler: tapping the pill creates a new timer linked to
  /// the open task and starts it.
  Future<void> _onStartTimer() async {
    final service = ref.read(entryCreationServiceProvider);
    await service.createTimerEntry(linked: widget.task);
  }

  /// Tracking-state body handler: tapping the pill navigates to the
  /// running timer entry. Mirrors the desktop sidebar's timer card so
  /// users have a consistent way to jump to the timer.
  void _onNavigateToRunningEntry() {
    final running = _running;
    if (running == null) return;
    navigateToTimerTarget(
      ref: ref,
      current: running,
      linkedFrom: _timeService.linkedFrom,
    );
  }

  /// Tracking-state stop-button handler: persists the running timer's
  /// `dateTo` as the moment of the tap, then stops the live timer. Only
  /// fires when the inset stop circle is tapped, never when the
  /// surrounding pill body is tapped.
  ///
  /// Routing through `EntryController.save(stopRecording: true)` keeps
  /// the action-bar stop path in lockstep with the entry-editor stop
  /// button (`duration_widget.dart`): the controller writes
  /// `dateTo: DateTime.now()` and then calls `TimeService.stop()` after
  /// `stopRecordingDelay`. Calling `_timeService.stop()` here directly
  /// would clear in-memory state without persisting, leaving the DB row
  /// at whatever `dateTo` was last written and shaving the trailing
  /// minute or two off the recorded session.
  Future<void> _onStopTimer() async {
    final running = _running ?? _timeService.getCurrent();
    if (running == null) {
      await _timeService.stop();
      return;
    }
    await ref
        .read(entryControllerProvider(running.meta.id).notifier)
        .save(stopRecording: true);
  }

  Future<void> _onChecklistPressed() async {
    await ref
        .read(entryCreationServiceProvider)
        .createChecklist(task: widget.task);
  }

  Future<void> _onImagePressed() async {
    await ref
        .read(entryCreationServiceProvider)
        .importImage(
          context,
          linkedId: widget.task.meta.id,
          categoryId: widget.task.meta.categoryId,
          analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider),
        );
  }

  void _onAudioPressed() {
    ref
        .read(entryCreationServiceProvider)
        .showAudioRecordingModal(
          context,
          linkedId: widget.task.meta.id,
          categoryId: widget.task.meta.categoryId,
        );
  }

  Future<void> _onMorePressed() async {
    await ref
        .read(entryCreationServiceProvider)
        .showCreateEntryModal(
          context,
          linkedFromId: widget.task.meta.id,
          categoryId: widget.task.meta.categoryId,
          // While the first-run card words the writing actions, the sheet
          // holds only attach-class offers (image, screenshot, linked task)
          // and both the trigger and the sheet say "Attach"; the generic
          // "Add" returns with the full row set.
          title: widget.compact
              ? context.messages.createEntryAttachTitle
              : null,
        );
  }

  /// Pill-specific elapsed-time formatter.
  ///
  /// Under one hour we drop the leading hours field and render `mm:ss`
  /// (e.g. `01:30`) so the pill stays compact for the dominant short-
  /// session case. At one hour and beyond we fall back to the shared
  /// `hh:mm:ss` format used elsewhere (sidebar timer, journal entries).
  String _formatPillDuration(Duration elapsed) {
    if (elapsed >= const Duration(hours: 1)) {
      return formatDuration(elapsed);
    }
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// True when an audio recording session is currently active (recording
  /// or paused) and is linked to *this* task — same task-scoping rule as
  /// the timer pill.
  bool _isRecordingAudioForThisTask(AudioRecorderState recorderState) {
    final status = recorderState.status;
    final isActive =
        status == AudioRecorderStatus.recording ||
        status == AudioRecorderStatus.paused;
    return isActive && recorderState.linkedId == widget.task.meta.id;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;

    final isTracking = _isTrackingThisTask;
    final elapsedLabel = isTracking
        ? _formatPillDuration(
            _running!.meta.dateTo.difference(_running!.meta.dateFrom),
          )
        : messages.taskActionBarTrackTime;

    final isRecordingAudio = _isRecordingAudioForThisTask(
      ref.watch(audioRecorderControllerProvider),
    );

    // Edge-to-edge glass strip (hairline + blur + gradient). The host
    // page must use `Scaffold.extendBody: true` so body content paints
    // behind this strip — that's what BackdropFilter samples and blurs.
    //
    // The bottom of the inner padding adds the system home-indicator
    // inset (e.g. iPhones with no home button). The glass surface still
    // extends edge-to-edge into that inset, while the touchable row sits
    // above it.
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;

    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.step5,
          // The optional activity slot collapses to zero height when idle and
          // brings its own bottom gap when active, so keep the bar's standard
          // top padding in both cases rather than tightening it.
          spacing.step4,
          spacing.step5,
          spacing.step4 + safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.topSlot != null)
              KeyedSubtree(
                key: TaskActionBar.topSlotKey,
                child: widget.topSlot!,
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Affordances are dropped in priority order so the row
                // always fits on a single line. Image goes first, then
                // checklist, then the Add trigger's label; everything
                // dropped stays reachable via the Add sheet.
                //
                // Thresholds include the widest translated idle pill
                // (Portuguese "Monitorar o tempo"), 48 px round buttons,
                // step4 (12 px) gaps, and the Add trigger's labeled pill
                // with its opens-caret. Each round button costs ≈60 px, the
                // labeled trigger ≈64 px over the bare circle — hence 528
                // for the five-control row and 468 for the four-control row.
                // While the first-run block shows, the bar keeps ONLY what no
                // other surface offers: Track time and the Add trigger. The
                // image circle sat immediately beside the "+" that opens a
                // sheet listing a labeled, subtitled "Import an image" row —
                // the same action in two adjacent homes, which is the exact
                // overlapping-membership defect `compact` exists to prevent.
                final showImage =
                    !widget.compact &&
                    constraints.maxWidth >=
                        TaskActionBar.minWidthForImageButton;
                final showChecklist =
                    !widget.compact &&
                    constraints.maxWidth >=
                        TaskActionBar.minWidthForChecklistButton;
                // On a compact row too narrow for two labeled pills, the
                // demoted secondary gives up its word: Track time folds to
                // an icon circle (tooltip and semantics keep its name) while
                // the Attach trigger — the likelier act on a blank task —
                // stays labeled. Decided from the REAL localized pill
                // widths, not a pixel guess, so an English phone that fits
                // both labels keeps both. A RUNNING timer always keeps the
                // pill: the elapsed readout and the inset stop control are
                // the whole point.
                final compactIconOnlyTrack =
                    widget.compact &&
                    !isTracking &&
                    trackTimePillWidth(
                              context,
                              messages.taskActionBarTrackTime,
                            ) +
                            spacing.step4 +
                            addMenuPillWidth(
                              context,
                              messages.createEntryAttachTitle,
                            ) >
                        constraints.maxWidth;
                final rowChildren = <Widget>[
                  if (compactIconOnlyTrack)
                    DsGlassRoundButton(
                      key: TaskActionBar.trackTimeKey,
                      icon: Icons.timer_outlined,
                      semanticLabel: messages.taskActionBarTrackTime,
                      onPressed: _onStartTimer,
                      // The subdued pill's own treatment, not the glass
                      // chip's: in dark theme the default glass fill read
                      // BRIGHTER than the Attach pill beside it, inverting
                      // the very demotion this circle exists to express.
                      backgroundColor: tokens.colors.surface.enabled,
                      outlineColor: tokens.colors.decorative.level02,
                    )
                  else
                    TrackTimePill(
                      key: TaskActionBar.trackTimeKey,
                      isTracking: isTracking,
                      subdued: widget.compact,
                      label: elapsedLabel,
                      idleSemanticLabel: messages.taskActionBarTrackTime,
                      navigateSemanticLabel:
                          messages.taskActionBarOpenRunningTimer,
                      stopSemanticLabel: messages.taskActionBarStopTracking,
                      onStartTimer: _onStartTimer,
                      onNavigateToRunningEntry: _onNavigateToRunningEntry,
                      onStop: _onStopTimer,
                    ),
                  if (!widget.compact || isRecordingAudio) ...[
                    SizedBox(width: spacing.step4),
                    DsGlassRoundButton(
                      key: TaskActionBar.audioKey,
                      icon: Icons.mic_rounded,
                      semanticLabel: isRecordingAudio
                          ? messages.taskActionBarAudioRecordingActive
                          : messages.taskFirstRunRecordAudio,
                      onPressed: _onAudioPressed,
                      backgroundColor: isRecordingAudio
                          ? tokens.colors.alert.error.defaultColor
                          : null,
                      // Idle, the mic wears the accent as a ring and an
                      // accent glyph — a peer of Track time rather than one
                      // of the quiet utilities beside it. Tracked time and
                      // captured thoughts are equally load-bearing for a
                      // task, so the bar carries two lead actions; the mic
                      // stays outlined rather than filled so the strip still
                      // holds only one filled shape.
                      outlineColor: isRecordingAudio
                          ? null
                          : tokens.colors.interactive.enabled,
                      iconColor: isRecordingAudio
                          ? Colors.white
                          : tokens.colors.interactive.enabled,
                    ),
                  ],
                  if (showChecklist) ...[
                    SizedBox(width: spacing.step4),
                    DsGlassRoundButton(
                      key: TaskActionBar.checklistKey,
                      icon: Icons.checklist_rounded,
                      semanticLabel: messages.taskFirstRunAddChecklist,
                      onPressed: _onChecklistPressed,
                    ),
                  ],
                  if (showImage) ...[
                    SizedBox(width: spacing.step4),
                    DsGlassRoundButton(
                      key: TaskActionBar.imageKey,
                      icon: Icons.image_rounded,
                      semanticLabel: messages.addActionImportImage,
                      onPressed: _onImagePressed,
                    ),
                  ],
                  SizedBox(width: spacing.step4),
                  // The sheet this opens titles itself "Add" and holds
                  // creation verbs — including the page's only route to a
                  // linked sub-task. An overflow glyph promised leftovers
                  // and delivered the page's creation hub; a bare "+"
                  // half-fixed that but still broke the page's own rule
                  // that "+" creates in place. Wherever the row has width,
                  // the trigger says the same word as its destination; only
                  // the narrowest rows — where the mic, the bar's other
                  // lead action, needs the space — fall back to the circle,
                  // whose semantics still carry the sheet's contents.
                  if (widget.compact ||
                      constraints.maxWidth >=
                          TaskActionBar.minWidthForLabeledAdd)
                    AddMenuPill(
                      key: TaskActionBar.moreKey,
                      // "Attach" while first-run: the page already shows the
                      // word "Add" on half a dozen affordances, and this
                      // trigger's curated contents are all attach-class. The
                      // label is scent a TOUCH user can see — the tooltip
                      // never surfaces on mobile. The paperclip goes with
                      // it: on this page "+" means commits-immediately, and
                      // a trigger that opens a sheet must not wear it.
                      icon: widget.compact
                          ? Icons.attach_file_rounded
                          : Icons.add_rounded,
                      label: widget.compact
                          ? messages.createEntryAttachTitle
                          : messages.createEntryTitle,
                      // Mode-aware scent: while the first-run card words the
                      // writing actions, the sheet holds only the net-new
                      // offers; once the card retires, the sheet holds
                      // everything and the hint must say so — a trigger
                      // whose honesty expires the moment the user succeeds
                      // is not honest.
                      tooltip: widget.compact
                          ? messages.createEntryTriggerHint
                          : messages.createEntryTriggerHintFull,
                      onPressed: _onMorePressed,
                    )
                  else
                    DsGlassRoundButton(
                      key: TaskActionBar.moreKey,
                      icon: Icons.add_rounded,
                      semanticLabel: messages.createEntryTriggerHintFull,
                      onPressed: _onMorePressed,
                    ),
                ];
                // While the first-run block shows, Add leads the row: on a
                // blank task the sheet route is the likelier act, and the
                // eye should land on it first. Track time leads again the
                // moment real content exists and tracking becomes dominant.
                // Reversing the list (gaps and all) rather than flipping the
                // Row's text direction keeps every child's own content LTR.
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.compact
                      ? rowChildren.reversed.toList()
                      : rowChildren,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
