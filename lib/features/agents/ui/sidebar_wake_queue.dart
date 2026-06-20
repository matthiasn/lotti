import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

/// Settings sub-route that opens the full Wake Cycles list.
const String kSidebarWakeQueueListRoute = '/settings/agents/pending-wakes';

/// How many *scheduled* wake rows the inline sidebar block renders
/// before collapsing the remainder into the `+N more →` affordance.
/// Ongoing wakes are always shown in full (typically 0–1 at a time)
/// because hiding an actively running agent behind a "more" link is
/// confusing.
const int kSidebarWakeQueueRowLimit = 3;

/// Maximum lookahead for scheduled wakes shown inline. Anything beyond
/// this window still surfaces via the trailing "+N more →" affordance
/// and the full Wake Cycles page, but does not clutter the
/// always-visible sidebar block.
const Duration kSidebarWakeQueueScheduledLookahead = Duration(hours: 1);

/// Test hook that lets widget tests intercept the navigation calls the
/// block triggers without standing up the global `NavService` and beamer
/// stack. Setting to `null` restores the production navigation path.
@visibleForTesting
abstract final class SidebarWakeQueueTestHooks {
  static void Function(String path)? navigatorOverride;
}

/// Whether [SidebarWakeQueue] would render a non-empty card given the
/// current snapshot of the pending- and ongoing-wake providers. The
/// composer above the sidebar uses this to decide whether to insert a
/// spacer between the wake card and the running-timer card — neither
/// widget should leave a phantom gap when its data is empty.
bool sidebarWakeQueueHasVisibleContent(WidgetRef ref) {
  final wakes =
      ref.watch(pendingWakeRecordsProvider).value ??
      const <PendingWakeRecord>[];
  final ongoing =
      ref.watch(ongoingWakeRecordsProvider).value ??
      const <OngoingWakeRecord>[];
  if (ongoing.isNotEmpty) return true;
  final cutoff = clock.now().add(kSidebarWakeQueueScheduledLookahead);
  return wakes.any((r) => !r.dueAt.isAfter(cutoff));
}

/// Quiet inline Wake Queue surfaced in the desktop sidebar's
/// `aboveSettings` slot. When at least one wake is active it renders:
///
/// 1. A `WAKES N ↗` header that links to the full Wake Cycles page.
/// 2. Up to N currently *running* agents, each with the live duration
///    since the wake started.
/// 3. Up to [kSidebarWakeQueueRowLimit] *scheduled* wakes that fall
///    within [kSidebarWakeQueueScheduledLookahead]; anything farther
///    out is intentionally invisible from the sidebar — the header
///    link icon is the only path into the full Wake Cycles page.
///
/// When the pre-resolve / zero-wake state holds, `build` returns
/// [SizedBox.shrink] so the card is hidden entirely rather than
/// presenting an empty header above the running-timer card.
class SidebarWakeQueue extends ConsumerWidget {
  const SidebarWakeQueue({super.key});

  /// Matches `SidebarTimerSection.animationDuration` so the wake card and
  /// the running-timer card share one rhythm when they appear or collapse
  /// in the sidebar's `aboveSettings` slot.
  static const Duration animationDuration = Duration(milliseconds: 220);

  /// Stable key used by the hidden state so [AnimatedSwitcher] cross-fades
  /// once between visible↔hidden rather than every time the content set
  /// changes.
  static const Key _hiddenKey = ValueKey('sidebar-wakes-hidden');
  static const Key _visibleKey = ValueKey('sidebar-wakes-visible');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wakesAsync = ref.watch(pendingWakeRecordsProvider);
    final ongoingAsync = ref.watch(ongoingWakeRecordsProvider);
    final allScheduled = wakesAsync.value ?? const <PendingWakeRecord>[];
    final ongoing = ongoingAsync.value ?? const <OngoingWakeRecord>[];

    final now = clock.now();
    final cutoff = now.add(kSidebarWakeQueueScheduledLookahead);
    final inWindow = allScheduled
        .where((r) => !r.dueAt.isAfter(cutoff))
        .toList();
    final visibleScheduled = inWindow.take(kSidebarWakeQueueRowLimit).toList();

    // Only "imminent" wakes count for the header badge — wakes scheduled
    // past the lookahead window are intentionally invisible from the
    // sidebar; the header link icon is the path to the full list.
    final totalCount = ongoing.length + inWindow.length;

