import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile / Beamer wrapper. Adds the [SliverBoxAdapterPage] chrome
/// + the [SyncFeatureGate] flag check and delegates content to
/// [BackfillSettingsBody]. The same body is reused inside the
/// Settings V2 detail pane via the panel registry — that host
/// renders its own header, so it embeds [BackfillSettingsBody]
/// directly without this wrapper.
class BackfillSettingsPage extends StatelessWidget {
  const BackfillSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.backfillSettingsTitle,
        subtitle: context.messages.backfillSettingsSubtitle,
        showBackButton: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const BackfillSettingsBody(),
      ),
    );
  }
}

/// Backfill Sync content. Layout follows the
/// `option_c_preview` handoff:
///   1. **Status row** — three welded cells (Inbound queue · Missing
///      · Skipped) on a single rounded surface. Operator-critical
///      counters live here so they sit at eye level.
///   2. **Sync statistics** — leader-dot ledger of seven counts.
///   3. **Automatic backfill** — toggle card.
///   4. **Advanced recovery** — collapsed group containing every
///      manual recovery action.
///
/// The body owns no chrome (page title / scaffold) — both hosts
/// (legacy [BackfillSettingsPage] and the Settings V2 detail pane)
/// supply their own.
class BackfillSettingsBody extends ConsumerWidget {
  const BackfillSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final config = ref.watch(backfillConfigControllerProvider);
    final stats = ref.watch(backfillStatsControllerProvider);
    final matrixService = getIt.isRegistered<MatrixService>()
        ? getIt<MatrixService>()
        : null;
    final coordinator = matrixService?.queueCoordinator;

