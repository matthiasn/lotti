import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/tools/ensure_link.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:uuid/uuid.dart';

/// Applies confirmed event-agent proposals.
///
/// Three deferred proposals reach it on accept:
/// - `suggest_follow_up_task` creates a follow-up task linked to the event
///   (inheriting the event's category and default profile), mirroring the
///   manual "add task" flow on the event detail page.
/// - `suggest_person` puts the event on the person's timeline: the
///   `RelationshipLink` from the person to the event, the same link the
///   event page's People row writes, so the person appears there.
/// - `suggest_note` adds the note to the event's timeline as the user's own:
///   a text entry linked from the event, in its category, as the Add sheet's
///   note would be.
///
/// The dispatcher never touches the event's rating or cover — there is no tool
/// that can, by design.
///
/// A confirmed proposal's task or note gets an id derived from the change
/// item ([ChangeEffect]), so the same proposal accepted on two devices before
/// they sync creates one entry.
class EventToolDispatcher {
  EventToolDispatcher({
    required this.journalDb,
    required this.journalRepository,
    required this.persistenceLogic,
    required this.entitiesCacheService,
    this.domainLogger,
  });

  final JournalDb journalDb;
  final JournalRepository journalRepository;
  final PersistenceLogic persistenceLogic;
  final EntitiesCacheService entitiesCacheService;
  final DomainLogger? domainLogger;

