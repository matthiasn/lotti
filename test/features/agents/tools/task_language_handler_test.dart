import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_language_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

enum _GeneratedCurrentLanguageKind { none, agent, user }

enum _GeneratedLanguageRequestShape {
  empty,
  whitespace,
  supported,
  supportedUppercase,
  supportedPadded,
  unsupported,
  unsupportedPadded,
}

class _GeneratedTaskLanguageScenario {
  const _GeneratedTaskLanguageScenario({
    required this.currentKind,
    required this.currentLanguage,
    required this.requestLanguage,
    required this.requestShape,
  });

  final _GeneratedCurrentLanguageKind currentKind;
  final SupportedLanguage currentLanguage;
  final SupportedLanguage requestLanguage;
  final _GeneratedLanguageRequestShape requestShape;

  String? get currentCode => currentKind == _GeneratedCurrentLanguageKind.none
      ? null
      : currentLanguage.code;

  ChangeSource? get currentSource {
    return switch (currentKind) {
      _GeneratedCurrentLanguageKind.none => null,
      _GeneratedCurrentLanguageKind.agent => ChangeSource.agent,
      _GeneratedCurrentLanguageKind.user => ChangeSource.user,
    };
  }

  String get requestCode {
    return switch (requestShape) {
      _GeneratedLanguageRequestShape.empty => '',
      _GeneratedLanguageRequestShape.whitespace => ' \n\t ',
      _GeneratedLanguageRequestShape.supported => requestLanguage.code,
      _GeneratedLanguageRequestShape.supportedUppercase =>
        requestLanguage.code.toUpperCase(),
      _GeneratedLanguageRequestShape.supportedPadded =>
        '  ${requestLanguage.code.toUpperCase()}  ',
      _GeneratedLanguageRequestShape.unsupported => 'zz',
      _GeneratedLanguageRequestShape.unsupportedPadded => '  zz  ',
    };
  }

  String get normalizedRequest => requestCode.trim().toLowerCase();

  bool get isEmptyRequest => normalizedRequest.isEmpty;

  bool get isUnsupported =>
      !isEmptyRequest && SupportedLanguage.fromCode(normalizedRequest) == null;

  bool get isNoOp =>
      !isEmptyRequest && !isUnsupported && currentCode == normalizedRequest;

  bool get userBlocksWrite =>
      !isEmptyRequest &&
      !isUnsupported &&
      !isNoOp &&
      currentKind == _GeneratedCurrentLanguageKind.user;

  bool get shouldWrite =>
      !isEmptyRequest && !isUnsupported && !isNoOp && !userBlocksWrite;

  @override
  String toString() {
    return '_GeneratedTaskLanguageScenario('
        'currentKind: $currentKind, '
        'currentLanguage: ${currentLanguage.code}, '
        'requestLanguage: ${requestLanguage.code}, '
        'requestShape: $requestShape)';
  }
}

extension _AnyTaskLanguageHandlerScenario on glados.Any {
  glados.Generator<_GeneratedCurrentLanguageKind> get currentLanguageKind =>
      glados.AnyUtils(this).choose(_GeneratedCurrentLanguageKind.values);

  glados.Generator<SupportedLanguage> get supportedLanguage =>
      glados.AnyUtils(this).choose(SupportedLanguage.values);

  glados.Generator<_GeneratedLanguageRequestShape> get languageRequestShape =>
      glados.AnyUtils(this).choose(_GeneratedLanguageRequestShape.values);

