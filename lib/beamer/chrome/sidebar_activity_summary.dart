import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/chrome/sidebar_audio_recording_section.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/entry_tools.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the compact desktop activity disclosure.
@visibleForTesting
abstract final class SidebarActivitySummaryKeys {
  static const Key root = Key('sidebar-activity-summary');
  static const Key header = Key('sidebar-activity-header');
  static const Key audio = Key('sidebar-activity-audio');
  static const Key timer = Key('sidebar-activity-timer');
  static const Key agents = Key('sidebar-activity-agents');
  static const Key details = Key('sidebar-activity-details');
}

/// Consolidates every transient desktop-sidebar status into one disclosure.
///
/// The collapsed row preserves the low idle footprint: a heading over one
/// compact metric per activity. Expanding it in place restores the full
/// recording, timer, and agent context plus direct controls without moving the
/// user into a modal surface. The summary paints no fill or frame of its own;
/// expanded, its heading drops the compact metrics, because each detail card
/// already shows its own elapsed time or count.
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
    final timeService = ref.read(timeServiceProvider);

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
              icon: LottiIcons.mic,
              value: compactSidebarActivityDuration(recorder.progress),
              tooltip: context.messages.taskActionBarAudioRecordingActive,
              color: context.designTokens.colors.alert.error.defaultColor,
            ),
          if (timer != null)
            _ActivityMetric(
              key: SidebarActivitySummaryKeys.timer,
              icon: LottiIcons.timer,
              value: compactSidebarActivityDuration(entryDuration(timer)),
              tooltip: context.messages.sidebarRunningTimerLabel,
              color: context.designTokens.colors.interactive.enabled,
            ),
          if (agentsVisible)
            _ActivityMetric(
              key: SidebarActivitySummaryKeys.agents,
              icon: LottiIcons.aiSpark,
              value: '${agentCounts.total}',
              tooltip: context.messages.sidebarWakesHeader,
              color: context.designTokens.colors.text.mediumEmphasis,
            ),
        ];

        return _ActivitySurface(
          metrics: metrics,
          // Expanded, the detail cards announce their own values; the header
          // then names only the section so nothing is read out twice.
          semanticsLabel: _expanded
              ? context.messages.sidebarActiveSectionTitle
              : _semanticsLabel(
                  context,
                  audioDuration: audioVisible ? recorder.progress : null,
                  timerDuration: timer == null ? null : entryDuration(timer),
                  agentCounts: agentsVisible ? agentCounts : null,
                ),
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
    final now = scheduled.isEmpty
        ? clock.now()
        : ref.watch(wakeCountdownTickerProvider).value ?? clock.now();
    final cutoff = now.add(kSidebarWakeQueueScheduledLookahead);
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
    required this.expanded,
    required this.details,
    required this.onTap,
  });

  final List<_ActivityMetric> metrics;
  final String semanticsLabel;
  final bool expanded;
  final Widget details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);

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

    // No fill and no frame: the heading sits directly on the sidebar like the
    // navigation rows, and once expanded the detail cards below it carry their
    // own single surface.
    return Material(
      key: SidebarActivitySummaryKeys.root,
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            liveRegion: false,
            label: '$semanticsLabel, $toggleTooltip',
            child: InkWell(
              key: SidebarActivitySummaryKeys.header,
              onTap: onTap,
              borderRadius: radius,
              hoverColor: tokens.colors.surface.hover,
              focusColor: tokens.colors.surface.focusPressed,
              child: Padding(
                // Expanded, the heading reads as a label for the cards
                // directly beneath it, so it keeps only a slim gap below.
                padding: EdgeInsets.only(
                  left: tokens.spacing.step4,
                  right: tokens.spacing.step4,
                  top: tokens.spacing.step3,
                  bottom: expanded
                      ? tokens.spacing.step2
                      : tokens.spacing.step3,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: label),
                        SizedBox(width: tokens.spacing.step3),
                        Tooltip(
                          message: toggleTooltip,
                          child: ExcludeSemantics(
                            child: Icon(
                              expanded
                                  ? LottiIcons.expand
                                  : LottiIcons.chevronRight,
                              size: tokens.spacing.step5,
                              color: tokens.colors.text.mediumEmphasis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // The compact metrics summarise what the detail cards
                    // show in full, so they step aside while expanded and
                    // each elapsed time and the agent count appear once.
                    AnimatedSize(
                      duration: SidebarWakeQueue.animationDuration,
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: expanded
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: EdgeInsets.only(
                                top: tokens.spacing.step2,
                              ),
                              child: Wrap(
                                spacing: tokens.spacing.step4,
                                runSpacing: tokens.spacing.step2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  for (final metric in metrics)
                                    ExcludeSemantics(child: metric),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: SidebarWakeQueue.animationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? KeyedSubtree(
                    key: SidebarActivitySummaryKeys.details,
                    child: details,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
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
