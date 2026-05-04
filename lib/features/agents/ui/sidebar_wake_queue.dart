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

/// Settings sub-route that opens the full Pending Wakes list.
const String kSidebarWakeQueueListRoute = '/settings/agents/pending-wakes';

/// How many wake rows the inline sidebar block renders before collapsing
/// the remainder into the `+N more →` affordance. Matches the design
/// handoff (`design_handoff_sidebar_wake_queue/README.md`, S1 variant).
const int kSidebarWakeQueueRowLimit = 2;

/// Test hook that lets widget tests intercept the navigation calls the
/// block triggers without standing up the global `NavService` and beamer
/// stack. Setting to `null` restores the production navigation path.
@visibleForTesting
abstract final class SidebarWakeQueueTestHooks {
  static void Function(String path)? navigatorOverride;
}

/// Quiet inline Wake Queue surfaced in the desktop sidebar's
/// `aboveSettings` slot. Renders a `WAKES N` header, up to
/// [kSidebarWakeQueueRowLimit] upcoming rows, and a `+N more →` link to
/// the full Pending Wakes view.
///
/// When the queue is empty the per-row list collapses but the header
/// (`WAKES 0`) and the link to the full Pending Wakes view stay visible
/// — matches the design handoff note "no layout shift when it's empty,
/// just hide rows, keep header collapsed". This also makes the visible
/// affordance survive the gating config flag: as soon as a user enables
/// `showSidebarWakeQueueFlag`, they get a confirmation that the section
/// mounted, even if no wakes are currently pending.
class SidebarWakeQueue extends ConsumerWidget {
  const SidebarWakeQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wakesAsync = ref.watch(pendingWakeRecordsProvider);
    final records = wakesAsync.value ?? const <PendingWakeRecord>[];
    final tokens = context.designTokens;
    final upcoming = records.take(kSidebarWakeQueueRowLimit).toList();
    final moreCount = records.length - upcoming.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: tokens.colors.decorative.level01,
          ),
        ),
      ),
      child: Padding(
        // Reserve breathing room below the last row so the block does
        // not crowd the Settings nav tile that sits immediately under
        // the `aboveSettings` slot. The sidebar itself adds an 8 px
        // gap between the slot and Settings; this 12 px bottom pad
        // makes the visual separation read as intentional rather than
        // accidental.
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step2,
          tokens.spacing.step3,
          tokens.spacing.step2,
          tokens.spacing.step4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(count: records.length),
            if (upcoming.isNotEmpty) SizedBox(height: tokens.spacing.step2),
            for (final record in upcoming)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step1),
                child: _WakeRow(record: record),
              ),
            // The link is always visible (not just when there are hidden
            // rows) — when the queue is empty it still gives the user a
            // way into the full Pending Wakes page so the section never
            // feels "stuck".
            _MoreLink(hiddenCount: moreCount),
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
    final labelStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: tokens.colors.text.lowEmphasis,
      letterSpacing: 1.2,
    );
    final countStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: tokens.colors.alert.warning.defaultColor,
      letterSpacing: 0.4,
    ).copyWith(fontFeatures: numericBadgeFontFeatures);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: Row(
        children: [
          Text(
            context.messages.sidebarWakesHeader.toUpperCase(),
            style: labelStyle,
          ),
          SizedBox(width: tokens.spacing.step2),
          Text('$count', style: countStyle),
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
    if (_remainingSeconds <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _remainingFromDueAt(widget.record.dueAt);
      setState(() {
        _remainingSeconds = remaining;
        if (_remainingSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  int _remainingFromDueAt(DateTime dueAt) {
    final remaining = dueAt.difference(clock.now());
    if (remaining <= Duration.zero) {
      return 0;
    }
    return remaining.inSeconds;
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
      // The agent service swallows errors elsewhere; the provider
      // refresh will reflect whatever the cancellation actually did.
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final record = widget.record;
    final eta = _formatEta(context, _remainingSeconds);
    final imminent = _remainingSeconds < 5 * 60;
    final etaColor = imminent
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.text.lowEmphasis;

    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final etaStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: etaColor,
    ).copyWith(fontFeatures: numericBadgeFontFeatures);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '${record.agent.displayName} · $eta',
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(tokens.radii.xs),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.step1,
                  ),
                  child: Row(
                    children: [
                      _AgentAvatar(displayName: record.agent.displayName),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: Text(
                          record.agent.displayName,
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
          _CancelWakeButton(
            onPressed: _cancelWake,
            cancelling: _cancelling,
          ),
        ],
      ),
    );
  }
}

/// Compact 18 px trailing × button that cancels the row's pending wake.
/// Sized small enough to live in the sidebar's narrow column without
/// crowding the avatar / title / ETA, with a 28 px circular hit target
/// so taps stay reliable on touch input.
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
        child: InkResponse(
          onTap: onPressed,
          radius: 14,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreLink extends StatelessWidget {
  const _MoreLink({required this.hiddenCount});

  /// How many wake records are present in the queue beyond the rendered
  /// rows. When zero the link still renders, just with a different
  /// label so the user always has a way into the full list.
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = AppFonts.inconsolata(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: tokens.colors.text.lowEmphasis,
    );
    final label = hiddenCount > 0
        ? context.messages.sidebarWakesMore(hiddenCount)
        : context.messages.sidebarWakesOpenList;

    return InkWell(
      onTap: _openWakesList,
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step2,
          vertical: tokens.spacing.step1,
        ),
        child: Text(label, style: style),
      ),
    );
  }

  void _openWakesList() => _navigateToAgentRoute(kSidebarWakeQueueListRoute);
}

/// Navigate the user from anywhere in the app to a Settings sub-route
/// without breaking back history. Three behaviours, picked so the agent
/// detail page's `Beamer.back()` always lands on the correct prior page:
///
/// 1. If a test override is registered, just call it and return.
/// 2. If the user is already on the Settings tab, beam the Settings
///    delegate directly. This preserves whatever in-tab history the
///    Beamer has accumulated, so back works as expected.
/// 3. If the user is on a different tab, switch to Settings via
///    [NavService.setIndex] (which does *not* reset the Settings
///    delegate to its root the way [NavService.tapIndex] would when
///    re-entering the same tab) and then beam the Settings delegate.
///
/// Both the index switch and the beam are deferred to a post-frame
/// callback. Riverpod's settings-tree URL sync writes provider state
/// from inside the Beamer's `buildPages` pass, so a synchronous
/// `beamToNamed` triggered from a tap handler produced
/// `Tried to modify a provider while the widget tree was building`.
/// Scheduling the work for the next frame moves it outside the build
/// phase entirely.
void _navigateToAgentRoute(String route) {
  final override = SidebarWakeQueueTestHooks.navigatorOverride;
  if (override != null) {
    override(route);
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navService = getIt<NavService>();
    if (navService.index != navService.settingsIndex) {
      navService.setIndex(navService.settingsIndex);
    }
    navService.settingsDelegate.beamToNamed(route);
    unawaited(navService.persistNamedRoute(route));
  });
}