    return _QueueDepthScope(
      queue: coordinator?.queue,
      builder: (context, depth) {
        return Padding(
          // Breathing room below the host's page title (V2 leaf panel
          // or legacy `SettingsPageHeader`) before the status row.
          padding: EdgeInsets.only(top: tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusRow(
                inbound: depth?.total ?? 0,
                missing: stats.stats?.totalMissing ?? 0,
                skipped: depth?.abandoned ?? 0,
              ),
              SizedBox(height: tokens.spacing.step4),
              _SyncStatsCard(
                stats: stats.stats,
                isLoading: stats.isLoading,
                onRefresh: () => ref
                    .read(backfillStatsControllerProvider.notifier)
                    .refresh(),
              ),
              SizedBox(height: tokens.spacing.step4),
              _AutomaticBackfillCard(
                isEnabled: config.value ?? true,
                isBusy: config.isLoading,
                onToggle: () => ref
                    .read(backfillConfigControllerProvider.notifier)
                    .toggle(),
              ),
              SizedBox(height: tokens.spacing.step4),
              _AdvancedRecoveryGroup(
                stats: stats,
                skipped: depth?.abandoned ?? 0,
                coordinator: coordinator,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Listens to [InboundQueue.depthChanges] and rebuilds with the
/// latest signal. Pulled out so the rest of the body stays a plain
/// [ConsumerWidget] — only this scope needs the stateful subscription.
/// Mirrors the binding pattern in `QueueDepthCard`.
class _QueueDepthScope extends StatefulWidget {
  const _QueueDepthScope({required this.queue, required this.builder});

  final InboundQueue? queue;
  final Widget Function(BuildContext context, QueueDepthSignal? depth) builder;

  @override
  State<_QueueDepthScope> createState() => _QueueDepthScopeState();
}

class _QueueDepthScopeState extends State<_QueueDepthScope> {
  StreamSubscription<QueueDepthSignal>? _sub;
  QueueDepthSignal? _latest;
  bool _liveSignalSeen = false;

  @override
  void initState() {
    super.initState();
    _bind(widget.queue);
  }

  @override
  void didUpdateWidget(covariant _QueueDepthScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.queue, widget.queue)) {
      _sub?.cancel();
      _latest = null;
      _liveSignalSeen = false;
      _bind(widget.queue);
    }
  }

  void _bind(InboundQueue? queue) {
    if (queue == null) return;
    // Capture the queue identity in the closure so that an in-flight
    // emission from a previous (cancelled-but-not-yet-detached)
    // subscription cannot land here and overwrite `_latest` with a
    // signal from the wrong queue. `StreamSubscription.cancel()` is
    // async, so a tick delay between rebinding and the old listener
    // shutting down is real, not theoretical.
    final boundQueue = queue;
    _sub = boundQueue.depthChanges.listen((signal) {
      if (!mounted || !identical(boundQueue, widget.queue)) return;
      setState(() {
        _latest = signal;
        _liveSignalSeen = true;
      });
    });
    unawaited(_loadInitial(boundQueue));
  }

  Future<void> _loadInitial(InboundQueue queue) async {
    try {
      final stats = await queue.stats();
      if (!mounted) return;
      // A live emission while the one-shot read was in flight wins —
      // do not overwrite it with the stale snapshot. Also bail if we
      // rebound to a different queue mid-flight.
      if (_liveSignalSeen) return;
      if (!identical(queue, widget.queue)) return;
      setState(() {
        _latest = QueueDepthSignal(
          total: stats.total,
          byProducer: stats.byProducer,
          oldestEnqueuedAt: stats.oldestEnqueuedAt,
          abandoned: stats.abandoned,
        );
      });
    } catch (_) {
      // The depth subscription will refresh on its next emission;
      // a one-shot DB hiccup at paint time should not crash the page.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _latest);
}

/// Three welded cells in a single rounded rectangle: inbound queue,
/// missing count, skipped count. Each cell colours its value based
/// on state: missing turns warning when > 0; skipped turns error
/// when > 0.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.inbound,
    required this.missing,
    required this.skipped,
  });

  final int inbound;
  final int missing;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final divider = tokens.colors.decorative.level01;

    final missingActive = missing > 0;
    final skippedActive = skipped > 0;

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatusCell(
                icon: Icons.inbox_outlined,
                label: messages.backfillStatusInboundQueue,
                value: inbound,
                valueColor: tokens.colors.text.highEmphasis,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: divider),
            Expanded(
              child: _StatusCell(
                icon: missingActive
                    ? Icons.bolt_outlined
                    : Icons.check_circle_outline,
                label: messages.backfillStatusMissing,
                value: missing,
                valueColor: missingActive
                    ? tokens.colors.alert.warning.defaultColor
                    : tokens.colors.text.highEmphasis,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: divider),
            Expanded(
              child: _StatusCell(
                icon: Icons.error_outline,
                label: messages.backfillStatusSkipped,
                value: skipped,
                labelColor: skippedActive
                    ? tokens.colors.alert.error.defaultColor
                    : null,
                valueColor: skippedActive
                    ? tokens.colors.alert.error.defaultColor
                    : tokens.colors.text.highEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final resolvedLabelColor = labelColor ?? tokens.colors.text.mediumEmphasis;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: resolvedLabelColor),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: resolvedLabelColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            _formatCount(context, value),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync statistics ledger card. Header (chart icon · title · device
/// count meta · refresh) above seven leader-dot rows.
class _SyncStatsCard extends StatelessWidget {
  const _SyncStatsCard({
    required this.stats,
    required this.isLoading,
    required this.onRefresh,
  });

  final BackfillStats? stats;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final hostCount = stats?.hostStats.length ?? 0;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.backfillStatsTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (stats != null)
                Padding(
                  padding: EdgeInsets.only(right: tokens.spacing.step2),
                  child: Text(
                    messages.backfillDevicesMeta(hostCount),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ),
              _IconActionButton(
                icon: Icons.refresh,
                tooltip: messages.backfillStatsRefresh,
                isBusy: isLoading,
                onPressed: isLoading ? null : onRefresh,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          if (stats == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
              child: Text(
                isLoading
                    ? messages.backfillStatsRefresh
                    : messages.backfillStatsNoData,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            )
          else
            _Ledger(stats: stats!),
        ],
      ),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.stats});

  final BackfillStats stats;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final highEmphasis = tokens.colors.text.highEmphasis;
    final lowEmphasis = tokens.colors.text.lowEmphasis;
    final success = tokens.colors.alert.success.defaultColor;
    final warning = tokens.colors.alert.warning.defaultColor;
    final interactive = tokens.colors.interactive.enabled;
    final error = tokens.colors.alert.error.defaultColor;

    final missingTone = stats.totalMissing > 0 ? warning : lowEmphasis;
    final requestedTone = stats.totalRequested > 0 ? interactive : lowEmphasis;
    final unresolvableTone = stats.totalUnresolvable > 0 ? error : lowEmphasis;

    return Column(
      children: [
        _LedgerRow(
          label: messages.backfillStatsTotalEntries,
          value: stats.totalEntries,
          color: highEmphasis,
        ),
        _LedgerRow(
          label: messages.backfillStatsReceived,
          value: stats.totalReceived,
          color: highEmphasis,
        ),
        _LedgerRow(
          label: messages.backfillStatsBackfilled,
          value: stats.totalBackfilled,
          color: success,
        ),
        _LedgerRow(
          label: messages.backfillStatsMissing,
          value: stats.totalMissing,
          color: missingTone,
        ),
        _LedgerRow(
          label: messages.backfillStatsRequested,
          value: stats.totalRequested,
          color: requestedTone,
        ),
        _LedgerRow(
          label: messages.backfillStatsDeleted,
          value: stats.totalDeleted,
          color: lowEmphasis,
        ),
        _LedgerRow(
          label: messages.backfillStatsUnresolvable,
          value: stats.totalUnresolvable,
          color: unresolvableTone,
        ),
      ],
    );
  }
}

/// One leader-dotted row: label on the left, dotted line filling the
/// gap, tabular value on the right.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Row(
        children: [
          Text(
            label,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
              child: CustomPaint(
                size: const Size.fromHeight(1),
                painter: _DottedLeaderPainter(
                  color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          Text(
            _formatCount(context, value),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  const _DottedLeaderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dotSpacing = 4.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dotSpacing) {
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLeaderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Automatic backfill toggle card. Sync icon · title + description ·
/// [DesignSystemToggle].
class _AutomaticBackfillCard extends StatelessWidget {
  const _AutomaticBackfillCard({
    required this.isEnabled,
    required this.isBusy,
    required this.onToggle,
  });

  final bool isEnabled;
  final bool isBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return _SurfaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync,
            size: 18,
            color: tokens.colors.interactive.enabled,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.backfillToggleTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  messages.backfillToggleDescription,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemToggle(
            value: isEnabled,
            onChanged: (_) => onToggle(),
            enabled: !isBusy,
            semanticsLabel: messages.backfillToggleTitle,
          ),
        ],
      ),
    );
  }
}

/// Collapsible group containing every recovery action. Header is
/// always visible; body is hidden until tapped open. Order matches
/// the design handoff:
///   1. Catch up now (primary)
///   2. Retry skipped events (visible when skipped > 0)
///   3. Manual backfill (primary)
///   4. Reset unresolvable (primary, disabled when 0)
///   5. Re-request pending (secondary, disabled when 0)
///   6. Ask peers for unresolvable (primary, disabled when 0)
///   7. Retire stuck entries (danger-tertiary, disabled when 0)
class _AdvancedRecoveryGroup extends StatefulWidget {
  const _AdvancedRecoveryGroup({
    required this.stats,
    required this.skipped,
    required this.coordinator,
  });

  final BackfillStatsState stats;
  final int skipped;
  final QueuePipelineCoordinator? coordinator;

  @override
  State<_AdvancedRecoveryGroup> createState() => _AdvancedRecoveryGroupState();
}

class _AdvancedRecoveryGroupState extends State<_AdvancedRecoveryGroup>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _chevController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _chevController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _chevController.forward();
    } else {
      _chevController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final actions = _buildActions(context);

    // The outer Container's `clipBehavior` clips its own descendant
    // paint, but [InkWell] splashes are drawn on the nearest ancestor
    // [Material] — which here is the [MaterialApp]'s root Material
    // far up the tree. Without a local [Material] inside the
    // container the splash escapes the rounded corners. Wrapping the
    // header in a transparent [Material] gives ink an in-bounds
    // surface, so the splash is naturally clipped by the Container's
    // rounded shape above it.
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        messages.backfillAdvancedRecoveryTitle,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      messages.backfillAdvancedRecoveryActions(actions.length),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.25).animate(
                        CurvedAnimation(
                          parent: _chevController,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            Container(
              height: 1,
              color: tokens.colors.decorative.level01,
            ),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  color: tokens.colors.decorative.level01,
                ),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final messages = context.messages;
    final stats = widget.stats;
    final coordinator = widget.coordinator;
    final unresolvable = stats.stats?.totalUnresolvable ?? 0;
    final requested = stats.stats?.totalRequested ?? 0;
    final missing = stats.stats?.totalMissing ?? 0;
    final openCount = missing + requested;
    // The controller serializes every backfill op, so while one is
    // in flight the others would only bounce off its guard. Reflect
    // that in the UI by disabling all controller-backed actions
    // whenever any of them is running — keeps the page from looking
    // actionable when it isn't.
    final controllerBusy =
        stats.isProcessing ||
        stats.isResetting ||
        stats.isReRequesting ||
        stats.isResettingAllUnresolvable ||
        stats.isRetiringStuck;

    return [
      _RecoveryAction(
        icon: Icons.bolt_outlined,
        title: messages.queueCatchUpNowButton,
        description: messages.backfillCatchUpDescription,
        ctaLabel: messages.queueCatchUpNowButton,
        ctaIcon: Icons.bolt_outlined,
        tone: _RecoveryTone.primary,
        onPressed: coordinator == null
            ? null
            : () => _kickCatchUp(context, coordinator),
      ),
      if (widget.skipped > 0)
        _RecoveryAction(
          icon: Icons.refresh_rounded,
          title: messages.queueSkippedCardTitle,
          description: messages.queueSkippedCardBody(widget.skipped),
          ctaLabel: messages.queueSkippedRetryAll,
          ctaIcon: Icons.refresh_rounded,
          tone: _RecoveryTone.primary,
          onPressed: coordinator == null
              ? null
              : () => _retrySkipped(context, coordinator.queue),
        ),
      _RecoveryAction(
        icon: Icons.history_rounded,
        title: messages.backfillManualTitle,
        description: messages.backfillManualDescription,
        ctaLabel: stats.isProcessing
            ? messages.backfillManualProcessing
            : messages.backfillManualTrigger,
        ctaIcon: Icons.sync,
        tone: _RecoveryTone.primary,
        isBusy: stats.isProcessing,
        onPressed: controllerBusy
            ? null
            : () => ProviderScope.containerOf(context)
                  .read(backfillStatsControllerProvider.notifier)
                  .triggerFullBackfill(),
      ),
      _RecoveryAction(
        icon: Icons.restore_rounded,
        title: messages.backfillResetUnresolvableTitle,
        description: messages.backfillResetUnresolvableDescription,
        ctaLabel: stats.isResetting
            ? messages.backfillResetUnresolvableProcessing
            : messages.backfillResetUnresolvableTrigger,
        ctaIcon: Icons.restore_rounded,
        tone: _RecoveryTone.primary,
        isBusy: stats.isResetting,
        onPressed: (controllerBusy || unresolvable == 0)
            ? null
            : () => ProviderScope.containerOf(context)
                  .read(backfillStatsControllerProvider.notifier)
                  .resetUnresolvable(),
      ),
      _RecoveryAction(
        icon: Icons.replay_rounded,
        title: messages.backfillReRequestTitle,
        description: messages.backfillReRequestDescription,
        ctaLabel: stats.isReRequesting
            ? messages.backfillReRequestProcessing
            : messages.backfillReRequestTrigger,
        ctaIcon: Icons.replay_rounded,
        tone: _RecoveryTone.ghost,
        isBusy: stats.isReRequesting,
        onPressed: (controllerBusy || requested == 0)
            ? null
            : () => ProviderScope.containerOf(context)
                  .read(backfillStatsControllerProvider.notifier)
                  .triggerReRequest(),
      ),
      _RecoveryAction(
        icon: Icons.group_outlined,
        title: messages.backfillAskPeersTitle,
        description: messages.backfillAskPeersDescription,
        ctaLabel: stats.isResettingAllUnresolvable
            ? messages.backfillAskPeersProcessing
            : messages.backfillAskPeersTrigger(unresolvable),
        ctaIcon: Icons.group_outlined,
        tone: _RecoveryTone.primary,
        isBusy: stats.isResettingAllUnresolvable,
        onPressed: (controllerBusy || unresolvable == 0)
            ? null
            : () => _confirmAndResetAllUnresolvable(context, unresolvable),
      ),
      _RecoveryAction(
        icon: Icons.block_outlined,
        title: messages.backfillRetireStuckTitle,
        description: messages.backfillRetireStuckDescription,
        ctaLabel: stats.isRetiringStuck
            ? messages.backfillRetireStuckProcessing
            : messages.backfillRetireStuckTrigger(openCount),
        ctaIcon: Icons.block_outlined,
        tone: _RecoveryTone.dangerGhost,
        isBusy: stats.isRetiringStuck,
        onPressed: (controllerBusy || openCount == 0)
            ? null
            : () => _confirmAndRetireStuck(context, openCount),
      ),
    ];
  }

  Future<void> _kickCatchUp(
    BuildContext context,
    QueuePipelineCoordinator coordinator,
  ) async {
    final messages = context.messages;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await coordinator.triggerBridge();
      messenger?.showSnackBar(
        SnackBar(content: Text(messages.queueCatchUpNowDone)),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(messages.queueCatchUpNowError(e.toString())),
        ),
      );
    }
  }

  Future<void> _retrySkipped(BuildContext context, InboundQueue queue) async {
    final messages = context.messages;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final count = await queue.resurrectAll();
      messenger?.showSnackBar(
        SnackBar(content: Text(messages.queueSkippedRetryAllDone(count))),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(messages.queueSkippedRetryAllError(e.toString())),
        ),
      );
    }
  }

