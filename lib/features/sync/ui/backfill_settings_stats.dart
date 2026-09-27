import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Three welded cells in a single rounded rectangle: inbound queue,
/// missing count, skipped count. Each cell colours its value based
/// on state: missing turns warning when > 0; skipped turns error
/// when > 0.
class StatusRow extends StatelessWidget {
  const StatusRow({
    required this.inbound,
    required this.missing,
    required this.skipped,
    super.key,
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
                icon: LottiIcons.inbox,
                label: messages.backfillStatusInboundQueue,
                value: inbound,
                valueColor: tokens.colors.text.highEmphasis,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: divider),
            Expanded(
              child: _StatusCell(
                icon: missingActive
                    ? LottiIcons.bolt
                    : LottiIcons.confirmCircled,
                label: messages.backfillStatusMissing,
                value: missing,
                valueColor: missingActive
                    ? tokens.colors.alert.warning.ink
                    : tokens.colors.text.highEmphasis,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: divider),
            Expanded(
              child: _StatusCell(
                icon: LottiIcons.error,
                label: messages.backfillStatusSkipped,
                value: skipped,
                labelColor: skippedActive
                    ? tokens.colors.alert.error.ink
                    : null,
                valueColor: skippedActive
                    ? tokens.colors.alert.error.ink
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
              Icon(icon, size: IconSizes.xs, color: resolvedLabelColor),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: resolvedLabelColor,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            formatCount(context, value),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync statistics ledger card. Header (chart icon · title · device
/// count meta · refresh) above eight leader-dot rows.
class SyncStatsCard extends StatelessWidget {
  const SyncStatsCard({
    required this.stats,
    required this.missingCount,
    required this.isLoading,
    required this.onRefresh,
    this.hostNames = const {},
    this.selfHostId,
    super.key,
  });

  final BackfillStats? stats;
  final int missingCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  /// Display names of known devices by host id, for the per-device rows.
  final Map<String, String> hostNames;

  /// This device's host id, marked in the per-device rows.
  final String? selfHostId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final hostCount = stats?.hostStats.length ?? 0;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LottiIcons.chart,
                size: IconSizes.m,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.backfillStatsTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
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
              DesignSystemIconAction(
                icon: LottiIcons.refresh,
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
            _Ledger(
              stats: stats!,
              missingCount: missingCount,
              hostNames: hostNames,
              selfHostId: selfHostId,
            ),
        ],
      ),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({
    required this.stats,
    required this.missingCount,
    required this.hostNames,
    required this.selfHostId,
  });

  final BackfillStats stats;
  final int missingCount;
  final Map<String, String> hostNames;
  final String? selfHostId;

  /// A device's name, or the start of its host id when it has none.
  String _hostLabel(BuildContext context, String hostId) {
    final name =
        hostNames[hostId] ??
        (hostId.length > 8 ? hostId.substring(0, 8) : hostId);
    return hostId == selfHostId
        ? context.messages.backfillStatsThisDevice(name)
        : name;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final highEmphasis = tokens.colors.text.highEmphasis;
    final lowEmphasis = tokens.colors.text.lowEmphasis;
    final success = tokens.colors.alert.success.ink;
    final warning = tokens.colors.alert.warning.ink;
    final interactive = tokens.colors.interactive.enabled;
    final error = tokens.colors.alert.error.ink;

    final missingTone = missingCount > 0 ? warning : lowEmphasis;
    final requestedTone = stats.totalRequested > 0 ? interactive : lowEmphasis;
    final unresolvableTone = stats.totalUnresolvable > 0 ? error : lowEmphasis;

    return Column(
      children: [
        _LedgerRow(
          label: messages.backfillStatsTrackedCounters,
          value: stats.trackedCounters,
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
          value: missingCount,
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
        // Authoritative non-events: always low-emphasis. Unlike unresolvable,
        // a non-zero burned count is benign (voided vector-clock counters with
        // nothing to fetch), so it never escalates to the error tone.
        _LedgerRow(
          label: messages.backfillStatsBurned,
          value: stats.totalBurned,
          color: lowEmphasis,
        ),
        if (stats.hostStats.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(
              top: tokens.spacing.step4,
              bottom: tokens.spacing.step1,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                messages.backfillStatsByDevice,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: lowEmphasis,
                ),
              ),
            ),
          ),
          // Counters differ between devices that hold the same records:
          // a device never gap-detects its own host. Listing them per host
          // shows where a difference sits.
          for (final host in [
            ...stats.hostStats,
          ]..sort((a, b) => b.trackedCounters.compareTo(a.trackedCounters)))
            _LedgerRow(
              label: _hostLabel(context, host.hostId),
              value: host.trackedCounters,
              color: highEmphasis,
            ),
        ],
      ],
    );
  }
}

/// Records of each synced type on this device, deletions included: the
/// numbers a deep backfill makes equal, so two devices in sync show the same
/// ones here — unlike the tracked counters. The counts update on their own
/// while shown, so the card has no refresh action.
class RecordCountsCard extends StatelessWidget {
  const RecordCountsCard({
    required this.counts,
    required this.isLoading,
    super.key,
  });

  /// Null while loading, or where no sync stack runs.
  final Map<SyncSequencePayloadType, int>? counts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final counts = this.counts;
    final labels = <SyncSequencePayloadType, String>{
      SyncSequencePayloadType.journalEntity: messages.backfillRecordsJournal,
      SyncSequencePayloadType.entryLink: messages.backfillRecordsEntryLinks,
      SyncSequencePayloadType.agentEntity:
          messages.backfillRecordsAgentEntities,
      SyncSequencePayloadType.agentLink: messages.backfillRecordsAgentLinks,
      SyncSequencePayloadType.notification:
          messages.backfillRecordsNotifications,
      SyncSequencePayloadType.consumptionEvent:
          messages.backfillRecordsConsumptionEvents,
    };

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LottiIcons.list,
                size: IconSizes.m,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.backfillRecordsTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.backfillRecordsHint,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          if (counts == null)
            Text(
              isLoading
                  ? messages.backfillStatsRefresh
                  : messages.backfillStatsNoData,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            )
          else
            for (final MapEntry(key: type, value: label) in labels.entries)
              if (counts[type] case final count?)
                _LedgerRow(
                  label: label,
                  value: count,
                  color: tokens.colors.text.highEmphasis,
                ),
        ],
      ),
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
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            // The label keeps its natural width, so the value sits at the
            // edge; only a label wider than most of the row — a long device
            // name — is cut short.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * _maxLabelShare,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
                child: CustomPaint(
                  size: const Size.fromHeight(1),
                  painter: _DottedLeaderPainter(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
            ),
            Text(
              formatCount(context, value),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: tokens.typography.weight.semiBold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The most of a row a label may take before it is cut short.
  static const double _maxLabelShare = 0.6;
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
