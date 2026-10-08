import 'dart:convert';

import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// What a recording belongs to: the subject whose current state frames its
/// post-processing — the correction of its transcript against the speech
/// dictionary, and its summary.
///
/// Separate from the `linkedTaskId` the runner carries, which stays a task
/// id only: that id also feeds task JSON, attribution and the task's stale
/// notification, none of which a goal or a person may receive.
sealed class RecordingSubject {
  const RecordingSubject(this.id);

  /// The subject entity's id.
  final String id;
}

final class TaskRecordingSubject extends RecordingSubject {
  const TaskRecordingSubject(super.id);
}

final class ProjectRecordingSubject extends RecordingSubject {
  const ProjectRecordingSubject(super.id);
}

/// A person. A check-in's recording resolves to the person it is about.
final class RelationshipRecordingSubject extends RecordingSubject {
  const RelationshipRecordingSubject(super.id);
}

/// A goal, by its journal entry's id.
final class GoalRecordingSubject extends RecordingSubject {
  const GoalRecordingSubject(super.id);
}

final class EventRecordingSubject extends RecordingSubject {
  const EventRecordingSubject(super.id);
}

/// The subject's state as the post-processing prompt shows it.
///
/// Bounded like the task's frame always was: a small header and the
/// subject agent's current report — never the subject's log, other
/// recordings' transcripts, or anything else that grows without limit.
class RecordingContext {
  const RecordingContext({
    required this.label,
    required this.reportHeading,
    this.headerJson,
    this.report,
  });

  /// What the subject is, as the prompt names it ("Task", "Goal", …).
  final String label;

  /// The heading the report goes under ("Task Report", …).
  final String reportHeading;

  /// The subject's title and the like, as JSON, or null when unknown.
  final String? headerJson;

  /// The subject agent's current report, or null when it has none.
  final String? report;
}

/// Resolves a recording's [RecordingSubject] and the [RecordingContext] that
/// frames its post-processing.
///
/// Reads agent reports through [AgentRepository], the one
/// [TaskSummaryResolver] reads; with no agent system every subject still gets
/// its header, and only the report is missing.
class RecordingContextResolver {
  RecordingContextResolver({
    required this._journalRepository,
    required this._aiInputRepository,
    required this._taskSummaryResolver,
    required this._agentRepository,
    required this._domainLogger,
  });

  final JournalRepository _journalRepository;
  final AiInputRepository _aiInputRepository;
  final TaskSummaryResolver _taskSummaryResolver;
  final AgentRepository? _agentRepository;
  final DomainLogger _domainLogger;

  static const _logTag = 'RecordingContextResolver';
  static const _json = JsonEncoder.withIndent('    ');

  /// The subject of the recording [audioEntryId]: the task in
  /// [linkedTaskId] when there is one, else the entity that links to the
  /// recording — a person (directly, or through a check-in about them), a
  /// goal, a project or an event, in that order. Null when nothing frames
  /// it; the dictionary alone then corrects the transcript.
  Future<RecordingSubject?> subjectOf(
    String audioEntryId, {
    String? linkedTaskId,
  }) async {
    if (linkedTaskId != null) return TaskRecordingSubject(linkedTaskId);
    final List<JournalEntity> parents;
    try {
      parents = await _journalRepository.getLinkedToEntities(
        linkedTo: audioEntryId,
      );
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: _logTag,
        message: 'subject lookup failed for $audioEntryId',
      );
      return null;
    }
    RecordingSubject? firstOf(RecordingSubject? Function(JournalEntity) map) {
      for (final parent in parents) {
        if (parent.meta.deletedAt != null) continue;
        final subject = map(parent);
        if (subject != null) return subject;
      }
      return null;
    }

