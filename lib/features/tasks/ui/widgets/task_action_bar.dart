import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
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
/// The action row is a [Wrap], so on narrow viewports — typically
/// phones — the trailing icons reflow onto a second run instead of
/// overflowing the right edge.
class TaskActionBar extends ConsumerStatefulWidget {
  const TaskActionBar({
    required this.task,
    super.key,
  });

  final Task task;

  /// Stable test key for the Track time pill body — the outer tap zone.
  /// Idle: tapping starts a timer. Tracking-this-task: tapping
  /// navigates to the running timer entry.
  @visibleForTesting
  static const Key trackTimeKey = ValueKey('task-action-bar-track-time');

  /// Stable test key for the inset stop button that appears inside the
  /// pill while tracking. Tapping it stops the timer.
  @visibleForTesting
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

  /// Round-button diameter and pill height. The design system has no
  /// dedicated icon-button-size token; this matches `tokens.spacing.step9`
  /// (48), the standard hit-target.
  @visibleForTesting
  static const double buttonSize = 48;

  /// Icon glyph size inside both the pill and round buttons.
  @visibleForTesting
  static const double iconSize = 20;

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

  /// Tracking-state stop-button handler: stops the live timer. Only
  /// fires when the inset stop circle is tapped, never when the
  /// surrounding pill body is tapped.
  Future<void> _onStopTimer() => _timeService.stop();

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
          spacing.step4,
          spacing.step5,
          spacing.step4 + safeBottomInset,
        ),
        child: LayoutBuilder(
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
                constraints.maxWidth >= TaskActionBar.minWidthForImageButton;
            final showChecklist =
                constraints.maxWidth >=
                TaskActionBar.minWidthForChecklistButton;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TrackTimePill(
                  key: TaskActionBar.trackTimeKey,
                  isTracking: isTracking,
                  label: elapsedLabel,
                  idleSemanticLabel: messages.taskActionBarTrackTime,
                  navigateSemanticLabel: messages.taskActionBarOpenRunningTimer,
                  stopSemanticLabel: messages.taskActionBarStopTracking,
                  onStartTimer: _onStartTimer,
                  onNavigateToRunningEntry: _onNavigateToRunningEntry,
                  onStop: _onStopTimer,
                ),
                SizedBox(width: spacing.step4),
                _RoundActionButton(
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
                  _RoundActionButton(
                    key: TaskActionBar.checklistKey,
                    icon: Icons.checklist_rounded,
                    semanticLabel: messages.addActionAddChecklist,
                    onPressed: _onChecklistPressed,
                  ),
                ],
                if (showImage) ...[
                  SizedBox(width: spacing.step4),
                  _RoundActionButton(
                    key: TaskActionBar.imageKey,
                    icon: Icons.image_rounded,
                    semanticLabel: messages.addActionImportImage,
                    onPressed: _onImagePressed,
                  ),
                ],
                SizedBox(width: spacing.step4),
                _RoundActionButton(
                  key: TaskActionBar.moreKey,
                  icon: Icons.more_horiz_rounded,
                  semanticLabel: messages.taskActionBarMoreActions,
                  onPressed: _onMorePressed,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Primary "Track time" pill.
///
/// Idle: stopwatch icon + localized label; the entire pill is one tap
/// target that starts a new timer.
///
/// Tracking-this-task: live-elapsed duration with the inset stop circle
/// on the leading edge. The pill body and the stop circle are
/// independent tap zones — tapping the body navigates to the running
/// timer entry (matching the sidebar timer card), tapping the stop
/// circle stops the timer.
class _TrackTimePill extends StatelessWidget {
  const _TrackTimePill({
    required this.isTracking,
    required this.label,
    required this.idleSemanticLabel,
    required this.navigateSemanticLabel,
    required this.stopSemanticLabel,
    required this.onStartTimer,
    required this.onNavigateToRunningEntry,
    required this.onStop,
    super.key,
  });

  final bool isTracking;
  final String label;
  final String idleSemanticLabel;
  final String navigateSemanticLabel;
  final String stopSemanticLabel;
  final VoidCallback onStartTimer;
  final VoidCallback onNavigateToRunningEntry;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final fillColor = isTracking
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.surface.hover;
    // The error palette has no dedicated on-color token — its
    // defaultColor is a vivid red across both themes, so a fixed white
    // foreground stays legible on top.
    final foreground = isTracking
        ? Colors.white
        : tokens.colors.text.highEmphasis;
    final pillRadius = BorderRadius.circular(tokens.radii.badgesPills);

    return Semantics(
      button: true,
      label: isTracking ? navigateSemanticLabel : idleSemanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: pillRadius,
          onTap: isTracking ? onNavigateToRunningEntry : onStartTimer,
          child: Container(
            height: TaskActionBar.buttonSize,
            // While tracking, the leading edge holds the inset stop
            // circle. step3 keeps it visually balanced inside the pill;
            // step2 (the prior value) crowded the circle against the
            // edge. The trailing edge keeps step2 because the digits
            // already get extra breathing room from the inner Padding
            // (right: step3) below.
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: pillRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTracking)
                  _PillStopButton(
                    onStop: onStop,
                    semanticLabel: stopSemanticLabel,
                  )
                else
                  Icon(
                    Icons.timer_outlined,
                    size: TaskActionBar.iconSize,
                    color: foreground,
                  ),
                SizedBox(width: spacing.step2),
                Padding(
                  padding: EdgeInsets.only(right: spacing.step3),
                  child: Text(
                    label,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: foreground,
                      // Tabular figures + slashed zero + cv02/03/04
                      // (open 4/6/9), matching the sidebar timer pill so
                      // the elapsed digits don't shift width as they
                      // tick.
                      fontFeatures: numericBadgeFontFeatures,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inset stop circle that lives on the leading edge of the running
/// pill. Its own [InkWell] absorbs the tap so it does not bubble up to
/// the pill body's navigate handler.
class _PillStopButton extends StatelessWidget {
  const _PillStopButton({
    required this.onStop,
    required this.semanticLabel,
  });

  final VoidCallback onStop;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        key: TaskActionBar.trackTimeStopKey,
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onStop,
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.stop_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon-only action button — the round affordances after the
/// Track time pill. [backgroundColor] / [iconColor] are optional
/// overrides; when null, the default surface-hover + high-emphasis
/// colors are used. The audio button passes the alert-error fill while
/// a recording session for the open task is active.
class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: TaskActionBar.buttonSize,
            height: TaskActionBar.buttonSize,
            decoration: BoxDecoration(
              color: backgroundColor ?? tokens.colors.surface.hover,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: TaskActionBar.iconSize,
              color: iconColor ?? tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}
