import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_language_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late MockJournalRepository mockJournalRepo;
  late Task task;

  setUp(() {
    mockJournalRepo = MockJournalRepository();
    task = testTask.copyWith(
      data: testTask.data.copyWith(languageCode: null),
    );
    registerFallbackValue(task as JournalEntity);
  });

  group('TaskLanguageHandler', () {
    group('handle', () {
      test('sets language and returns success with didWrite=true', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('de');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.wasNoOp, isFalse);
        expect(result.message, contains('de'));
        expect(result.message, contains('German'));
        expect(result.updatedTask, isNotNull);
        expect(result.updatedTask!.data.languageCode, 'de');
        expect(result.error, isNull);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('trims and lowercases language code', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('  EN  ');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.languageCode, 'en');
      });

      test('rejects empty language code', () async {
        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('empty'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('rejects unsupported language code', () async {
        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('xx');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('Unsupported'));
        expect(result.error, contains('xx'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('returns no-op when language is already set to same value',
          () async {
        final taskWithLang = task.copyWith(
          data: task.data.copyWith(languageCode: 'fr'),
        );

        final handler = TaskLanguageHandler(
          task: taskWithLang,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('fr');

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
        expect(result.message, contains('already'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('allows changing from one language to another', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final taskWithLang = task.copyWith(
          data: task.data.copyWith(languageCode: 'en'),
        );

        final handler = TaskLanguageHandler(
          task: taskWithLang,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('de');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.languageCode, 'de');
      });

      test('returns error when repository returns false', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => false);

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('en');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('repository returned false'));
      });

      test('returns error when repository throws', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('DB error'));

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('en');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('DB error'));
      });

      test('updates local task field after successful write', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.languageCode, isNull);

        await handler.handle('es');

        expect(handler.task.data.languageCode, 'es');
      });

      test('does not update local task field when write fails', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('fail'));

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.handle('en');

        expect(handler.task.data.languageCode, isNull);
      });
    });

    group('fromHandlerResult conversion', () {
      test('maps successful write with entityId', () {
        final langResult = TaskLanguageResult(
          success: true,
          message: 'Task language set to "en" (English).',
          updatedTask: task,
          didWrite: true,
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: langResult.success,
          message: langResult.message,
          didWrite: langResult.didWrite,
          error: langResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.output, contains('en'));
        expect(toolResult.mutatedEntityId, 'ent-123');
        expect(toolResult.errorMessage, isNull);
      });

      test('maps no-op result without entityId', () {
        final langResult = TaskLanguageResult(
          success: true,
          message: 'Language is already "en". No change needed.',
          updatedTask: task,
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: langResult.success,
          message: langResult.message,
          didWrite: langResult.didWrite,
          error: langResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.mutatedEntityId, isNull);
      });

      test('maps error result with error message', () {
        const langResult = TaskLanguageResult(
          success: false,
          message: 'Unsupported language code: "xx".',
          error: 'Unsupported language code: "xx".',
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: langResult.success,
          message: langResult.message,
          didWrite: langResult.didWrite,
          error: langResult.error,
        );

        expect(toolResult.success, isFalse);
        expect(toolResult.errorMessage, contains('xx'));
        expect(toolResult.mutatedEntityId, isNull);
      });
    });

    group('TaskLanguageResult', () {
      test('wasNoOp is true when success=true and didWrite=false', () {
        const result = TaskLanguageResult(
          success: true,
          message: 'no-op',
        );
        expect(result.wasNoOp, isTrue);
      });

      test('wasNoOp is false when didWrite=true', () {
        const result = TaskLanguageResult(
          success: true,
          message: 'wrote',
          didWrite: true,
        );
        expect(result.wasNoOp, isFalse);
      });

      test('wasNoOp is false when success=false', () {
        const result = TaskLanguageResult(
          success: false,
          message: 'error',
        );
        expect(result.wasNoOp, isFalse);
      });
    });
  });
}