    return firstOf(
          (p) => p is Task ? TaskRecordingSubject(p.meta.id) : null,
        ) ??
        firstOf(
          (p) => switch (p) {
            RelationshipEntry() => RelationshipRecordingSubject(p.meta.id),
            CheckInEntry() => RelationshipRecordingSubject(
              p.data.relationshipId,
            ),
            _ => null,
          },
        ) ??
        firstOf(
          (p) => p is GoalEntry ? GoalRecordingSubject(p.meta.id) : null,
        ) ??
        firstOf(
          (p) => p is ProjectEntry ? ProjectRecordingSubject(p.meta.id) : null,
        ) ??
        firstOf(
          (p) => p is JournalEvent ? EventRecordingSubject(p.meta.id) : null,
        );
  }

  /// The frame for [subject], or null when its entity is gone.
  Future<RecordingContext?> contextFor(RecordingSubject subject) async {
    final entity = await _aiInputRepository.getEntity(subject.id);
    if (entity == null || entity.meta.deletedAt != null) return null;
    return switch ((subject, entity)) {
      (TaskRecordingSubject(), final Task task) => RecordingContext(
        label: 'Task',
        reportHeading: 'Task Report',
        headerJson: _json.convert({
          'title': task.data.title,
          'languageCode': task.data.languageCode,
        }),
        report: await _taskSummaryResolver.resolve(
          subject.id,
          fullReport: true,
        ),
      ),
      (ProjectRecordingSubject(), final ProjectEntry project) =>
        RecordingContext(
          label: 'Project',
          reportHeading: 'Project Report',
          headerJson: _json.convert({'title': project.data.title}),
          report: _reportBody(
            await _guarded(
              subject,
              (repo) => repo.getLatestProjectReportForProjectId(subject.id),
            ),
          ),
        ),
      (RelationshipRecordingSubject(), final RelationshipEntry person) =>
        RecordingContext(
          label: 'Person',
          reportHeading: 'Relationship Briefing',
          headerJson: _json.convert({
            'name': person.data.title,
            'nickname': ?person.data.nickname,
            'languageCode': person.data.languageCode,
          }),
          report: _reportBody(
            await _latestReport(
              subject,
              AgentLinkTypes.agentRelationship,
            ),
          ),
        ),
      (GoalRecordingSubject(), final GoalEntry goal) => RecordingContext(
        label: 'Goal',
        reportHeading: 'Goal Report',
        headerJson: _json.convert({
          'title': goal.data.title,
          'statement': goal.data.statement,
        }),
        // A report written for a superseded statement of the goal must not
        // frame a recording about the revised one.
        report: _reportBody(
          switch (await _latestReport(subject, AgentLinkTypes.agentGoal)) {
            final report?
                when report.provenance['specVersionId'] ==
                    goal.data.specVersionId =>
              report,
            _ => null,
          },
        ),
      ),
      (EventRecordingSubject(), final JournalEvent event) => RecordingContext(
        label: 'Event',
        reportHeading: 'Event Report',
        headerJson: _json.convert({'title': event.data.title}),
        report: _reportBody(
          await _latestReport(subject, AgentLinkTypes.agentEvent),
        ),
      ),
      _ => null,
    };
  }

  /// The current report of the newest agent linked to [subject] by
  /// [linkType].
  Future<AgentReportEntity?> _latestReport(
    RecordingSubject subject,
    String linkType,
  ) => _guarded(subject, (repo) async {
    final links = await repo.getLinksTo(subject.id, type: linkType);
    if (links.isEmpty) return null;
    links.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return repo.getLatestReport(links.first.fromId, AgentReportScopes.current);
  });

  /// Runs [read] against the agent repository; a failure is logged and
  /// leaves the frame without its report rather than failing the step.
  Future<AgentReportEntity?> _guarded(
    RecordingSubject subject,
    Future<AgentReportEntity?> Function(AgentRepository repo) read,
  ) async {
    final repo = _agentRepository;
    if (repo == null) return null;
    try {
      return await read(repo);
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: _logTag,
        message: 'report lookup failed for ${subject.id}',
      );
      return null;
    }
  }

  /// The report's body, falling back to its TLDR; null when both are empty.
  String? _reportBody(AgentReportEntity? report) {
    if (report == null) return null;
    final content = report.content.trim();
    if (content.isNotEmpty) return content;
    final tldr = report.tldr?.trim() ?? '';
    return tldr.isEmpty ? null : tldr;
  }
}
