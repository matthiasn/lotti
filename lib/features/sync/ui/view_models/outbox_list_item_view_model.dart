import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class OutboxListItemViewModel {
  const OutboxListItemViewModel({
    required this.timestampLabel,
    required this.payloadKindLabel,
    required this.retriesLabel,
    required this.attachmentValue,
    this.subjectValue,
    this.payloadSizeLabel,
  });
  factory OutboxListItemViewModel.fromItem({
    required BuildContext context,
    required OutboxItem item,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final messages = context.messages;

    final timestamp = df.format(item.createdAt);

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

    return OutboxListItemViewModel(
      timestampLabel: timestamp,
      payloadKindLabel: payloadKind,
      retriesLabel: retriesLabel,
      subjectValue: subjectValue,
      attachmentValue: attachmentValue,
      payloadSizeLabel: formatBytes(item.payloadSize),
    );
  }

  final String timestampLabel;
  final String payloadKindLabel;
  final String retriesLabel;
  final String attachmentValue;
  final String? subjectValue;
  final String? payloadSizeLabel;

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
        entryLink: (_) => messages.syncPayloadEntryLink,
        aiConfig: (_) => messages.syncPayloadAiConfig,
        aiConfigDelete: (_) => messages.syncPayloadAiConfigDelete,
        savedTaskFilter: (_) => messages.syncPayloadSavedTaskFilter,
        savedTaskFilterDelete: (_) => messages.syncPayloadSavedTaskFilterDelete,
        configFlag: (_) => messages.syncPayloadConfigFlag,
        themingSelection: (_) => messages.syncPayloadThemingSelection,
        dailyOsUserName: (_) => messages.syncPayloadDailyOsUserName,
        notification: (_) => messages.syncPayloadNotification,
        notificationStateUpdate: (_) =>
            messages.syncPayloadNotificationStateUpdate,
        onboardingSnapshotBegin: (_) => messages.syncListUnknownPayload,
        onboardingSnapshotAccepted: (_) => messages.syncListUnknownPayload,
        onboardingTerminalCounters: (_) => messages.syncListUnknownPayload,
        onboardingSnapshotEnd: (_) => messages.syncListUnknownPayload,
        consumptionEvent: (_) => messages.syncPayloadConsumptionEvent,
        backfillRequest: (_) => messages.syncPayloadBackfillRequest,
        mediaRequest: (_) => messages.syncPayloadMediaRequest,
        backfillResponse: (_) => messages.syncPayloadBackfillResponse,
        agentEntity: (_) => messages.syncPayloadAgentEntity,
        agentLink: (_) => messages.syncPayloadAgentLink,
        agentBundle: (_) => messages.syncPayloadAgentBundle,
        // Surface the bundle's child count so the outbox list shows e.g.
        // "Outbox bundle (12)" — at a glance the user sees how many small
        // text-only updates a single envelope carries.
        outboxBundle: (b) =>
            '${messages.syncPayloadOutboxBundle} (${b.children.length})',
        syncNodeProfile: (_) => messages.syncPayloadSyncNodeProfile,
      );
    } catch (_) {
      return messages.syncListUnknownPayload;
    }
  }

  /// Formats a byte count with B/KB/MB/GB thresholds; null in, null out.
  @visibleForTesting
  static String? formatBytes(int? bytes) {
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _titleCase(String value, String locale) {
    final String? formatted = toBeginningOfSentenceCase(value, locale);
    return formatted ?? value;
  }
}
