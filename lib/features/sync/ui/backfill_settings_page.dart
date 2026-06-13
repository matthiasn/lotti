import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/ui/backfill_settings_recovery.dart';
import 'package:lotti/features/sync/ui/backfill_settings_stats.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/sync/ui/backfill_settings_recovery.dart';

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
///   2. **Sync statistics** — leader-dot ledger of eight counts.
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
              StatusRow(
                inbound: depth?.total ?? 0,
                missing: stats.stats?.totalMissing ?? 0,
                skipped: depth?.abandoned ?? 0,
              ),
              SizedBox(height: tokens.spacing.step4),
              SyncStatsCard(
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
              AdvancedRecoveryGroup(
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

/// Compact icon-only button used in card headers (e.g. the stats
/// refresh control). Mirrors the Material `IconButton` ergonomics
/// while sourcing every visual from design tokens.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isBusy = false,
    super.key,
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
String formatCount(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(value);

/// Test-only seam for [formatCount] — locale plumbing is the part worth
/// testing; the number formatting itself is intl's.
@visibleForTesting
String debugFormatCount(BuildContext context, int value) =>
    formatCount(context, value);
