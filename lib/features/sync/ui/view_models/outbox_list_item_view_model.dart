import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class OutboxListItemViewModel {
  const OutboxListItemViewModel({
    required this.timestampLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.statusChipIcon,
    required this.payloadKindLabel,
    required this.retriesLabel,
    required this.attachmentValue,
    required this.attachmentIcon,
    required this.semanticsLabel,
    required this.retryButtonLabel,
    this.subjectValue,
  });
  factory OutboxListItemViewModel.fromItem({
    required BuildContext context,
    required OutboxItem item,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final statusIndex = item.status;
    final status = statusIndex >= 0 && statusIndex < OutboxStatus.values.length
        ? OutboxStatus.values[statusIndex]
        : OutboxStatus.values.first;
    final messages = context.messages;

    final timestamp = df.format(item.createdAt);
    final statusLabel = _titleCase(
      switch (status) {
        OutboxStatus.pending => messages.outboxMonitorLabelPending,
        OutboxStatus.sent => messages.outboxMonitorLabelSent,
        OutboxStatus.error => messages.outboxMonitorLabelError,
      },
      locale,
    );

    final statusColor = switch (status) {
      OutboxStatus.pending => theme.colorScheme.tertiary,
      OutboxStatus.sent => theme.colorScheme.primary,
      OutboxStatus.error => theme.colorScheme.error,
    };

    final statusIcon = switch (status) {
      OutboxStatus.pending => Icons.schedule_rounded,
      OutboxStatus.sent => Icons.check_circle_outline_rounded,
      OutboxStatus.error => Icons.error_outline_rounded,
    };

    final statusChipIcon = switch (status) {
      OutboxStatus.pending => Icons.pending_actions_rounded,
      OutboxStatus.sent => Icons.outbox_rounded,
      OutboxStatus.error => Icons.report_rounded,
    };

    final retriesLabel = _buildRetriesLabel(
      retryCount: item.retries,
      locale: locale,
      messages: messages,
    );

    final payloadKind = _payloadKindLabel(
      context: context,
      message: item.message,
    );

    final trimmedSubject = item.subject.trim();
    final subjectValue = trimmedSubject.isEmpty ? null : trimmedSubject;

    final trimmedAttachment = item.filePath?.trim();
    final hasAttachment =
        trimmedAttachment != null && trimmedAttachment.isNotEmpty;
    final attachmentValue = hasAttachment
        ? trimmedAttachment
        : _titleCase(messages.outboxMonitorNoAttachment, locale);

    final attachmentIcon =
        hasAttachment ? Icons.attachment_rounded : Icons.block_outlined;

    final semanticsLabel =
        '$statusLabel, $timestamp, ${payloadKind.toLowerCase()}';

    final retryButtonLabel = _titleCase(messages.outboxMonitorRetry, locale);

    return OutboxListItemViewModel(
      timestampLabel: timestamp,
      statusLabel: statusLabel,
      statusColor: statusColor,
      statusIcon: statusIcon,
      statusChipIcon: statusChipIcon,
      payloadKindLabel: payloadKind,
      retriesLabel: retriesLabel,
      subjectValue: subjectValue,
      attachmentValue: attachmentValue,
      attachmentIcon: attachmentIcon,
      semanticsLabel: semanticsLabel,
      retryButtonLabel: retryButtonLabel,
    );
  }

  final String timestampLabel;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final IconData statusChipIcon;
  final String payloadKindLabel;
  final String retriesLabel;
  final String attachmentValue;
  final IconData attachmentIcon;
  final String semanticsLabel;
  final String retryButtonLabel;
  final String? subjectValue;

  static String _buildRetriesLabel({
    required int retryCount,
    required String locale,
    required AppLocalizations messages,
  }) {
    final numberFormat = NumberFormat.decimalPattern(locale);
    final base = retryCount == 1
        ? messages.outboxMonitorRetry
        : messages.outboxMonitorRetries;
    final formattedLabel = _titleCase(base, locale);
    return '${numberFormat.format(retryCount)} $formattedLabel';
  }

  static String _payloadKindLabel({
    required BuildContext context,
    required String message,
  }) {
    final messages = context.messages;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        return messages.syncListUnknownPayload;
      }
      final syncMessage = SyncMessage.fromJson(decoded);
      return syncMessage.map(
        journalEntity: (_) => messages.syncPayloadJournalEntity,
        entityDefinition: (_) => messages.syncPayloadEntityDefinition,
        tagEntity: (_) => messages.syncPayloadTagEntity,
        entryLink: (_) => messages.syncPayloadEntryLink,
        aiConfig: (_) => messages.syncPayloadAiConfig,
        aiConfigDelete: (_) => messages.syncPayloadAiConfigDelete,
        themingSelection: (_) => 'Theming Selection',
      );
    } catch (_) {
      return messages.syncListUnknownPayload;
    }
  }

  static String _titleCase(String value, String locale) {
    final String? formatted = toBeginningOfSentenceCase(value, locale);
    return formatted ?? value;
  }
}