    final tokens = context.designTokens;
    final child = totalCount == 0
        ? const SizedBox.shrink(key: _hiddenKey)
        : Material(
            key: _visibleKey,
            // Quiet neutral card — agents are background/scheduled work, so
            // this sits a tier below the accent-tinted live timer/recording
            // cards (no accent rail or tint). Rows carry their own horizontal
            // padding so the leading dot aligns to the live cards' glyph
            // column and the nav rows above.
            color: tokens.colors.surface.enabled,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(count: totalCount),
                  if (ongoing.isNotEmpty)
                    for (final record in ongoing)
                      _OngoingWakeRow(record: record),
                  if (visibleScheduled.isNotEmpty)
                    for (final record in visibleScheduled)
                      _WakeRow(record: record),
                ],
              ),
            ),
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
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Sentence-case caption in the app's voice — a quiet low-emphasis tier-2
    // sublabel that sits clearly below the high-emphasis live rows above and
    // the medium-emphasis wake titles below, not a wide-tracked console
    // header. The count rides the same style so it reads as one calm
    // "Wakes N" cluster.
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final countStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

    return InkWell(
      onTap: _openWakesList,
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step2,
        ),
        child: Row(
          children: [
            Text(messages.sidebarWakesHeader, style: labelStyle),
            SizedBox(width: tokens.spacing.step2),
            Text('$count', style: countStyle),
            const Spacer(),
            Tooltip(
              message: messages.sidebarWakesOpenList,
              child: Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live wall-clock duration since wake start, paired with the linked
/// task / project title. Driven by the page-scoped 1Hz
/// [wakeCountdownTickerProvider] — one timer feeds every row across
/// the app, so the sidebar's ongoing block doesn't allocate its own.
///
/// The trailing cancel button signals the orchestrator's abort hook so a
/// stuck wake cycle can be unstuck without restarting the app. The runner
/// observes the abort, marks the wake-run row as `aborted`, and releases
/// the lock; the underlying executor future is left to settle on its own.
class _OngoingWakeRow extends ConsumerStatefulWidget {
  const _OngoingWakeRow({required this.record});

  final OngoingWakeRecord record;

  @override
  ConsumerState<_OngoingWakeRow> createState() => _OngoingWakeRowState();
}

class _OngoingWakeRowState extends ConsumerState<_OngoingWakeRow> {
  bool _cancelling = false;

  Future<void> _abortWake() async {
    if (_cancelling) return;
    // `abortRunningWake` is synchronous, so a finally that resets
    // `_cancelling` would clear the spinner state in the same stack frame —
    // the user would never see the indicator and the early-return guard
    // above would not actually persist across rapid double taps. Once the
    // abort signal is delivered, the orchestrator releases the runner lock
    // and the row falls out of `ongoingWakeRecordsProvider`, which tears
    // this widget down. While that's in flight we keep `_cancelling` set
    // so the trailing × is replaced by the in-progress spinner.
    final didSignal = ref
        .read(agentServiceProvider)
        .abortRunningWake(widget.record.agentId);
    if (mounted && didSignal) {
      setState(() => _cancelling = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final record = widget.record;
    // Green dot = "running now"; the elapsed clock itself stays neutral so
    // it reads as data, not a second green signal.
    final accent = tokens.colors.alert.success.defaultColor;
    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final durationStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

    final elapsed = ref.watch(
      wakeCountdownTickerProvider.select((async) {
        final now = async.value ?? clock.now();
        return formatWakeElapsed(now.difference(record.startedAt));
      }),
    );

    // Live title: re-watch the linked task/project title so a rename
    // refreshes the row without waiting for the agent to stop and
    // restart. Falls back to the snapshot title on the record (which
    // already encodes the agent.displayName / agentId fallback) when
    // the provider has no usable title.
    final liveSubjectTitle = record.subjectId == null
        ? null
        : ref
              .watch(pendingWakeTargetTitleProvider(record.subjectId))
              .value
              ?.trim();
    final title = liveSubjectTitle != null && liveSubjectTitle.isNotEmpty
        ? liveSubjectTitle
        : record.title;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _navigateToAgentRoute(
                agentInstanceRoute(record.agentId),
              ),
              borderRadius: BorderRadius.circular(tokens.radii.xs),
              child: Row(
                children: [
                  // 20px leading slot so the dot aligns to the same icon
                  // column as the nav and the timer/audio glyphs.
                  SizedBox(
                    width: 20,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  Expanded(
                    child: Tooltip(
                      message: title,
                      child: Text(
                        title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Text(elapsed, style: durationStyle),
                ],
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          _CancelWakeButton(onPressed: _abortWake, cancelling: _cancelling),
        ],
      ),
    );
  }
}

class _WakeRow extends ConsumerStatefulWidget {
  const _WakeRow({required this.record});

  final PendingWakeRecord record;

  @override
  ConsumerState<_WakeRow> createState() => _WakeRowState();
}

class _WakeRowState extends ConsumerState<_WakeRow> {
  bool _cancelling = false;

  Future<void> _cancelWake() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final service = ref.read(agentServiceProvider);
    try {
      switch (widget.record.type) {
        case PendingWakeType.pending:
          service.cancelPendingWake(widget.record.agent.agentId);
        case PendingWakeType.scheduled:
          await service.clearScheduledWake(widget.record.agent.agentId);
      }
    } catch (_) {
      // Service swallows; the provider refresh reflects whatever the
      // cancellation actually did.
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final record = widget.record;

    // Try task first, then project — `??` would short-circuit on the
    // task ID even when the task's title is blank, which is exactly the
    // case that surfaced "Task Agent" instead of the project name on
    // the scheduled (120 s countdown) row. The ongoing-wake row was
    // already fixed via `_resolveOngoingRecord`; this is the matching
    // fix for the pending-wake row.
    final taskId = record.state.slots.activeTaskId;
    final projectId = record.state.slots.activeProjectId;
    String? subjectTitle;
    if (taskId != null && taskId.isNotEmpty) {
      subjectTitle = ref
          .watch(pendingWakeTargetTitleProvider(taskId))
          .value
          ?.trim();
    }
    if ((subjectTitle == null || subjectTitle.isEmpty) &&
        projectId != null &&
        projectId.isNotEmpty) {
      subjectTitle = ref
          .watch(pendingWakeTargetTitleProvider(projectId))
          .value
          ?.trim();
    }
    final title = subjectTitle != null && subjectTitle.isNotEmpty
        ? subjectTitle
        : record.agent.displayName;

    final remainingSeconds = ref.watch(
      wakeCountdownTickerProvider.select((async) {
        final now = async.value ?? clock.now();
        final diff = record.dueAt.difference(now);
        return diff <= Duration.zero ? 0 : diff.inSeconds;
      }),
    );
    final eta = _formatEta(context, remainingSeconds);
    final imminent = remainingSeconds < 5 * 60;
    // Amber only when the wake is imminent (<5 min) — otherwise the ETA is
    // quiet, low-emphasis data, not a standing alert.
    final etaColor = imminent
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.text.lowEmphasis;

    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final etaStyle = tokens.typography.styles.others.caption.copyWith(
      color: etaColor,
      fontFeatures: numericBadgeFontFeatures,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '$title · $eta',
              child: InkWell(
                onTap: () => _navigateToAgentRoute(
                  agentInstanceRoute(record.agent.agentId),
                ),
                borderRadius: BorderRadius.circular(tokens.radii.xs),
                child: Row(
                  children: [
                    // Neutral dot in the shared 20px icon column — marks a
                    // scheduled (not-yet-running) wake, vs the green dot the
                    // ongoing row uses.
                    SizedBox(
                      width: 20,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tokens.colors.text.lowEmphasis,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step4),
                    Expanded(
                      child: Tooltip(
                        message: title,
                        child: Text(
                          title,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Text(eta, style: etaStyle),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          _CancelWakeButton(onPressed: _cancelWake, cancelling: _cancelling),
        ],
      ),
    );
  }
}

/// Compact 18 px trailing × button that cancels the row's pending wake.
class _CancelWakeButton extends StatelessWidget {
  const _CancelWakeButton({
    required this.onPressed,
    required this.cancelling,
  });

  final Future<void> Function() onPressed;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tooltip = context.messages.sidebarWakesCancelTooltip;
    if (cancelling) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        // The visible × stays small (12 px) so the row reads as a
        // tight cluster, but the InkResponse keeps a 28 px hit target
        // for touch accessibility.
        child: InkResponse(
          onTap: onPressed,
          radius: 14,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.close_rounded,
              size: 12,
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings sub-route for a single agent's instance detail page.
String agentInstanceRoute(String agentId) =>
    '/settings/agents/instances/$agentId';

void _openWakesList() => _navigateToAgentRoute(kSidebarWakeQueueListRoute);

/// Navigate from anywhere to a Settings sub-route while preserving the
/// in-tab Beamer history: switch to the Settings tab via `setIndex`
/// (not `tapIndex`, which re-roots the delegate when re-entering the
/// same tab), beam the Settings delegate, and persist the route so
/// reload returns the user to the same page.
void _navigateToAgentRoute(String route) {
  final override = SidebarWakeQueueTestHooks.navigatorOverride;
  if (override != null) {
    override(route);
    return;
  }
  final navService = getIt<NavService>();
  if (navService.index != navService.settingsIndex) {
    navService.setIndex(navService.settingsIndex);
  }
  navService.settingsDelegate.beamToNamed(route);
  unawaited(navService.persistNamedRoute(route));
}

/// Compact ETA: `now` when ≤ 0, `mm:ss` under an hour, `Xh Ym` otherwise.
String _formatEta(BuildContext context, int seconds) {
  if (seconds <= 0) return context.messages.sidebarWakesNow;
  if (seconds < 60 * 60) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