  glados.Generator<_GeneratedTaskLanguageScenario> get taskLanguageScenario =>
      glados.CombinableAny(this).combine4(
        currentLanguageKind,
        supportedLanguage,
        supportedLanguage,
        languageRequestShape,
        (
          _GeneratedCurrentLanguageKind currentKind,
          SupportedLanguage currentLanguage,
          SupportedLanguage requestLanguage,
          _GeneratedLanguageRequestShape requestShape,
        ) => _GeneratedTaskLanguageScenario(
          currentKind: currentKind,
          currentLanguage: currentLanguage,
          requestLanguage: requestLanguage,
          requestShape: requestShape,
        ),
      );
}

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
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

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
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

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

      test(
        'returns no-op when agent-set language already matches',
        () async {
          final taskWithLang = task.copyWith(
            data: task.data.copyWith(
              languageCode: 'fr',
              languageSource: ChangeSource.agent,
            ),
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
        },
      );

      test('allows changing agent-set language to another', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final taskWithLang = task.copyWith(
          data: task.data.copyWith(
            languageCode: 'en',
            languageSource: ChangeSource.agent,
          ),
        );

        final handler = TaskLanguageHandler(
          task: taskWithLang,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('de');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.languageCode, 'de');
        expect(result.updatedTask!.data.languageSource, ChangeSource.agent);
      });

      test('returns error when repository returns false', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => false);

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
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('DB error'));

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
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.languageCode, isNull);

        await handler.handle('es');

        expect(handler.task.data.languageCode, 'es');
      });

      test('rejects overwriting user-set language', () async {
        final taskWithUserLang = task.copyWith(
          data: task.data.copyWith(
            languageCode: 'de',
            languageSource: ChangeSource.user,
          ),
        );

        final handler = TaskLanguageHandler(
          task: taskWithUserLang,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('en');

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
        expect(result.message, contains('manually set by user'));
        expect(result.message, contains('de'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test(
        'returns no-op for user-set language with same code',
        () async {
          final taskWithUserLang = task.copyWith(
            data: task.data.copyWith(
              languageCode: 'en',
              languageSource: ChangeSource.user,
            ),
          );

          final handler = TaskLanguageHandler(
            task: taskWithUserLang,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.handle('en');

          expect(result.success, isTrue);
          expect(result.didWrite, isFalse);
          expect(result.wasNoOp, isTrue);
          expect(result.message, contains('already'));

          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test('sets languageSource to agent on successful write', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('en');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.languageSource, ChangeSource.agent);
      });

      test('does not update local task field when write fails', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('fail'));

        final handler = TaskLanguageHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.handle('en');

        expect(handler.task.data.languageCode, isNull);
      });

      glados.Glados(
        glados.any.taskLanguageScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated language validation, no-op, and write semantics',
        (scenario) async {
          final repo = MockJournalRepository();
          when(
            () => repo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final initialTask = task.copyWith(
            data: scenario.currentKind == _GeneratedCurrentLanguageKind.none
                ? task.data.copyWith(languageCode: null)
                : task.data.copyWith(
                    languageCode: scenario.currentCode,
                    languageSource: scenario.currentSource!,
                  ),
          );
          final handler = TaskLanguageHandler(
            task: initialTask,
            journalRepository: repo,
          );

          final result = await handler.handle(scenario.requestCode);

          if (scenario.isEmptyRequest || scenario.isUnsupported) {
            expect(result.success, isFalse, reason: '$scenario');
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(result.updatedTask, isNull, reason: '$scenario');
            expect(
              result.error,
              scenario.isEmptyRequest
                  ? contains('empty')
                  : contains('Unsupported'),
              reason: '$scenario',
            );
            expect(handler.task, initialTask, reason: '$scenario');
            verifyNever(() => repo.updateJournalEntity(any()));
            return;
          }

          expect(result.success, isTrue, reason: '$scenario');
          expect(result.error, isNull, reason: '$scenario');

          if (scenario.isNoOp || scenario.userBlocksWrite) {
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(result.wasNoOp, isTrue, reason: '$scenario');
            expect(result.updatedTask, initialTask, reason: '$scenario');
            expect(handler.task, initialTask, reason: '$scenario');
            verifyNever(() => repo.updateJournalEntity(any()));
            return;
          }

          expect(scenario.shouldWrite, isTrue, reason: '$scenario');
          expect(result.didWrite, isTrue, reason: '$scenario');
          expect(result.wasNoOp, isFalse, reason: '$scenario');
          expect(
            result.updatedTask!.data.languageCode,
            scenario.normalizedRequest,
            reason: '$scenario',
          );
          expect(
            result.updatedTask!.data.languageSource,
            ChangeSource.agent,
            reason: '$scenario',
          );
          expect(handler.task, result.updatedTask, reason: '$scenario');

          final captured =
              verify(
                    () => repo.updateJournalEntity(captureAny()),
                  ).captured.single
                  as Task;
          expect(captured, result.updatedTask, reason: '$scenario');
        },
        tags: 'glados',
      );
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
