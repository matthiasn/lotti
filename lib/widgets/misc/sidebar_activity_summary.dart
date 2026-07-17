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

/// Stable keys for the compact desktop activity disclosure.
@visibleForTesting
abstract final class SidebarActivitySummaryKeys {
  static const Key root = Key('sidebar-activity-summary');
  static const Key audio = Key('sidebar-activity-audio');
  static const Key timer = Key('sidebar-activity-timer');
  static const Key agents = Key('sidebar-activity-agents');
  static const Key details = Key('sidebar-activity-details');
}

/// Consolidates every transient desktop-sidebar status into one disclosure.
///
/// The collapsed row preserves the low idle footprint. Expanding it in place
/// restores the full recording, timer, and agent context plus direct controls
/// without moving the user into a modal surface.
class SidebarActivitySummary extends ConsumerStatefulWidget {
  const SidebarActivitySummary({required this.showAudio, super.key});

  final bool showAudio;

  @override
  ConsumerState<SidebarActivitySummary> createState() =>
      _SidebarActivitySummaryState();
}

class _SidebarActivitySummaryState
    extends ConsumerState<SidebarActivitySummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(audioRecorderControllerProvider);
    final audioVisible =
        widget.showAudio && sidebarAudioRecordingHasVisibleContent(ref);
    final agentCounts = _agentCounts();
    final timeService = getIt<TimeService>();

    return StreamBuilder<JournalEntity?>(
      stream: timeService.getStream(),
      initialData: timeService.getCurrent(),
      builder: (context, snapshot) {
        final timer = snapshot.data;
        final agentsVisible = agentCounts.total > 0;
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
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
          details: _ActivityDetails(
            showAudio: audioVisible,
            showTimer: timer != null,
            showWakeQueue: agentsVisible,
          ),
        );
      },
    );
  }

  _AgentCounts _agentCounts() {
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
    required this.expanded,
    required this.details,
    required this.onTap,
  });

  final List<_ActivityMetric> metrics;
  final String semanticsLabel;
  final bool liveRegion;
  final bool expanded;
  final Widget details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    final label = Text(
      context.messages.sidebarActiveSectionTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
        fontWeight: tokens.typography.weight.semiBold,
      ),
    );
    final toggleTooltip = expanded
        ? context.messages.sidebarActivityCollapseTooltip
        : context.messages.sidebarActivityExpandTooltip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          liveRegion: liveRegion,
          label: '$semanticsLabel, $toggleTooltip',
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minTarget),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step4,
                    vertical: tokens.spacing.step3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: largeText
                            ? Wrap(
                                spacing: tokens.spacing.step4,
                                runSpacing: tokens.spacing.step2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  label,
                                  for (final metric in metrics)
                                    ExcludeSemantics(child: metric),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: label),
                                  for (
                                    var index = 0;
                                    index < metrics.length;
                                    index++
                                  ) ...[
                                    if (index > 0)
                                      SizedBox(
                                        height: tokens.spacing.step5,
                                        child: VerticalDivider(
                                          width: tokens.spacing.step4,
                                          color:
                                              tokens.colors.decorative.level01,
                                        ),
                                      ),
                                    ExcludeSemantics(child: metrics[index]),
                                  ],
                                ],
                              ),
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Tooltip(
                        message: toggleTooltip,
                        child: ExcludeSemantics(
                          child: Icon(
                            expanded
                                ? Icons.expand_more_rounded
                                : Icons.chevron_right_rounded,
                            size: tokens.spacing.step5,
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: SidebarWakeQueue.animationDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  key: SidebarActivitySummaryKeys.details,
                  padding: EdgeInsets.only(top: tokens.spacing.step3),
                  child: details,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ActivityDetails extends StatelessWidget {
  const _ActivityDetails({
    required this.showAudio,
    required this.showTimer,
    required this.showWakeQueue,
  });

  final bool showAudio;
  final bool showTimer;
  final bool showWakeQueue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final sections = <Widget>[
      if (showAudio) const SidebarAudioRecordingSection(),
      if (showTimer) const SidebarTimerSection(),
      if (showWakeQueue) const SidebarWakeQueue(),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) SizedBox(height: tokens.spacing.step3),
          sections[index],
        ],
      ],
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
