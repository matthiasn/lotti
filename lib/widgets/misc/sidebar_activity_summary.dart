import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/widgets/misc/sidebar_audio_recording_section.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';

/// Stable keys for the compact desktop activity summary.
@visibleForTesting
abstract final class SidebarActivitySummaryKeys {
  static const Key root = Key('sidebar-activity-summary');
  static const Key audio = Key('sidebar-activity-audio');
  static const Key timer = Key('sidebar-activity-timer');
  static const Key agents = Key('sidebar-activity-agents');
  static const Key dialog = Key('sidebar-activity-dialog');
}

/// Consolidates every transient desktop-sidebar status into one compact row.
///
/// Recording, timer, and agent details remain available in a single dialog,
/// while the persistent sidebar pays only for one summary surface. The global
/// bottom action bar remains the primary direct-control surface for recording
/// and time tracking.
class SidebarActivitySummary extends ConsumerWidget {
  const SidebarActivitySummary({
    required this.showAudio,
    required this.showWakeQueue,
    super.key,
  });

  final bool showAudio;
  final bool showWakeQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.watch(audioRecorderControllerProvider);
    final audioVisible =
        showAudio && sidebarAudioRecordingHasVisibleContent(ref);
    final agentCounts = showWakeQueue ? _agentCounts(ref) : null;
    final timeService = getIt<TimeService>();

    return StreamBuilder<JournalEntity?>(
      stream: timeService.getStream(),
      initialData: timeService.getCurrent(),
      builder: (context, snapshot) {
        final timer = snapshot.data;
        final agentsVisible = agentCounts != null && agentCounts.total > 0;
        if (!audioVisible && timer == null && !agentsVisible) {
          return const SizedBox.shrink();
        }

        final metrics = <_ActivityMetric>[
          if (audioVisible)
            _ActivityMetric(
              key: SidebarActivitySummaryKeys.audio,
              icon: Icons.mic_rounded,
              value: compactSidebarActivityDuration(recorder.progress),
              tooltip: context.messages.taskActionBarAudioRecordingActive,
              color: context.designTokens.colors.alert.error.defaultColor,
            ),
          if (timer != null)
            _ActivityMetric(
              key: SidebarActivitySummaryKeys.timer,
              icon: Icons.timer_outlined,
              value: compactSidebarActivityDuration(entryDuration(timer)),
              tooltip: context.messages.sidebarRunningTimerLabel,
              color: context.designTokens.colors.interactive.enabled,
            ),
          if (agentsVisible)
            _ActivityMetric(
              key: SidebarActivitySummaryKeys.agents,
              icon: Icons.auto_awesome_rounded,
              value: '${agentCounts.total}',
              tooltip: context.messages.sidebarWakesHeader,
              color: context.designTokens.colors.text.mediumEmphasis,
            ),
        ];

        return _ActivitySurface(
          metrics: metrics,
          semanticsLabel: _semanticsLabel(
            context,
            audioDuration: audioVisible ? recorder.progress : null,
            timerDuration: timer == null ? null : entryDuration(timer),
            agentCounts: agentsVisible ? agentCounts : null,
          ),
          liveRegion: audioVisible,
          onTap: () => _showDetails(context),
        );
      },
    );
  }

  _AgentCounts _agentCounts(WidgetRef ref) {
    final scheduled =
        ref.watch(pendingWakeRecordsProvider).value ??
        const <PendingWakeRecord>[];
    final ongoing =
        ref.watch(ongoingWakeRecordsProvider).value ??
        const <OngoingWakeRecord>[];
    final cutoff = clock.now().add(kSidebarWakeQueueScheduledLookahead);
    final queued = scheduled
        .where((wake) => !wake.dueAt.isAfter(cutoff))
        .length;
    return _AgentCounts(active: ongoing.length, queued: queued);
  }

  String _semanticsLabel(
    BuildContext context, {
    required Duration? audioDuration,
    required Duration? timerDuration,
    required _AgentCounts? agentCounts,
  }) {
    final messages = context.messages;
    return [
      messages.sidebarActiveSectionTitle,
      if (audioDuration != null)
        '${messages.taskActionBarAudioRecordingActive} ${formatDuration(audioDuration)}',
      if (timerDuration != null)
        '${messages.sidebarRunningTimerLabel} ${formatDuration(timerDuration)}',
      if (agentCounts != null && agentCounts.active > 0)
        messages.sidebarWakesActiveCount(agentCounts.active),
      if (agentCounts != null && agentCounts.queued > 0)
        messages.sidebarWakesQueuedCount(agentCounts.queued),
    ].join(', ');
  }

  Future<void> _showDetails(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final tokens = dialogContext.designTokens;
        return AlertDialog(
          key: SidebarActivitySummaryKeys.dialog,
          title: Text(dialogContext.messages.sidebarActiveSectionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showAudio) const SidebarAudioRecordingSection(),
                if (showAudio) SizedBox(height: tokens.spacing.step4),
                const SidebarTimerSection(),
                if (showWakeQueue) ...[
                  SizedBox(height: tokens.spacing.step4),
                  const SidebarWakeQueue(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shortens sub-hour durations to `mm:ss`; longer sessions retain hours.
@visibleForTesting
String compactSidebarActivityDuration(Duration duration) {
  final formatted = formatDuration(duration);
  return formatted.startsWith('00:') ? formatted.substring(3) : formatted;
}

class _ActivitySurface extends StatelessWidget {
  const _ActivitySurface({
    required this.metrics,
    required this.semanticsLabel,
    required this.liveRegion,
    required this.onTap,
  });

  final List<_ActivityMetric> metrics;
  final String semanticsLabel;
  final bool liveRegion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    return Semantics(
      button: true,
      liveRegion: liveRegion,
      label: semanticsLabel,
      child: Material(
        key: SidebarActivitySummaryKeys.root,
        color: tokens.colors.surface.enabled,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: tokens.colors.surface.hover,
          focusColor: tokens.colors.surface.focusPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: largeText
                ? Wrap(
                    spacing: tokens.spacing.step4,
                    runSpacing: tokens.spacing.step2,
                    children: [
                      for (final metric in metrics)
                        ExcludeSemantics(child: metric),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.messages.sidebarActiveSectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                                fontWeight: tokens.typography.weight.semiBold,
                              ),
                        ),
                      ),
                      for (var index = 0; index < metrics.length; index++) ...[
                        if (index > 0)
                          SizedBox(
                            height: tokens.spacing.step5,
                            child: VerticalDivider(
                              width: tokens.spacing.step4,
                              color: tokens.colors.decorative.level01,
                            ),
                          ),
                        ExcludeSemantics(child: metrics[index]),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.icon,
    required this.value,
    required this.tooltip,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String value;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: tokens.spacing.step5, color: color),
          SizedBox(width: tokens.spacing.step2),
          Text(
            value,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontFeatures: numericBadgeFontFeatures,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCounts {
  const _AgentCounts({required this.active, required this.queued});

  final int active;
  final int queued;

  int get total => active + queued;
}
