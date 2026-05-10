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
import 'package:lotti/ui/app_fonts.dart';

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

/// Quiet inline Wake Queue surfaced in the desktop sidebar's
/// `aboveSettings` slot. Renders:
///
/// 1. A `WAKES N ↗` header that links to the full Wake Cycles page.
/// 2. Up to N currently *running* agents, each with the live duration
///    since the wake started.
/// 3. Up to [kSidebarWakeQueueRowLimit] *scheduled* wakes that fall
///    within [kSidebarWakeQueueScheduledLookahead]; anything farther
///    out is hidden under the trailing `+N more →` link.
///
/// The link row is always visible — when the queue is empty it still
/// gives the user a one-tap path into the full list so the section
/// never feels "stuck".
class SidebarWakeQueue extends ConsumerWidget {
  const SidebarWakeQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wakesAsync = ref.watch(pendingWakeRecordsProvider);
    final ongoingAsync = ref.watch(ongoingWakeRecordsProvider);
    final allScheduled = wakesAsync.value ?? const <PendingWakeRecord>[];
    final ongoing = ongoingAsync.value ?? const <OngoingWakeRecord>[];
    final tokens = context.designTokens;

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

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        // Tighter horizontal padding than the rest of the sidebar so
        // the title cell can breathe past the avatar/cancel cluster.
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step1,
          tokens.spacing.step3,
          tokens.spacing.step1,
          tokens.spacing.step4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(count: totalCount),
            if (ongoing.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              for (final record in ongoing)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.step1),
                  child: _OngoingWakeRow(record: record),
                ),
            ],
            if (visibleScheduled.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              for (final record in visibleScheduled)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.step1),
                  child: _WakeRow(record: record),
                ),
            ],
          ],
        ),
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
    final labelStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: tokens.colors.text.lowEmphasis,
      letterSpacing: 1.2,
    );
    final countStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: count > 0
          ? tokens.colors.alert.warning.defaultColor
          : tokens.colors.text.lowEmphasis,
      letterSpacing: 0.4,
    ).copyWith(fontFeatures: numericBadgeFontFeatures);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: InkWell(
        onTap: _openWakesList,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
          child: Row(
            children: [
              Text(
                messages.sidebarWakesHeader.toUpperCase(),
                style: labelStyle,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text('$count', style: countStyle),
              const Spacer(),
              Tooltip(
                message: messages.sidebarWakesOpenList,
                child: Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
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
    final accent = tokens.colors.alert.success.defaultColor;
    final titleStyle = AppFonts.inconsolata(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: tokens.colors.text.mediumEmphasis,
    );
    final durationStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: accent,
    ).copyWith(fontFeatures: numericBadgeFontFeatures);

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

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _navigateToAgentRoute(
              agentInstanceRoute(record.agentId),
            ),
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step2,
                vertical: tokens.spacing.step1,
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Expanded(
                    child: Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Text(elapsed, style: durationStyle),
                ],
              ),
            ),
          ),
        ),
        _CancelWakeButton(onPressed: _abortWake, cancelling: _cancelling),
      ],
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
    final subjectId =
        record.state.slots.activeTaskId ?? record.state.slots.activeProjectId;
    final subjectTitle = ref
        .watch(pendingWakeTargetTitleProvider(subjectId))
        .value
        ?.trim();
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
    final etaColor = imminent
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.text.lowEmphasis;

    final titleStyle = AppFonts.inconsolata(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: tokens.colors.text.mediumEmphasis,
    );
    final etaStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: etaColor,
    ).copyWith(fontFeatures: numericBadgeFontFeatures);

    return Row(
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
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Text(eta, style: etaStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
        _CancelWakeButton(onPressed: _cancelWake, cancelling: _cancelling),
      ],
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
