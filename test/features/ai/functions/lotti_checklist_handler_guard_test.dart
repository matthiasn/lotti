import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockJournalDb extends Mock implements JournalDb {}

const _uuid = Uuid();

Task _task() => Task(
      meta: Metadata(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        categoryId: 'cat',
      ),
      data: TaskData(
        title: 'T',
        checklistIds: const [],
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
    );

ChatCompletionMessageToolCall _call(String args) =>
    ChatCompletionMessageToolCall(
      id: 'tool-1',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'add_checklist_item',
        arguments: args,
      ),
    );

void main() {
  late MockAutoChecklistService autoService;
  late MockChecklistRepository checklistRepo;
  late MockJournalDb journalDb;
  late LottiChecklistItemHandler handler;
  late Task task;

  setUp(() {
    autoService = MockAutoChecklistService();
    checklistRepo = MockChecklistRepository();
    journalDb = MockJournalDb();
    getIt.registerSingleton<JournalDb>(journalDb);
    task = _task();
    handler = LottiChecklistItemHandler(
      task: task,
      autoChecklistService: autoService,
      checklistRepository: checklistRepo,
    );
  });

  tearDown(getIt.reset);

  group('LottiChecklistItemHandler guard', () {
    test('rejects bracketed array pattern', () {
      final result = handler.processFunctionCall(
          _call('{"actionItemDescription": "[item1, item2, item3]"}'));
      expect(result.success, false);
      expect(result.error, contains('Multiple items detected'));
    });

    test('rejects comma-separated list (top-level 2+ commas)', () {
      final result = handler.processFunctionCall(
          _call('{"actionItemDescription": "item1, item2, item3"}'));
      expect(result.success, false);
      expect(result.error, contains('Multiple items detected'));
    });

    test('accepts single item with commas in parentheses', () {
      final result = handler.processFunctionCall(_call(
          '{"actionItemDescription": "Setup database (cache, indexes, warm-up)"}'));
      expect(result.success, true);
    });

    test('accepts single item with one comma', () {
      final result = handler.processFunctionCall(
          _call('{"actionItemDescription": "Buy milk, 2%"}'));
      expect(result.success, true);
    });

    test('matches screenshot issue exactly', () {
      final result = handler.processFunctionCall(_call(
          '{"actionItemDescription": "[Investigate audio quality from Bluetooth headphones,Find out if network connectivity detection triggers sending,Come up with an implementation plan to fix the network issue]"}'));
      expect(result.success, false);
      expect(result.error, contains('Multiple items detected'));
    });
  });
}
