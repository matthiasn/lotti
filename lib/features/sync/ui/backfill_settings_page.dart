import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/sync/sync_node_profile.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/ui/backfill_settings_recovery.dart';
import 'package:lotti/features/sync/ui/backfill_settings_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:material_ui/material_ui.dart';

export 'package:lotti/features/sync/ui/backfill_settings_recovery.dart';

/// Mobile / Beamer wrapper. Adds the [SliverBoxAdapterPage] chrome
/// + the [SyncFeatureGate] flag check and delegates content to
/// [BackfillSettingsBody]. The same body is reused inside the
/// desktop settings detail pane via its `settingsRoutes` entry — that host
/// renders its own header, so it embeds [BackfillSettingsBody]
/// directly without this wrapper.
class BackfillSettingsPage extends StatelessWidget {
  const BackfillSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.syncHealthTitle,
        subtitle: context.messages.syncHealthSubtitle,
        showBackButton: true,
        padding: EdgeInsets.symmetric(
          horizontal: context.designTokens.spacing.step5,
        ),
        child: const BackfillSettingsBody(),
      ),
    );
  }
}

/// Sync health content (the page was "Backfill sync"). Layout follows the
/// `option_c_preview` handoff, with the records first:
///   1. **Records on this device** — per-type record counts, the numbers a
///      deep backfill makes equal across devices: the direct answer to "do
///      my devices hold the same data?". Re-counted while shown.
///   2. **Status row** — three welded cells (Inbound queue · Missing
///      · Skipped) on a single rounded surface. Operator-critical
///      counters live here so they sit at eye level.
///   3. **Sync statistics** — leader-dot ledger of eight counts, then the
///      tracked counters per device.
///   4. **Automatic backfill** — toggle card.
///   5. **Advanced recovery** — collapsed group containing every
///      manual recovery action.
///
/// Each section watches only what it shows. The inbound queue and the
/// record counts change several times a second during a sync; a rebuild of
/// the whole body on every change, per-device ledger included, is what made
/// the page stutter while scrolling.
///
/// The body owns no chrome (page title / scaffold) — both hosts
/// (legacy [BackfillSettingsPage] and the desktop settings detail pane)
/// supply their own.
class BackfillSettingsBody extends StatelessWidget {
  const BackfillSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final matrixService = getIt.isRegistered<MatrixService>()
        ? getIt<MatrixService>()
        : null;
    final coordinator = matrixService?.queueCoordinator;

    return _QueueDepthScope(
      queue: coordinator?.queue,
      builder: (context, depth) {
        return Padding(
          // Breathing room below the host's page title (desktop leaf panel
          // or legacy `SettingsPageHeader`) before the first card.
          padding: EdgeInsets.only(top: tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RecordCountsSection(),
              SizedBox(height: tokens.spacing.step4),
              _StatusSection(depth: depth),
              SizedBox(height: tokens.spacing.step4),
              const _StatsSection(),
              SizedBox(height: tokens.spacing.step4),
              const _AutomaticBackfillSection(),
              SizedBox(height: tokens.spacing.step4),
              _RecoverySection(depth: depth, coordinator: coordinator),
            ],
          ),
        );
      },
    );
  }
}

/// The live missing count, or the last statistics' total before the live
/// count has arrived.
int _missingCount(WidgetRef ref) =>
    ref.watch(backfillMissingCountProvider).value ??
    ref.watch(backfillStatsControllerProvider).stats?.totalMissing ??
    0;

class _RecordCountsSection extends ConsumerWidget {
  const _RecordCountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordCounts = ref.watch(deepBackfillRecordCountsProvider);
    return RecordCountsCard(
      counts: recordCounts.value,
      isLoading: recordCounts.isLoading,
    );
  }
}

class _StatusSection extends ConsumerWidget {
  const _StatusSection({required this.depth});

