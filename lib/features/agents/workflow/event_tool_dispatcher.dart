import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:uuid/uuid.dart';

/// Applies confirmed event-agent proposals.
///
/// The event agent's only write-action (v1) is `suggest_follow_up_task`, a
/// deferred proposal. When the user accepts it, [dispatch] creates a follow-up
/// task linked to the event (inheriting the event's category and default
/// profile), mirroring the manual "add task" flow on the event detail page.
///
/// The dispatcher never touches the event's rating or cover — there is no tool
/// that can, by design.
class EventToolDispatcher {
  EventToolDispatcher({
    required this.journalRepository,
    required this.persistenceLogic,
    required this.entitiesCacheService,
    this.domainLogger,
  });

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
    switch (toolName) {
      case EventAgentToolNames.suggestFollowUpTask:
        return _handleSuggestFollowUpTask(args, eventId);
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
    );

    if (task == null) {
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
}
