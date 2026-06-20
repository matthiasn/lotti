import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/sidebar_live_card.dart';
import 'package:lotti/widgets/misc/timer_navigation.dart';

/// Inline timer panel rendered in the desktop sidebar's `aboveSettings`
/// slot whenever a time-recording session is active.
///
/// Tapping anywhere on the body navigates to the running task (or the
/// timer's journal entry, if not linked to a task). Tapping the stop
/// button stops the timer.
///
/// Visibility is a pure function of whether a timer is running: the card
/// stays mounted for the entire lifetime of a session and collapses only
/// when no timer is running. It is deliberately *not* suppressed when the
/// running task is open in the task-details pane, nor when the user
/// navigates to another tab. The running indicator in the task detail
/// action bar and this sidebar card may both be on screen at once — that
/// duplication is intentional. A single, always-present sidebar surface
/// guarantees the user never loses the elapsed-time readout or the
/// one-tap path back to the running task, no matter where they are in the
/// app.
///
/// Reactivity:
///
/// * [TimeService.getStream] drives running/duration updates and is the
///   sole input to visibility — appearance and disappearance follow the
///   timer starting and stopping, nothing else.
class SidebarTimerSection extends ConsumerWidget {
  const SidebarTimerSection({super.key});

  /// Duration used for both the fade and the surrounding collapse.
  /// Short enough to feel responsive, long enough to read as a
  /// transition rather than a flicker.
  @visibleForTesting
  static const Duration animationDuration = Duration(milliseconds: 220);

  /// Stable key for the collapsed (no running timer) state so the
  /// [AnimatedSwitcher] animates a single hidden ↔ visible transition.
  static const Key _hiddenKey = ValueKey('sidebar-timer-hidden');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeService = getIt<TimeService>();

    return StreamBuilder<JournalEntity?>(
      stream: timeService.getStream(),
      initialData: timeService.getCurrent(),
      builder: (context, snapshot) {
        final child = _resolveChild(
          ref: ref,
          timeService: timeService,
          current: snapshot.data,
        );
        return AnimatedSize(
          duration: animationDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: animationDuration,
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: child,
          ),
        );
      },
    );
  }

  Widget _resolveChild({
    required WidgetRef ref,
    required TimeService timeService,
    required JournalEntity? current,
  }) {
    if (current == null) {
      return const SizedBox.shrink(key: _hiddenKey);
    }
    final linkedFrom = timeService.linkedFrom;
    return _SidebarTimerCard(
      key: ValueKey('sidebar-timer-${current.meta.id}'),
      current: current,
      linkedFrom: linkedFrom,
      onStop: () => unawaited(timeService.stop()),
      onTapBody: () => navigateToTimerTarget(
        ref: ref,
        current: current,
        linkedFrom: linkedFrom,
      ),
    );
  }
}

class _SidebarTimerCard extends StatelessWidget {
  const _SidebarTimerCard({
    required this.current,
    required this.linkedFrom,
    required this.onStop,
    required this.onTapBody,
    super.key,
  });

  final JournalEntity current;
  final JournalEntity? linkedFrom;
  final VoidCallback onStop;
  final VoidCallback onTapBody;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final title = _resolveTitle(messages.taskUntitled);
    final durationText = formatDuration(entryDuration(current));

    // Teal "live" accent — the app's interactive accent identifies a running
    // timer (rail + glyph + prominent elapsed time) and separates it from the
    // red audio card so the two stop buttons can never be confused.
    return SidebarLiveCard(
      accent: tokens.colors.interactive.enabled,
      glyph: Icons.timer_outlined,
      title: title,
      timeText: durationText,
      onTap: onTapBody,
      semanticsLabel: messages.sidebarRunningTimerLabel,
      trailing: _StopTimerButton(onStop: onStop),
    );
  }

  String _resolveTitle(String fallback) {
    if (linkedFrom is Task) {
      final t = (linkedFrom! as Task).data.title.trim();
      if (t.isNotEmpty) return t;
    }
    final linkedText = linkedFrom?.entryText?.plainText.trim();
    if (linkedText != null && linkedText.isNotEmpty) return linkedText;
    final currentText = current.entryText?.plainText.trim();
    if (currentText != null && currentText.isNotEmpty) return currentText;
    return fallback;
  }
}

class _StopTimerButton extends StatelessWidget {
  const _StopTimerButton({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final tooltip = context.messages.sidebarRunningTimerStopTooltip;

    // Teal-tinted chip + teal glyph — same affordance pattern as the audio
    // recording's red stop, so the action language is consistent across the
    // live cards (only the accent differs). Red still stays exclusive to the
    // consequential recording stop.
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          color: accent.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onStop,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.stop_rounded, size: 16, color: accent),
            ),
          ),
        ),
      ),
    );
  }
}