  final ValueListenable<QueueDepthSignal?> depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = _missingCount(ref);
    return ValueListenableBuilder<QueueDepthSignal?>(
      valueListenable: depth,
      builder: (context, depth, _) => StatusRow(
        inbound: depth?.total ?? 0,
        missing: missing,
        skipped: depth?.abandoned ?? 0,
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(backfillStatsControllerProvider);
    final self = ref.watch(localSyncNodeSelfProvider).value;
    final hostNames = {
      for (final node
          in ref.watch(knownSyncNodesProvider).value ??
              const <SyncNodeProfile>[])
        node.hostId: node.displayName,
      if (self != null) self.hostId: self.displayName,
    };
    return SyncStatsCard(
      stats: stats.stats,
      missingCount: _missingCount(ref),
      isLoading: stats.isLoading,
      onRefresh: () =>
          ref.read(backfillStatsControllerProvider.notifier).refresh(),
      hostNames: hostNames,
      selfHostId: self?.hostId,
    );
  }
}

class _AutomaticBackfillSection extends ConsumerWidget {
  const _AutomaticBackfillSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(backfillConfigControllerProvider);
    return _AutomaticBackfillCard(
      isEnabled: config.value ?? true,
      isBusy: config.isLoading,
      onToggle: () =>
          ref.read(backfillConfigControllerProvider.notifier).toggle(),
    );
  }
}

class _RecoverySection extends ConsumerWidget {
  const _RecoverySection({required this.depth, required this.coordinator});

  final ValueListenable<QueueDepthSignal?> depth;
  final QueuePipelineCoordinator? coordinator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(backfillStatsControllerProvider);
    return ValueListenableBuilder<QueueDepthSignal?>(
      valueListenable: depth,
      builder: (context, depth, _) => AdvancedRecoveryGroup(
        stats: stats,
        skipped: depth?.abandoned ?? 0,
        coordinator: coordinator,
      ),
    );
  }
}

/// Listens to [InboundQueue.depthChanges] and publishes the latest signal
/// through a [ValueListenable]. The subtree is built once; only the
/// listeners of that value rebuild on a signal — during a sync the queue
/// emits several a second. Mirrors the binding pattern in `QueueDepthCard`.
class _QueueDepthScope extends StatefulWidget {
  const _QueueDepthScope({required this.queue, required this.builder});

  final InboundQueue? queue;
  final Widget Function(
    BuildContext context,
    ValueListenable<QueueDepthSignal?> depth,
  )
  builder;

  @override
  State<_QueueDepthScope> createState() => _QueueDepthScopeState();
}

class _QueueDepthScopeState extends State<_QueueDepthScope> {
  StreamSubscription<QueueDepthSignal>? _sub;
  final ValueNotifier<QueueDepthSignal?> _latest = ValueNotifier(null);
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
      _latest.value = null;
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
      _latest.value = signal;
      _liveSignalSeen = true;
    });
    unawaited(_loadInitial(boundQueue));
  }

  Future<void> _loadInitial(InboundQueue queue) async {
    try {
      final stats = await queue.depthSnapshot();
      if (!mounted) return;
      // A live emission while the one-shot read was in flight wins —
      // do not overwrite it with the stale snapshot. Also bail if we
      // rebound to a different queue mid-flight.
      if (_liveSignalSeen) return;
      if (!identical(queue, widget.queue)) return;
      _latest.value = QueueDepthSignal(
        total: stats.total,
        abandoned: stats.abandoned,
      );
    } catch (_) {
      // The depth subscription will refresh on its next emission;
      // a one-shot DB hiccup at paint time should not crash the page.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _latest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _latest);
}

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
    return SurfaceCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Row(
        children: [
          Icon(
            LottiIcons.sync,
            size: IconSizes.m,
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

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding, super.key});

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

/// Locale-aware integer formatter used in both the status row and
/// ledger so the page stays consistent across English (`715,544`),
/// German (`715.544`), French (`715 544`), etc.
String formatCount(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(value);
