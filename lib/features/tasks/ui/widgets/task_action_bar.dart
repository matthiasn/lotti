import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/services/time_service.dart';

/// Sticky action bar pinned to the bottom of the task details page.
///
/// Replaces the floating action button with an edge-to-edge glass strip
/// (top hairline + backdrop blur + soft top→bottom gradient) that
/// surfaces the most-frequent task actions:
///
/// * a primary "Track time" pill that toggles into a live elapsed-time
///   readout while a timer is running on this task — tapping it then
///   stops the timer
/// * round affordances: add checklist, import image, record audio,
///   "more actions" (opens the existing create-entry menu for long-tail
///   items like Event / Text / Paste image / link to event), and
///   capture screenshot
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

  /// Stable test key for the Track time pill.
  @visibleForTesting
  static const Key trackTimeKey = ValueKey('task-action-bar-track-time');

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

  /// Stable test key for the screenshot icon button.
  @visibleForTesting
  static const Key screenshotKey = ValueKey('task-action-bar-screenshot');

  /// Round-button diameter and pill height. The design system has no
  /// dedicated icon-button-size token; this matches `tokens.spacing.step9`
  /// (48), the standard hit-target.
  @visibleForTesting
  static const double buttonSize = 48;

  /// Icon glyph size inside both the pill and round buttons.
  @visibleForTesting
  static const double iconSize = 20;

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

  Future<void> _onTrackTimePressed() async {
    if (_isTrackingThisTask) {
      await _timeService.stop();
      return;
    }
    final service = ref.read(entryCreationServiceProvider);
    await service.createTimerEntry(linked: widget.task);
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

  Future<void> _onScreenshotPressed() async {
    await ref
        .read(entryCreationServiceProvider)
        .createScreenshotEntry(
          linkedId: widget.task.meta.id,
          categoryId: widget.task.meta.categoryId,
          analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;

    final isTracking = _isTrackingThisTask;
    final elapsedLabel = isTracking
        ? formatDuration(
            _running!.meta.dateTo.difference(_running!.meta.dateFrom),
          )
        : messages.taskActionBarTrackTime;

    // Edge-to-edge glass strip (hairline + blur + gradient). The host
    // page must use `Scaffold.extendBody: true` so body content paints
    // behind this strip — that's what BackdropFilter samples and blurs.
    //
    // No SafeArea here: the host page lifts the bar above the mobile
    // bottom-nav pill via DesignSystemBottomNavigationBar.occupiedHeight.
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.step5,
          vertical: spacing.step4,
        ),
        // Wrap so the trailing icons reflow onto a second run on narrow
        // viewports instead of overflowing the right edge. Using a real
        // Wrap means we don't need to predict text widths or maintain
        // parallel "compact" metric tiers.
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: spacing.step4,
          runSpacing: spacing.step3,
          children: [
            _TrackTimePill(
              key: TaskActionBar.trackTimeKey,
              isTracking: isTracking,
              label: elapsedLabel,
              idleSemanticLabel: messages.taskActionBarTrackTime,
              stopSemanticLabel: messages.taskActionBarStopTracking,
              onPressed: _onTrackTimePressed,
            ),
            _RoundActionButton(
              key: TaskActionBar.checklistKey,
              icon: Icons.checklist_rounded,
              semanticLabel: messages.addActionAddChecklist,
              onPressed: _onChecklistPressed,
            ),
            _RoundActionButton(
              key: TaskActionBar.imageKey,
              icon: Icons.image_rounded,
              semanticLabel: messages.addActionImportImage,
              onPressed: _onImagePressed,
            ),
            _RoundActionButton(
              key: TaskActionBar.audioKey,
              icon: Icons.mic_rounded,
              semanticLabel: messages.addActionAddAudioRecording,
              onPressed: _onAudioPressed,
            ),
            _RoundActionButton(
              key: TaskActionBar.moreKey,
              icon: Icons.more_horiz_rounded,
              semanticLabel: messages.taskActionBarMoreActions,
              onPressed: _onMorePressed,
            ),
            _RoundActionButton(
              key: TaskActionBar.screenshotKey,
              icon: Icons.screenshot_rounded,
              semanticLabel: messages.addActionAddScreenshot,
              onPressed: _onScreenshotPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary "Track time" pill. Idle: stopwatch icon + localized label,
/// tap starts a new timer. Recording-this-task: stop icon + live elapsed
/// duration, tap stops the timer.
class _TrackTimePill extends StatelessWidget {
  const _TrackTimePill({
    required this.isTracking,
    required this.label,
    required this.idleSemanticLabel,
    required this.stopSemanticLabel,
    required this.onPressed,
    super.key,
  });

  final bool isTracking;
  final String label;
  final String idleSemanticLabel;
  final String stopSemanticLabel;
  final VoidCallback onPressed;

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
    final iconColor = isTracking
        ? Colors.white
        : tokens.colors.text.highEmphasis;
    final textColor = iconColor;

    return Semantics(
      button: true,
      label: isTracking ? stopSemanticLabel : idleSemanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          onTap: onPressed,
          child: Container(
            height: TaskActionBar.buttonSize,
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTracking ? Icons.stop_rounded : Icons.timer_outlined,
                  size: TaskActionBar.iconSize,
                  color: iconColor,
                ),
                SizedBox(width: spacing.step2),
                Text(
                  label,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: textColor,
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

/// Circular icon-only action button — the round affordances after the
/// Track time pill.
class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

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
              color: tokens.colors.surface.hover,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: TaskActionBar.iconSize,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}
