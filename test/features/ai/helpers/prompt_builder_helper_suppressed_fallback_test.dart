import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

void main() {
  test('suppressed_labels placeholder falls back to [] on error', () async {
    final db = MockJournalDb();
    final aiRepo = MockAiInputRepository();
    getIt.registerSingleton<JournalDb>(db);
    final mockLabelsRepo = MockLabelsRepository();
    when(() => mockLabelsRepo.buildLabelTuples(any()))
        .thenThrow(Exception('db'));
    final helper = PromptBuilderHelper(
      aiInputRepository: aiRepo,
      checklistRepository: MockChecklistRepository(),
      journalRepository: MockJournalRepository(),
      labelsRepository: mockLabelsRepo,
    );

    // Task with suppression set, but DB throws during name resolution
    final task = Task(
      meta: Metadata(
        id: 't1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 's',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        statusHistory: const [],
        title: 't',
        aiSuppressedLabelIds: const {'x'},
      ),
    );
    when(db.getAllLabelDefinitions).thenThrow(Exception('db'));
    when(() => aiRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    final prompt = AiConfigPrompt(
      id: 'p',
      name: 'Checklist Updates',
      systemMessage: 'sys',
      userMessage: 'Suppressed:```json\n{{suppressed_labels}}\n```',
      defaultModelId: 'm',
      modelIds: const ['m'],
      createdAt: DateTime.now(),
      useReasoning: false,
      requiredInputData: const [InputDataType.task],
      aiResponseType: AiResponseType.checklistUpdates,
    );

    final out = await helper.buildPromptWithData(
      promptConfig: prompt,
      entity: task,
    );
    expect(out, contains('[]'));
    await getIt.reset();
  });
}
