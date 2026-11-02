import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';

/// Where one person stands for the event the agent is narrating.
enum EventPersonStanding {
  /// Not with the event, never suggested for it — free to suggest.
  open,

  /// Already with the event: their timeline holds it.
  withEvent,

  /// Suggested before and still waiting for the user.
  suggested,

  /// Suggested before and dismissed by the user — never again.
  dismissed,
}

/// One person the user keeps, as the event agent sees them.
class EventKnownPerson {
  const EventKnownPerson({
    required this.id,
    required this.name,
    this.nickname,
  });

  final String id;
  final String name;
  final String? nickname;
}

/// Everyone on the People page, and where each stands for one event — what
/// the event agent's `list_people` answers, and what `suggest_person` is
/// checked against before a suggestion reaches the user.
///
/// The agent matches the names it reads in the event's notes, voice memos and
/// photo captions against this list itself; the directory only says who
/// exists and who is already with the event, suggested, or dismissed. A
/// private person is absent while private entries are hidden, so a
/// suggestion row never shows a name the page would hide.
class EventPeopleDirectory {
  EventPeopleDirectory({
    required List<EventKnownPerson> people,
    Set<String> withEventIds = const {},
    Set<String> suggestedIds = const {},
    Set<String> dismissedIds = const {},
  }) : people = List.unmodifiable(people),
       _byId = {for (final person in people) person.id: person},
       _withEvent = withEventIds,
       _suggested = suggestedIds,
       _dismissed = dismissedIds;

  /// How far back [load] reads this agent's pending change sets and
  /// decisions for the event.
  ///
  /// The repository's defaults (20 sets, 50 decisions) are display windows,
  /// and follow-up proposals use them up too; a dismissal or a pending
  /// suggestion that fell outside them would read as open and be proposed
  /// again. One event's proposals stay far below this, so in practice it
  /// reads them all.
  static const historyWindow = 1000;

  /// Everyone the user keeps, by name.
  final List<EventKnownPerson> people;
  final Map<String, EventKnownPerson> _byId;
  final Set<String> _withEvent;
  final Set<String> _suggested;
  final Set<String> _dismissed;

  /// Reads the directory for [eventId] as [agentId] sees it: the people
  /// (private-filtered), the people whose live `RelationshipLink` runs to the
  /// event, and the people this agent has suggested for it — still pending,
  /// or dismissed.
  static Future<EventPeopleDirectory> load({
    required JournalRepository journalRepository,
    required AgentRepository agentRepository,
    required String agentId,
    required String eventId,
  }) async {
    final relationships = await journalRepository.getRelationships();
    final people = [
      for (final person in relationships)
        if (person.meta.deletedAt == null)
          EventKnownPerson(
            id: person.meta.id,
            name: person.data.title.trim(),
            nickname: person.data.nickname?.trim(),
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final suggested = <String>{};
    for (final changeSet in await agentRepository.getPendingChangeSets(
      agentId,
      taskId: eventId,
      limit: historyWindow,
    )) {
      for (final item in changeSet.items) {
        if (item.toolName == EventAgentToolNames.suggestPerson &&
            item.status == ChangeItemStatus.pending) {
          if (item.args[EventAgentPersonToolArgs.personId]
              case final String id) {
            suggested.add(id);
          }
        }
      }
    }

    final dismissed = <String>{
      for (final decision in await agentRepository.getChangeDecisions(
        agentId,
        taskId: eventId,
        limit: historyWindow,
      ))
        if (decision.toolName == EventAgentToolNames.suggestPerson &&
            decision.verdict == ChangeDecisionVerdict.rejected)
          if (decision.args?[EventAgentPersonToolArgs.personId]
              case final String id)
            id,
    };

    return EventPeopleDirectory(
      people: people,
      withEventIds: await eventPersonLinkSources(journalRepository, eventId),
      suggestedIds: suggested,
      dismissedIds: dismissed,
    );
  }

  EventKnownPerson? byId(String id) => _byId[id];

  /// Where [id] stands for the event. A dismissal outranks a pending
  /// suggestion, and being with the event outranks both.
  EventPersonStanding standingOf(String id) {
    if (_withEvent.contains(id)) return EventPersonStanding.withEvent;
    if (_dismissed.contains(id)) return EventPersonStanding.dismissed;
    if (_suggested.contains(id)) return EventPersonStanding.suggested;
    return EventPersonStanding.open;
  }

  /// The `list_people` answer: one line per person — id, name, nickname and,
  /// when it is not open, their standing — narrowed to names or nicknames
  /// containing [query] when one is given.
  String render({String? query}) {
    final q = query?.trim().toLowerCase() ?? '';
    final lines = [
      for (final person in people)
        if (q.isEmpty ||
            person.name.toLowerCase().contains(q) ||
            (person.nickname?.toLowerCase().contains(q) ?? false))
          _line(person),
    ];
    if (lines.isEmpty) {
      return q.isEmpty
          ? 'The user keeps no people yet.'
          : 'No person matches "${query!.trim()}".';
    }
    return lines.join('\n');
  }

  String _line(EventKnownPerson person) {
    final nickname = person.nickname;
    final names =
        nickname == null || nickname.isEmpty || nickname == person.name
        ? person.name
        : '${person.name} (called "$nickname")';
    final standing = switch (standingOf(person.id)) {
      EventPersonStanding.open => '',
      EventPersonStanding.withEvent => ' — already with this event',
      EventPersonStanding.suggested =>
        ' — already suggested, awaiting the user',
      EventPersonStanding.dismissed =>
        ' — dismissed by the user for this event',
    };
    return '- ${person.id}: $names$standing';
  }
}

/// The people whose live `RelationshipLink` runs to [eventId] — the rows that
/// also put the event on each person's timeline. Read through the journal,
/// since the relationships feature ranks above agents.
Future<Set<String>> eventPersonLinkSources(
  JournalRepository journalRepository,
  String eventId,
) async {
  final links = await journalRepository.getTypedLinksForTaskIds(
    {eventId},
    linkTypes: {entryLinkTypeDbName(EntryLinkType.relationship)},
  );
  return {
    for (final link in links)
      if (link.toId == eventId && link.deletedAt == null && link.hidden != true)
        link.fromId,
  };
}
