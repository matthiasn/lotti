import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_status_presentation.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The plain-language status line at the top of the outbox page — the answer to
/// "is my stuff synced?" before the user reads a single row. Shows a calm tone
/// when synced, an in-progress tone while sending, a reassuring offline line
/// when signed out, and a clear failure line (with a one-tap **Retry all**)
/// when items couldn't send.
class OutboxSummaryHeader extends StatelessWidget {
  const OutboxSummaryHeader({
    required this.summary,
    this.onRetryAll,
    super.key,
  });

  final QueueSummary summary;

  /// Shown only when there are failed items.
  final VoidCallback? onRetryAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final accent = _toneColor(summary.state, colors);
    final showRetryAll = summary.failedCount > 0 && onRetryAll != null;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Row(
        children: [
          Icon(_icon(summary.state), color: accent, size: IconSizes.s),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              _summaryText(summary, messages),
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: colors.text.highEmphasis,
              ),
            ),
          ),
          if (showRetryAll) ...[
            SizedBox(width: tokens.spacing.step2),
            DesignSystemButton(
              label: messages.outboxRetryAll,
              leadingIcon: LottiIcons.refresh,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: onRetryAll,
            ),
          ],
        ],
      ),
    );
  }

  String _summaryText(QueueSummary s, AppLocalizations m) => switch (s.state) {
    QueueState.synced => m.outboxSummarySynced,
    QueueState.sending => m.outboxSummarySending(s.activeCount),
    QueueState.waiting => m.outboxSummaryWaiting(s.activeCount),
    QueueState.failed => m.outboxSummaryFailed(s.failedCount),
    QueueState.offline => m.outboxSummaryOffline(s.activeCount + s.failedCount),
  };

  Color _toneColor(QueueState state, DsColors colors) => switch (state) {
    QueueState.synced => colors.alert.success.ink,
    QueueState.sending => colors.alert.info.ink,
    QueueState.waiting => colors.alert.warning.ink,
    QueueState.failed => colors.alert.error.ink,
    QueueState.offline => colors.text.mediumEmphasis,
  };

  IconData _icon(QueueState state) => switch (state) {
    QueueState.synced => LottiIcons.confirmCircled,
    QueueState.sending => LottiIcons.sync,
    QueueState.waiting => LottiIcons.schedule,
    QueueState.failed => LottiIcons.error,
    QueueState.offline => LottiIcons.cloudOff,
  };
}
