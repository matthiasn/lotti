import 'dart:ui' as ui;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Keeps task-suggestion inbox rows aligned with the backing change set.
///
/// Agent proposals are persisted in the agent database, while inbox rows live
/// in the notifications database. This service is the explicit bridge between
/// those stores: when a change-set item is resolved, the task-scoped
/// suggestion row is either refreshed with the remaining pending count or every
/// open row for the task is removed from the inbox through a monotonic
/// lifecycle state.
class ChangeSetNotificationService {
  const ChangeSetNotificationService({
    required NotificationRepository notificationRepository,
    required JournalDb journalDb,
  }) : _notificationRepository = notificationRepository,
       _journalDb = journalDb;

  final NotificationRepository _notificationRepository;
  final JournalDb _journalDb;

  /// Reflects a user confirm/reject decision in the task-suggestion inbox.
  Future<void> syncAfterUserDecision(ChangeSetEntity changeSet) {
    return _sync(
      changeSet,
      onResolved: _notificationRepository.markTaskSuggestionsActedOn,
    );
  }

  /// Reflects an agent-autonomous retraction in the task-suggestion inbox.
  Future<void> syncAfterAgentRetraction(ChangeSetEntity changeSet) {
    return _sync(
      changeSet,
      onResolved: _notificationRepository.retractTaskSuggestionsForTask,
    );
  }

  Future<void> _sync(
    ChangeSetEntity changeSet, {
    required Future<List<NotificationEntity>> Function(String linkedTaskId)
    onResolved,
  }) async {
    final pendingCount = changeSet.items
        .where((item) => item.status == ChangeItemStatus.pending)
        .length;

    if (pendingCount == 0) {
      await onResolved(changeSet.taskId);
      return;
    }

    final task = await _journalDb.journalEntityById(changeSet.taskId);
    final taskTitle = task is Task ? task.data.title : null;
    final messages = lookupAppLocalizations(
      _resolveSupportedLocale(ui.PlatformDispatcher.instance.locale),
    );
    final body = taskTitle == null || taskTitle.trim().isEmpty
        ? messages.notificationSuggestionAttentionBodyFallback
        : taskTitle;

    await _notificationRepository.createTaskSuggestion(
      linkedTaskId: changeSet.taskId,
      suggestionCount: pendingCount,
      title: messages.notificationSuggestionAttentionTitle(pendingCount),
      body: body,
      category: task is Task ? task.meta.categoryId : null,
      idSeed: changeSet.id,
    );
  }
}

ui.Locale _resolveSupportedLocale(ui.Locale locale) {
  const supportedLocales = AppLocalizations.supportedLocales;

  for (final supportedLocale in supportedLocales) {
    if (_isExactLocaleMatch(supportedLocale, locale)) {
      return supportedLocale;
    }
  }

  for (final supportedLocale in supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode) {
      return supportedLocale;
    }
  }

  return supportedLocales.first;
}

bool _isExactLocaleMatch(ui.Locale a, ui.Locale b) {
  return a.languageCode == b.languageCode &&
      a.scriptCode == b.scriptCode &&
      a.countryCode == b.countryCode;
}
