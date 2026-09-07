import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

/// Locale-specific scene copy, composed from structured task facts. Titles and
/// category names remain user data; all framing text comes from the catalogs.
class PlazaCopy {
  PlazaCopy(this.messages) {
    // The bundled intl initializer installs tables synchronously and returns
    // a completed future. CPU generators also need it before an app is mounted.
    unawaited(_dateSymbols);
  }

  final AppLocalizations messages;
  static final Future<void> _dateSymbols = initializeDateFormatting();
  late final DateFormat _dateFormat = DateFormat.MMMd(messages.localeName);

  /// Default for standalone CPU scene fixtures. App routes pass their locale.
  static final english = PlazaCopy(AppLocalizationsEn());

  String date(DateTime date) => _dateFormat.format(date);

  String state(TaskAttention a) {
    final project = a.task.project;
    if (project != null) {
      return switch (project.state) {
        PlazaProjectState.open => messages.projectStatusOpen,
        PlazaProjectState.active => messages.projectStatusActive,
        PlazaProjectState.monitoring => messages.projectStatusMonitoring,
        PlazaProjectState.onHold => messages.projectStatusOnHold,
        PlazaProjectState.completed => messages.projectStatusCompleted,
        PlazaProjectState.archived => messages.projectStatusArchived,
      };
    }
    if (a.task.state == PlazaTaskState.blocked) {
      return messages.taskStatusBlocked;
    }
    if (a.overdue) return messages.projectTasksDueOverdue;
    return switch (a.task.state) {
      PlazaTaskState.open => messages.taskStatusOpen,
      PlazaTaskState.inProgress => messages.taskStatusInProgress,
      PlazaTaskState.blocked => messages.taskStatusBlocked,
      PlazaTaskState.done => messages.taskStatusDone,
      PlazaTaskState.cancelled => messages.eventsStatusCancelled,
    };
  }

  String reason(TaskAttention a) {
    if (a.task.deleted ||
        a.task.state == PlazaTaskState.done ||
        a.task.state == PlazaTaskState.cancelled) {
      return '';
    }
    final project = a.task.project;
    if (project != null) {
      if (project.overdueCount > 0) {
        return messages.plazaProjectOverdue(project.overdueCount);
      }
      if (project.attentionCount > 0) {
        return messages.plazaNeedsAttention(project.attentionCount);
      }
    }
    if (a.task.state == PlazaTaskState.blocked) {
      return messages.plazaBlockedReason;
    }
    if (a.overdue) return messages.plazaOverdueSince(date(a.task.due!));
    if (a.stale) return messages.plazaStaleReason(a.daysSinceActivity);
    if (a.dueSoon) return messages.plazaDueSoonReason(date(a.task.due!));
    return '';
  }

  List<String> metaBits(PlazaTask task) => [
    if (task.project case final project?) ...[
      messages.plazaTaskCount(project.taskCount),
      messages.plazaDoneCount(project.doneCount, project.taskCount),
    ],
    if (task.due != null) messages.plazaDueOn(date(task.due!)),
    if (task.linkedTaskIds.isNotEmpty)
      messages.plazaLinks(task.linkedTaskIds.length),
  ];

  String week(DateTime epoch, int bucket) => messages.plazaWeek(
    bucket + 1,
    date(epoch.add(Duration(days: bucket * 7))),
  );
}