/// 16 px square avatar tile with the agent's first display-name letter,
/// tinted by a hue derived from the agent name. Mirrors the soul-avatar
/// treatment from the design handoff (`shared.jsx` → `SoulAvatar`).
class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final letter = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();
    final hue = _hueForName(displayName);
    final isDark = tokens.colors.background.level02.computeLuminance() < 0.5;
    final base = HSLColor.fromAHSL(1, hue, 0.40, isDark ? 0.32 : 0.55);
    final text = HSLColor.fromAHSL(1, hue, 0.55, isDark ? 0.86 : 0.30);

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: base.toColor(),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: text.toColor(),
          height: 1,
        ),
      ),
    );
  }

  /// Stable [0, 360) hue from a UTF-16 sum of the name. Deterministic so
  /// re-renders keep the same colour and tests can assert against it.
  double _hueForName(String name) {
    if (name.isEmpty) return 168;
    var sum = 0;
    for (final code in name.codeUnits) {
      sum = (sum + code) & 0xFFFF;
    }
    return (sum % 360).toDouble();
  }
}

/// Compact ETA: `now` when ≤ 0, `mm:ss` under an hour, `Xh Ym` otherwise.
String _formatEta(BuildContext context, int seconds) {
  if (seconds <= 0) {
    return context.messages.sidebarWakesNow;
  }
  if (seconds < 60 * 60) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