  Future<void> _confirmAndResetAllUnresolvable(
    BuildContext context,
    int unresolvable,
  ) async {
    final messages = context.messages;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messages.backfillAskPeersConfirmTitle),
        content: Text(
          messages.backfillAskPeersConfirmContent(unresolvable),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(messages.backfillAskPeersConfirmAccept),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ProviderScope.containerOf(
      context,
    ).read(backfillStatsControllerProvider.notifier).resetAllUnresolvable();
  }

  Future<void> _confirmAndRetireStuck(
    BuildContext context,
    int openCount,
  ) async {
    final messages = context.messages;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messages.backfillRetireStuckConfirmTitle),
        content: Text(
          messages.backfillRetireStuckConfirmContent(openCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(messages.backfillRetireStuckConfirmAccept),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ProviderScope.containerOf(
      context,
    ).read(backfillStatsControllerProvider.notifier).retireStuckNow();
  }
}

enum _RecoveryTone { primary, ghost, dangerGhost }

class _RecoveryAction extends StatelessWidget {
  const _RecoveryAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.tone,
    required this.onPressed,
    this.isBusy = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String ctaLabel;
  final IconData ctaIcon;
  final _RecoveryTone tone;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isDanger = tone == _RecoveryTone.dangerGhost;
    final iconChipBg = isDanger
        ? tokens.colors.alert.error.defaultColor.withValues(alpha: 0.14)
        : tokens.colors.surface.enabled;
    final iconColor = isDanger
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.text.mediumEmphasis;

