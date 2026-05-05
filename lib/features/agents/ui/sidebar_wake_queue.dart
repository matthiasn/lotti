import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
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
        // Tighter horizontal padding than the rest of the sidebar so the
        // wake row body gets all the available width back — the design
        // ask is that the title cell breathes and the ETA chip never
        // feels cramped against the cancel-x.
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

/// Compact ongoing-wake row: template name on the left, live wall-clock
/// duration on the right. Tapping the title opens the agent's
/// instance detail page so the user can drop straight into the
/// in-flight conversation.
class _OngoingWakeRow extends ConsumerStatefulWidget {
  const _OngoingWakeRow({required this.record});

  final OngoingWakeRecord record;

  @override
  ConsumerState<_OngoingWakeRow> createState() => _OngoingWakeRowState();
}

class _OngoingWakeRowState extends ConsumerState<_OngoingWakeRow> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = clock.now().difference(widget.record.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsed = clock.now().difference(widget.record.startedAt);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _OngoingWakeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.startedAt != widget.record.startedAt) {
      _elapsed = clock.now().difference(widget.record.startedAt);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    _navigateToAgentRoute(
      '/settings/agents/instances/${widget.record.agentId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step2,
          vertical: tokens.spacing.step1,
        ),
        child: Row(
          children: [
            // Pulsing-green dot to read as "this is alive right now".
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
                widget.record.title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(_formatElapsed(_elapsed), style: durationStyle),
          ],
        ),
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
  Timer? _timer;
  late int _remainingSeconds;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _remainingFromDueAt(widget.record.dueAt);
    _scheduleTick();
  }

  @override
  void didUpdateWidget(covariant _WakeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.dueAt != widget.record.dueAt) {
      _remainingSeconds = _remainingFromDueAt(widget.record.dueAt);
      _scheduleTick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleTick() {
    _timer?.cancel();
    if (_remainingSeconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _remainingFromDueAt(widget.record.dueAt);
      setState(() {
        _remainingSeconds = remaining;
        if (_remainingSeconds <= 0) timer.cancel();
      });
    });
  }

  int _remainingFromDueAt(DateTime dueAt) {
    final remaining = dueAt.difference(clock.now());
    return remaining <= Duration.zero ? 0 : remaining.inSeconds;
  }

  void _handleTap() {
    final agentId = widget.record.agent.agentId;
    _navigateToAgentRoute('/settings/agents/instances/$agentId');
  }

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
    // Prefer the linked task / project title — what the user
    // identifies the wake by — over the agent's display name. Falls
    // back to the agent display name when the agent has no linked
    // subject (e.g. an improver agent).
    final subjectId =
        record.state.slots.activeTaskId ?? record.state.slots.activeProjectId;
    final subjectTitle = ref
        .watch(pendingWakeTargetTitleProvider(subjectId))
        .value
        ?.trim();
    final title = subjectTitle != null && subjectTitle.isNotEmpty
        ? subjectTitle
        : record.agent.displayName;

    final eta = _formatEta(context, _remainingSeconds);
    final imminent = _remainingSeconds < 5 * 60;
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
              onTap: _handleTap,
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
        width: 24,
        height: 24,
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
        child: InkResponse(
          onTap: onPressed,
          radius: 12,
          child: SizedBox(
            width: 24,
            height: 24,
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

void _openWakesList() => _navigateToAgentRoute(kSidebarWakeQueueListRoute);

/// Navigate the user from anywhere in the app to a Settings sub-route
/// without breaking back history. See the comment kept on
/// `_navigateToAgentRoute` history for why we don't just call
/// `tapIndex` — Beamer back-history matters here.
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

/// Render a wall-clock duration since wake start. Mirrors the
/// pending-wake countdown shape so the two read symmetrically: under
/// an hour it's `mm:ss`, otherwise `Xh Ym`.
String _formatElapsed(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  if (totalSeconds < 60 * 60) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
