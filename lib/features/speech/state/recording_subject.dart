import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/providers/service_providers.dart';

/// What a recording is about, as the recording strip and its receipt name
/// it: the title of the task, project, goal or person it is linked to, else
/// the first words of the entry. Null when there is nothing to name.
String? recordingSubjectTitle(JournalEntity? subject) {
  final title = switch (subject) {
    Task(:final data) => data.title,
    ProjectEntry(:final data) => data.title,
    GoalEntry(:final data) => data.title,
    RelationshipEntry(:final data) => data.title,
    _ => subject?.entryText?.plainText,
  }?.trim();
  return title == null || title.isEmpty ? null : title;
}

/// The entry a take is linked to, by id; null once it is deleted, or when it
/// cannot be read.
final FutureProviderFamily<JournalEntity?, String> recordingSubjectProvider =
    FutureProvider.autoDispose.family<JournalEntity?, String>(
      (ref, id) async {
        try {
          return await ref.read(journalDbProvider).journalEntityById(id);
        } catch (_) {
          // A subject that cannot be read is named like a deleted one.
          return null;
        }
      },
      name: 'recordingSubjectProvider',
    );

/// The subject's own page, by its kind, for a way back whose original route
/// no longer resolves. Null for a kind with no page of its own by entry id —
/// a goal's page is keyed by its agent.
String? recordingSubjectRoute(JournalEntity subject) => switch (subject) {
  Task() => '/tasks/${subject.id}',
  ProjectEntry() => '/projects/${subject.id}',
  RelationshipEntry() => '/people/${subject.id}',
  GoalEntry() => null,
  _ => '/journal/${subject.id}',
};
