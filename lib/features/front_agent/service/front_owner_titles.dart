import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';

/// The title of a destination at the time a segment is walked: a task's or
/// project's title, a person's name, a goal's statement from its spec head.
/// Stored on the door record so the thread can say where a segment went
/// without a lookup, even once the owner is renamed or gone.
class FrontOwnerTitles {
  const FrontOwnerTitles({
    required JournalDb journalDb,
    required AgentRepository agentRepository,
  }) : this._(journalDb, agentRepository);

  const FrontOwnerTitles._(this._journalDb, this._agentRepository);

  final JournalDb _journalDb;
  final AgentRepository _agentRepository;

  /// Null when the owner cannot be found, when the row under [id] is not
  /// of [kind] — a dispatch that names a person's id as a task gets no
  /// title rather than the wrong one — or when the kind has no owner.
  Future<String?> titleFor(FrontDestinationKind kind, String id) async {
    switch (kind) {
      case FrontDestinationKind.task:
      case FrontDestinationKind.project:
      case FrontDestinationKind.person:
        return switch ((kind, await _journalDb.journalEntityById(id))) {
          (FrontDestinationKind.task, final Task task) => task.data.title,
          (FrontDestinationKind.project, final ProjectEntry project) =>
            project.data.title,
          (FrontDestinationKind.person, final RelationshipEntry person) =>
            person.data.title,
          _ => null,
        };
      case FrontDestinationKind.goal:
        final head = await _agentRepository.getEntity(goalSpecHeadId(id));
        if (head is! GoalSpecHeadEntity || head.deletedAt != null) return null;
        return switch (await _agentRepository.getEntity(head.versionId)) {
          final GoalSpecVersionEntity version => version.statement,
          _ => null,
        };
      case FrontDestinationKind.day:
      case FrontDestinationKind.newThing:
      case FrontDestinationKind.journal:
      case FrontDestinationKind.unrouted:
        return null;
    }
  }
}
