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

/// A single sync-outbox row: a token-driven card with a plain-language status
/// badge, the human "what" (payload kind), and — for failed items — a
/// reassuring reason plus Retry / Remove actions. Tapping the card expands its
/// diagnostic meta (retries, size, subject, attachment) for the curious; the
/// default view stays clean.
class OutboxMessageCard extends StatefulWidget {
  const OutboxMessageCard({
    required this.item,
    this.onRetry,
    this.onRemove,
    super.key,
  });

  final OutboxItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  State<OutboxMessageCard> createState() => _OutboxMessageCardState();
}

class _OutboxMessageCardState extends State<OutboxMessageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final item = widget.item;

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
      child: Material(
        // Step above the level02 page background so the card reads as elevated.
        color: colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
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
                    SizedBox(width: tokens.spacing.step1),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: tokens.spacing.step4,
                      color: colors.text.lowEmphasis,
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
                if (_expanded) _Details(vm: vm),
                if (widget.onRetry != null || widget.onRemove != null) ...[
                  SizedBox(height: tokens.spacing.step3),
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step2,
                    children: [
                      if (widget.onRetry != null)
                        DesignSystemButton(
                          label: messages.outboxActionRetry,
                          leadingIcon: Icons.refresh_rounded,
                          variant: DesignSystemButtonVariant.secondary,
                          onPressed: widget.onRetry,
                        ),
                      if (widget.onRemove != null)
                        DesignSystemButton(
                          label: messages.outboxActionRemove,
                          leadingIcon: Icons.delete_outline_rounded,
                          variant: DesignSystemButtonVariant.dangerTertiary,
                          onPressed: widget.onRemove,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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

/// De-emphasized diagnostic meta, revealed by tapping the card.
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
