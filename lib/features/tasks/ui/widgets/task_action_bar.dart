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
/// * round affordances: add checklist, import image, record audio, and
///   "more actions" (opens the existing create-entry menu for long-tail
///   items like Event / Text / Paste image / link to event / capture
///   screenshot — the latter is desktop-only inside that menu)
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
    super.key,
  });

  final Task task;
  final Widget? topSlot;

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
  @visibleForTesting
  static const double minWidthForChecklistButton = 340;

  /// Minimum [LayoutBuilder] inner width at which the image affordance
  /// is included. Image is dropped first (before checklist) when the
  /// row would otherwise overflow. Both stay reachable via the "..."
  /// (more) menu.
  @visibleForTesting
  static const double minWidthForImageButton = 400;

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
        .read(entryControllerProvider(id: running.meta.id).notifier)
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
                // checklist; both stay reachable via the "..." (more) menu.
                //
                // Thresholds are based on the worst-case rendered widths of
                // the inner content: the idle pill ("Track time" label,
                // ~150 px including icon and padding), 48 px round buttons,
                // and step4 (12 px) gaps. Adding each extra button costs
                // ~60 px, so 5 items need ≈ 400 px and 4 items need ≈ 340.
                final showImage =
                    constraints.maxWidth >=
                    TaskActionBar.minWidthForImageButton;
                final showChecklist =
                    constraints.maxWidth >=
                    TaskActionBar.minWidthForChecklistButton;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TrackTimePill(
                      key: TaskActionBar.trackTimeKey,
                      isTracking: isTracking,
                      label: elapsedLabel,
                      idleSemanticLabel: messages.taskActionBarTrackTime,
                      navigateSemanticLabel:
                          messages.taskActionBarOpenRunningTimer,
                      stopSemanticLabel: messages.taskActionBarStopTracking,
                      onStartTimer: _onStartTimer,
                      onNavigateToRunningEntry: _onNavigateToRunningEntry,
                      onStop: _onStopTimer,
                    ),
                    SizedBox(width: spacing.step4),
                    DsGlassRoundButton(
                      key: TaskActionBar.audioKey,
                      icon: Icons.mic_rounded,
                      semanticLabel: isRecordingAudio
                          ? messages.taskActionBarAudioRecordingActive
                          : messages.addActionAddAudioRecording,
                      onPressed: _onAudioPressed,
                      backgroundColor: isRecordingAudio
                          ? tokens.colors.alert.error.defaultColor
                          : null,
                      iconColor: isRecordingAudio ? Colors.white : null,
                    ),
                    if (showChecklist) ...[
                      SizedBox(width: spacing.step4),
                      DsGlassRoundButton(
                        key: TaskActionBar.checklistKey,
                        icon: Icons.checklist_rounded,
                        semanticLabel: messages.addActionAddChecklist,
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
                    DsGlassRoundButton(
                      key: TaskActionBar.moreKey,
                      icon: Icons.more_horiz_rounded,
                      semanticLabel: messages.taskActionBarMoreActions,
                      onPressed: _onMorePressed,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
