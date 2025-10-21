import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Displays a single outbox entry using the modern card system.
class OutboxListItem extends StatelessWidget {
  const OutboxListItem({
    required this.item,
    this.onRetry,
    this.showRetry = false,
    super.key,
  });

  final OutboxItem item;
  final Future<void> Function()? onRetry;
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final status = OutboxStatus.values[item.status];
    final statusLabel = _statusLabel(context, status);
    final statusColor = _statusColor(context, status);
    final statusIcon = _statusIcon(status);

    final retriesLabel = _retriesLabel(context, item.retries);

    final payloadKind = _payloadKind(context, item.message);

    final noAttachmentMessage = context.messages.outboxMonitorNoAttachment;
    final noAttachmentDisplay = _titleCaseMessage(noAttachmentMessage, locale);
    final hasAttachment =
        item.filePath != null && item.filePath!.trim().isNotEmpty;
    final attachmentValue =
        hasAttachment ? item.filePath!.trim() : noAttachmentDisplay;

    final subjectValue = item.subject.isNotEmpty ? item.subject.trim() : null;

    final trailing = showRetry && onRetry != null
        ? FilledButton.icon(
            key: ValueKey('outboxRetry-${item.id}'),
            onPressed: () => onRetry!.call(),
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              _titleCaseMessage(
                context.messages.outboxMonitorRetry,
                locale,
              ),
            ),
          )
        : null;

    return Semantics(
      label:
          '$statusLabel, ${df.format(item.createdAt)}, ${payloadKind.toLowerCase()}',
      child: ModernBaseCard(
        child: ModernCardContent(
          leading: ModernIconContainer(
            icon: statusIcon,
            iconColor: statusColor,
          ),
          title: df.format(item.createdAt),
          trailing: trailing,
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppTheme.spacingSmall,
                runSpacing: AppTheme.spacingSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ModernStatusChip(
                    label: statusLabel,
                    color: statusColor,
                    icon: _statusChipIcon(status),
                  ),
                  Chip(
                    label: Text(
                      payloadKind,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              _MetaRow(
                icon: Icons.restart_alt_rounded,
                label: context.messages.outboxMonitorRetriesLabel,
                value: retriesLabel,
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              _MetaRow(
                icon: Icons.widgets_rounded,
                label: context.messages.syncListPayloadKindLabel,
                value: payloadKind,
              ),
              if (subjectValue != null) ...[
                const SizedBox(height: AppTheme.spacingSmall),
                _MetaRow(
                  icon: Icons.tag_rounded,
                  label: context.messages.outboxMonitorSubjectLabel,
                  value: subjectValue,
                ),
              ],
              const SizedBox(height: AppTheme.spacingSmall),
              _MetaRow(
                icon: hasAttachment
                    ? Icons.attachment_rounded
                    : Icons.block_outlined,
                label: context.messages.outboxMonitorAttachmentLabel,
                value: attachmentValue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(BuildContext context, OutboxStatus status) {
    final base = switch (status) {
      OutboxStatus.pending => context.messages.outboxMonitorLabelPending,
      OutboxStatus.sent => context.messages.outboxMonitorLabelSent,
      OutboxStatus.error => context.messages.outboxMonitorLabelError,
    };

    return _titleCaseMessage(
      base,
      Localizations.localeOf(context).toString(),
    );
  }

  static Color _statusColor(BuildContext context, OutboxStatus status) {
    return switch (status) {
      OutboxStatus.pending => Theme.of(context).colorScheme.tertiary,
      OutboxStatus.sent => Theme.of(context).colorScheme.primary,
      OutboxStatus.error => Theme.of(context).colorScheme.error,
    };
  }

  static IconData _statusIcon(OutboxStatus status) {
    return switch (status) {
      OutboxStatus.pending => Icons.schedule_rounded,
      OutboxStatus.sent => Icons.check_circle_outline_rounded,
      OutboxStatus.error => Icons.error_outline_rounded,
    };
  }

  static IconData _statusChipIcon(OutboxStatus status) {
    return switch (status) {
      OutboxStatus.pending => Icons.pending_actions_rounded,
      OutboxStatus.sent => Icons.outbox_rounded,
      OutboxStatus.error => Icons.report_rounded,
    };
  }

  static String _retriesLabel(BuildContext context, int retries) {
    final locale = Localizations.localeOf(context).toString();
    final numberFormat = NumberFormat.decimalPattern(locale);
    final base = retries == 1
        ? context.messages.outboxMonitorRetry
        : context.messages.outboxMonitorRetries;

    final formattedBase = _titleCaseMessage(base, locale);
    return '${numberFormat.format(retries)} $formattedBase';
  }

  static String _payloadKind(BuildContext context, String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        return context.messages.syncListUnknownPayload;
      }
      final syncMessage = SyncMessage.fromJson(decoded);

      return syncMessage.map(
        journalEntity: (_) => context.messages.syncPayloadJournalEntity,
        entityDefinition: (_) => context.messages.syncPayloadEntityDefinition,
        tagEntity: (_) => context.messages.syncPayloadTagEntity,
        entryLink: (_) => context.messages.syncPayloadEntryLink,
        aiConfig: (_) => context.messages.syncPayloadAiConfig,
        aiConfigDelete: (_) => context.messages.syncPayloadAiConfigDelete,
      );
    } catch (_) {
      return context.messages.syncListUnknownPayload;
    }
  }

  static String _titleCaseMessage(
    String value,
    String locale,
  ) {
    final formatted = toBeginningOfSentenceCase(value, locale);
    return formatted;
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: AppTheme.letterSpacingSubtitle,
    );
    final valueStyle = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: AppTheme.letterSpacingSubtitle,
      height: AppTheme.lineHeightSubtitle,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: AppTheme.iconSizeCompact,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTheme.alphaSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSmall),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label: ', style: labelStyle),
                TextSpan(text: value, style: valueStyle),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