  static const _uuid = Uuid();

  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String eventId,
  ) async {
    final (:effect, args: toolArgs) = ChangeEffect.takeFrom(args);
    switch (toolName) {
      case EventAgentToolNames.suggestFollowUpTask:
        return _handleSuggestFollowUpTask(toolArgs, eventId, effect);
      case EventAgentToolNames.suggestPerson:
        return _handleSuggestPerson(toolArgs, eventId);
      case EventAgentToolNames.suggestNote:
        return _handleSuggestNote(toolArgs, eventId, effect);
      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage: 'Tool $toolName is not registered for the Event Agent',
        );
    }
  }

  Future<ToolExecutionResult> _handleSuggestFollowUpTask(
    Map<String, dynamic> args,
    String eventId,
    ChangeEffect? effect,
  ) async {
    final titleValue = args['title'];
    if (titleValue is! String || titleValue.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a non-empty string',
        errorMessage: 'Missing or empty title',
      );
    }
    final title = titleValue.trim();

    final event = await journalRepository.getJournalEntityById(eventId);
    // Guard against accept-after-delete: if the event is gone (or soft-deleted)
    // we must not create an orphaned, uncategorized, unlinked task. Refuse so
    // the proposal stays unresolved rather than silently dropping a task.
    if (event == null || event.meta.deletedAt != null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: event $eventId no longer exists',
        errorMessage: 'Event missing or deleted; follow-up not created',
      );
    }

    if (await _createdBefore(effect, _taskRole, eventId, 'Follow-up task')
        case final ToolExecutionResult existing) {
      return existing;
    }

    final categoryId = event.meta.categoryId;
    final category = categoryId != null
        ? entitiesCacheService.getCategoryById(categoryId)
        : null;

    final notes = args['notes'] is String ? args['notes'] as String : '';
    final now = clock.now();

    final task = await persistenceLogic.createTaskEntry(
      data: TaskData(
        status: TaskStatus.open(
          id: _uuid.v1(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: title,
        profileId: category?.defaultProfileId,
      ),
      entryText: EntryText(plainText: notes),
      // Links the new task to the event so it shows under the event's tasks.
      linkedId: eventId,
      categoryId: categoryId,
      uuidV5Input: effect?.entityInput(_taskRole),
    );

    if (task == null) {
      // The insert refuses an id that exists: the other device's task can
      // have arrived between the check above and the write.
      if (await _createdBefore(effect, _taskRole, eventId, 'Follow-up task')
          case final ToolExecutionResult existing) {
        return existing;
      }
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to create the follow-up task',
        errorMessage: 'Task creation failed',
      );
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'created follow-up task ${DomainLogger.sanitizeId(task.meta.id)} '
      'for event ${DomainLogger.sanitizeId(eventId)}',
      subDomain: 'event-followup',
    );

    return ToolExecutionResult(
      success: true,
      output: 'Created follow-up task "$title" (${task.meta.id})',
      mutatedEntityId: task.meta.id,
    );
  }

  /// Adds the suggested note to the event's timeline: a text entry linked
  /// from the event, in its category, dated now — the moment the user made
  /// it theirs. Refuses while the event is gone, so the proposal stays
  /// unresolved rather than leaving a note on nothing.
  Future<ToolExecutionResult> _handleSuggestNote(
    Map<String, dynamic> args,
    String eventId,
    ChangeEffect? effect,
  ) async {
    final textValue = args[EventAgentNoteToolArgs.text];
    final text = textValue is String ? textValue.trim() : '';
    if (text.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "text" must be a non-empty string',
        errorMessage: 'Missing or empty note text',
      );
    }

    final event = await journalRepository.getJournalEntityById(eventId);
    if (event == null || event.meta.deletedAt != null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: event $eventId no longer exists',
        errorMessage: 'Event missing or deleted; note not added',
      );
    }

    if (await _createdBefore(effect, _noteRole, eventId, 'Note')
        case final ToolExecutionResult existing) {
      return existing;
    }

    final now = clock.now();
    final note = JournalEntity.journalEntry(
      entryText: EntryText(plainText: text, markdown: text),
      meta: await persistenceLogic.createMetadata(
        dateFrom: now,
        dateTo: now,
        categoryId: event.meta.categoryId,
        uuidV5Input: effect?.entityInput(_noteRole),
      ),
    );
    final stored = await persistenceLogic.createDbEntity(
      note,
      linkedId: eventId,
    );
    if (stored != true) {
      // The insert refuses an id that exists: the other device's note can
      // have arrived between the check above and the write.
      if (await _createdBefore(effect, _noteRole, eventId, 'Note')
          case final ToolExecutionResult existing) {
        return existing;
      }
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to add the note',
        errorMessage: 'Note creation failed',
      );
    }

    // `createDbEntity` reports the note stored even when its link to the
    // event was not written, and an unlinked note is not on the event's
    // timeline. Confirm the link, so a failure leaves the item to retry —
    // the retry finds the note under its derived id and links it.
    if (!await ensureLink(
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      fromId: eventId,
      toId: note.meta.id,
    )) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: note ${note.meta.id} exists but could not be linked',
        errorMessage: 'Note link failed',
      );
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'added suggested note ${DomainLogger.sanitizeId(note.meta.id)} '
      'to event ${DomainLogger.sanitizeId(eventId)}',
      subDomain: 'event-note',
    );
    return ToolExecutionResult(
      success: true,
      output: 'Added the note to the event (${note.meta.id})',
      mutatedEntityId: note.meta.id,
    );
  }

  /// Links the suggested person to the event — idempotently, so a
  /// suggestion accepted on two devices, or re-applied after a crash, writes
  /// one link. Refuses while the event or the person is gone, so the
  /// suggestion stays unresolved rather than linking a deleted entry.
  Future<ToolExecutionResult> _handleSuggestPerson(
    Map<String, dynamic> args,
    String eventId,
  ) async {
    final idValue = args[EventAgentPersonToolArgs.personId];
    final personId = idValue is String ? idValue.trim() : '';
    if (personId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "personId" must be a non-empty string',
        errorMessage: 'Missing personId',
      );
    }

    final event = await journalRepository.getJournalEntityById(eventId);
    if (event == null || event.meta.deletedAt != null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: event $eventId no longer exists',
        errorMessage: 'Event missing or deleted; person not linked',
      );
    }
    final person = await journalRepository.getJournalEntityById(personId);
    if (person is! RelationshipEntry || person.meta.deletedAt != null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: person $personId no longer exists',
        errorMessage: 'Person missing or deleted; not linked',
      );
    }

    final linked = await ensureLink(
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      fromId: personId,
      toId: eventId,
      linkType: EntryLinkType.relationship,
    );
    if (!linked || !await _showLink(personId, eventId)) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: ${person.data.title} could not be linked to the event',
        errorMessage: 'Person link failed',
      );
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'linked person ${DomainLogger.sanitizeId(personId)} '
      'to event ${DomainLogger.sanitizeId(eventId)}',
      subDomain: 'event-person',
    );
    return ToolExecutionResult(
      success: true,
      output: 'Added ${person.data.title} to the event',
      mutatedEntityId: eventId,
    );
  }

  /// Shows a live person → event link the user once hid, and answers whether
  /// every live one is shown afterwards.
  ///
  /// `ensureLink` counts a hidden link as there, yet the People row and the
  /// agent's directory leave hidden links out — so without this a confirmed
  /// suggestion would report the person added while they stay off the event.
  /// Confirming is the user asking to see them there.
  Future<bool> _showLink(String personId, String eventId) async {
    for (final link in await journalDb.linksBetween(
      personId,
      eventId,
      type: entryLinkTypeDbName(EntryLinkType.relationship),
    )) {
      if (link.deletedAt != null || link.hidden != true) continue;
      if (!await journalRepository.changeLink(
        link.id,
        (stored) => stored.copyWith(hidden: false),
      )) {
        return false;
      }
    }
    return true;
  }

  /// The role of the task in its [ChangeEffect]'s derived ids.
  static const _taskRole = 'task';

  /// The role of the note in its [ChangeEffect]'s derived ids.
  static const _noteRole = 'note';

  /// The result for the entry in [role] — a follow-up task or a note, named
  /// [what] in the result — that an earlier application of [effect]
  /// created, here, on another device, or deleted since; `null` when there
  /// is none (or no effect).
  ///
  /// The entry and its link from [eventId] are two writes, and that
  /// application can have stopped between them — the app died — so a live
  /// entry is linked to the event where it is not; the link takes its
  /// triple's derived id, so one that landed is not written twice
  /// (`specs/tla/ChangeDispatchRecovery.tla`, TailOnRerun). A link that cannot
  /// be made live fails the dispatch, retryably, so the item is not taken for
  /// applied. An entry deleted since stays deleted.
  Future<ToolExecutionResult?> _createdBefore(
    ChangeEffect? effect,
    String role,
    String eventId,
    String what,
  ) async {
    if (effect == null || !await effect.created(journalDb, role)) {
      return null;
    }
    final entryId = effect.entityId(role);
    if (await journalDb.journalEntityById(entryId) != null &&
        !await ensureLink(
          persistenceLogic: persistenceLogic,
          journalDb: journalDb,
          fromId: eventId,
          toId: entryId,
        )) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: $what $entryId exists but could not be linked',
        errorMessage: '$what link failed',
      );
    }
    return ToolExecutionResult(
      success: true,
      output: '$what already exists ($entryId)',
      mutatedEntityId: entryId,
    );
  }
}