    return Container(
      color: tokens.colors.background.level02,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconChipBg,
                  borderRadius: BorderRadius.circular(tokens.radii.smallChips),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      description,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemButton(
            label: ctaLabel,
            onPressed: onPressed,
            leadingIcon: isBusy ? null : ctaIcon,
            variant: switch (tone) {
              _RecoveryTone.primary => DesignSystemButtonVariant.primary,
              _RecoveryTone.ghost => DesignSystemButtonVariant.secondary,
              _RecoveryTone.dangerGhost =>
                DesignSystemButtonVariant.dangerSecondary,
            },
            size: DesignSystemButtonSize.medium,
          ),
        ],
      ),
    );
  }
}

/// Shared rounded surface card. Background, radius, and outline come
/// from design tokens; the only knob the caller turns is `padding`.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: padding ?? EdgeInsets.all(tokens.spacing.step5),
      child: child,
    );
  }
}

/// Compact icon-only button used in card headers (e.g. the stats
/// refresh control). Mirrors the Material `IconButton` ergonomics
/// while sourcing every visual from design tokens.
class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isBusy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = onPressed != null;
    final foreground = enabled
        ? tokens.colors.text.mediumEmphasis
        : tokens.colors.text.lowEmphasis;
    final child = isBusy
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          )
        : Icon(icon, size: 16, color: foreground);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.smallChips),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step2),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Locale-aware integer formatter used in both the status row and
/// ledger so the page stays consistent across English (`715,544`),
/// German (`715.544`), French (`715 544`), etc.
String _formatCount(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(value);
