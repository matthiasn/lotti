import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_tool_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalRepository mockJournalRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockCache;
  late EventToolDispatcher dispatcher;

  const eventId = 'event-1';
  const categoryId = 'cat-1';
  final now = DateTime(2026, 6, 20, 19, 30);

  Metadata meta(String id, {String? categoryId}) => Metadata(
    id: id,
    createdAt: now,
    updatedAt: now,
    dateFrom: now,
    dateTo: now,
    categoryId: categoryId,
  );

  final eventEntity = JournalEntity.event(
    meta: meta(eventId, categoryId: categoryId),
    data: const EventData(
      title: 'Trip',
      stars: 0,
      status: EventStatus.completed,
    ),
  );

  final category = CategoryDefinition(
    id: categoryId,
    name: 'Travel',
    private: false,
    active: true,
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
    defaultProfileId: 'profile-1',
  );

  final createdTask = Task(
    meta: meta('task-9'),
    data: TaskData(
      title: 'Share the album',
      status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
    ),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(const EntryText(plainText: ''));
    registerFallbackValue(
      TaskData(
        title: '',
        status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
      ),
    );
  });

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockCache = MockEntitiesCacheService();
    dispatcher = EventToolDispatcher(
      journalRepository: mockJournalRepository,
      persistenceLogic: mockPersistenceLogic,
      entitiesCacheService: mockCache,
    );

    when(
      () => mockJournalRepository.getJournalEntityById(eventId),
    ).thenAnswer((_) async => eventEntity);
    when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);
  });

  test('suggest_follow_up_task creates a task linked to the event', () async {
    when(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => createdTask);

    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': '  Share the album  ', 'notes': 'Everyone asked.'},
      eventId,
    );

    expect(result.success, isTrue);
    expect(result.mutatedEntityId, 'task-9');

    final captured = verify(
      () => mockPersistenceLogic.createTaskEntry(
        data: captureAny(named: 'data'),
        entryText: captureAny(named: 'entryText'),
        linkedId: captureAny(named: 'linkedId'),
        categoryId: captureAny(named: 'categoryId'),
      ),
    ).captured;
    final data = captured[0] as TaskData;
    final entryText = captured[1] as EntryText;
    expect(data.title, 'Share the album'); // trimmed
    expect(data.profileId, 'profile-1'); // inherited from the category
    expect(entryText.plainText, 'Everyone asked.');
    expect(captured[2], eventId); // linkedId links the task to the event
    expect(captured[3], categoryId);
  });

  test('rejects an empty title and creates nothing', () async {
    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': '   '},
      eventId,
    );

    expect(result.success, isFalse);
    verifyNever(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    );
  });

  test('reports failure when task creation returns null', () async {
    when(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => null);

    final result = await dispatcher.dispatch(
      EventAgentToolNames.suggestFollowUpTask,
      {'title': 'X'},
      eventId,
    );

    expect(result.success, isFalse);
    expect(result.errorMessage, contains('Task creation failed'));
  });

  test('rejects an unknown tool', () async {
    final result = await dispatcher.dispatch('set_event_cover', {}, eventId);

    expect(result.success, isFalse);
    expect(result.output, contains('Unknown tool'));
  });
}
