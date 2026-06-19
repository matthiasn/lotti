import 'package:flutter/material.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_list_item_view_model.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_status_presentation.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A single sync-outbox row, redesigned to match the conflicts surface:
/// a token-driven card with a plain-language status badge, the human "what"
/// (payload kind), and — for failed items — a reassuring reason plus Retry /
/// Remove actions. Diagnostic meta (retries, size, subject, attachment) is
/// shown only when [showDetails] is on.
class OutboxMessageCard extends StatelessWidget {
  const OutboxMessageCard({
    required this.item,
    this.showDetails = false,
    this.onRetry,
    this.onRemove,
    super.key,
  });

  final OutboxItem item;
  final bool showDetails;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;

    final status = item.status >= 0 && item.status < OutboxStatus.values.length
        ? OutboxStatus.values[item.status]
        : OutboxStatus.pending;
    final presentation = presentationStatusOf(status);
    final isFailed = presentation == OutboxPresentationStatus.failed;

    // Reuse the existing view model purely for its localized payload/meta
    // labels; the status visuals come from the new presentation model.
    final vm = OutboxListItemViewModel.fromItem(context: context, item: item);
    final statusLabel = _statusLabel(presentation, messages);

    return Semantics(
      label: '$statusLabel, ${vm.timestampLabel}, ${vm.payloadKindLabel}',
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DesignSystemBadge.filled(
                  label: statusLabel,
                  tone: _toneFor(presentation),
                ),
                const Spacer(),
                Text(
                  vm.timestampLabel,
                  style: monoMetaStyle(
                    tokens,
                    colors,
                    color: colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              vm.payloadKindLabel,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: colors.text.highEmphasis,
              ),
            ),
            if (isFailed) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                messages.outboxFailedReassurance,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step1),
              Text(
                messages.outboxTriedTimes(item.retries),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: colors.text.lowEmphasis,
                ),
              ),
            ],
            if (showDetails) _Details(vm: vm),
            if (onRetry != null || onRemove != null) ...[
              SizedBox(height: tokens.spacing.step3),
              Row(
                children: [
                  if (onRetry != null)
                    DesignSystemButton(
                      label: messages.outboxActionRetry,
                      leadingIcon: Icons.refresh_rounded,
                      variant: DesignSystemButtonVariant.secondary,
                      onPressed: onRetry,
                    ),
                  if (onRetry != null && onRemove != null)
                    SizedBox(width: tokens.spacing.step2),
                  if (onRemove != null)
                    DesignSystemButton(
                      label: messages.outboxActionRemove,
                      leadingIcon: Icons.delete_outline_rounded,
                      variant: DesignSystemButtonVariant.dangerTertiary,
                      onPressed: onRemove,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  DesignSystemBadgeTone _toneFor(OutboxPresentationStatus status) =>
      switch (status) {
        OutboxPresentationStatus.waiting => DesignSystemBadgeTone.warning,
        OutboxPresentationStatus.sending => DesignSystemBadgeTone.primary,
        OutboxPresentationStatus.failed => DesignSystemBadgeTone.danger,
        OutboxPresentationStatus.sent => DesignSystemBadgeTone.success,
      };

  String _statusLabel(
    OutboxPresentationStatus status,
    AppLocalizations messages,
  ) => switch (status) {
    OutboxPresentationStatus.waiting => messages.outboxStatusWaiting,
    OutboxPresentationStatus.sending => messages.outboxStatusSending,
    OutboxPresentationStatus.failed => messages.outboxStatusFailed,
    OutboxPresentationStatus.sent => messages.outboxStatusSent,
  };
}

/// De-emphasized diagnostic meta, revealed by the page-level "show technical
/// details" toggle.
class _Details extends StatelessWidget {
  const _Details({required this.vm});

  final OutboxListItemViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: colors.text.lowEmphasis,
    );
    final lines = <String>[
      vm.retriesLabel,
      if (vm.payloadSizeLabel != null) vm.payloadSizeLabel!,
      if (vm.subjectValue != null) vm.subjectValue!,
      vm.attachmentValue,
    ];
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) Text(line, style: style)],
      ),
    );
  }
}
