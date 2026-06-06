part of 'backfill_settings_page.dart';

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
/// count meta · refresh) above eight leader-dot rows.
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
        // Authoritative non-events: always low-emphasis. Unlike unresolvable,
        // a non-zero burned count is benign (voided vector-clock counters with
        // nothing to fetch), so it never escalates to the error tone.
        _LedgerRow(
          label: messages.backfillStatsBurned,
          value: stats.totalBurned,
          color: lowEmphasis,
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
