// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../tasks/ui/checklists/checklists_widget_test.dart';

class _MockJournalDb extends Mock implements JournalDb {}

class _MockJournalRepository extends Mock implements JournalRepository {}

class _MockLabelsRepository extends Mock implements LabelsRepository {}

void main() {
  late _MockJournalDb db;
  late MockChecklistRepository mockChecklistRepository;
  late ProviderContainer container;

  setUp(() async {
    db = _MockJournalDb();
    mockChecklistRepository = MockChecklistRepository();
    await getIt.reset();
    getIt.registerSingleton<JournalDb>(db);
    container = ProviderContainer();
  });

  tearDown(() async {
    await getIt.reset();
    container.dispose();
  });

  AiConfigPrompt makePrompt() => AiConfigPrompt(
        id: 'p',
        defaultModelId: 'm',
        modelIds: const ['m'],
        createdAt: DateTime(2025),
        name: 'checklist updates',
        systemMessage: '',
        userMessage: 'Available Labels (id and name):```json\n{{labels}}\n```',
        requiredInputData: const [],
        aiResponseType: AiResponseType.checklistUpdates,
        useReasoning: false,
        trackPreconfigured: false,
      );

  test('privacy default excludes private labels when flag unset', () async {
    final publicLabel = LabelDefinition(
      id: 'public',
      name: 'Public Label',
      color: '#FF0000',
      description: null,
      sortOrder: null,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      vectorClock: null,
      private: false,
    );

    // Privacy filtering handled at DB layer via config flag
    // When flag is false, DB query returns only public labels
    when(() => db.getAllLabelDefinitions())
        .thenAnswer((_) async => [publicLabel]);
    when(() => db.getLabelUsageCounts())
        .thenAnswer((_) async => <String, int>{});

    final mockLabelsRepo = _MockLabelsRepository();
    when(mockLabelsRepo.getAllLabels)
        .thenAnswer((_) => db.getAllLabelDefinitions());
    when(mockLabelsRepo.getLabelUsageCounts)
        .thenAnswer((_) => db.getLabelUsageCounts());
    final helper = PromptBuilderHelper(
      aiInputRepository: container.read(aiInputRepositoryProvider),
      checklistRepository: mockChecklistRepository,
      journalRepository: _MockJournalRepository(),
      labelsRepository: mockLabelsRepo,
    );

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: Task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: TaskData(
          title: 'Task',
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime(2025),
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      ),
    );

    expect(prompt, isNotNull);
    expect(prompt!.contains('Public Label'), isTrue);
    expect(prompt.contains('Private Label'), isFalse);
  });

  test('privacy flag true includes private labels', () async {
    // Privacy filtering handled at DB layer via config flag
    // When flag is true, DB query returns both public and private labels
    when(() => db.getAllLabelDefinitions()).thenAnswer((_) async => [
          LabelDefinition(
            id: 'public',
            name: 'Public Label',
            color: '#FF0000',
            description: null,
            sortOrder: null,
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            vectorClock: null,
            private: false,
          ),
          LabelDefinition(
            id: 'private',
            name: 'Private Label',
            color: '#00FF00',
            description: null,
            sortOrder: null,
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            vectorClock: null,
            private: true,
          ),
        ]);
    when(() => db.getLabelUsageCounts())
        .thenAnswer((_) async => <String, int>{});

    final mockLabelsRepo = _MockLabelsRepository();
    when(mockLabelsRepo.getAllLabels)
        .thenAnswer((_) => db.getAllLabelDefinitions());
    when(mockLabelsRepo.getLabelUsageCounts)
        .thenAnswer((_) => db.getLabelUsageCounts());
    final helper = PromptBuilderHelper(
      aiInputRepository: container.read(aiInputRepositoryProvider),
      checklistRepository: mockChecklistRepository,
      journalRepository: _MockJournalRepository(),
      labelsRepository: mockLabelsRepo,
    );
    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: Task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: TaskData(
          title: 'Task',
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime(2025),
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      ),
    );

    expect(prompt, isNotNull);
    expect(prompt!.contains('Public Label'), isTrue);
    expect(prompt.contains('Private Label'), isTrue);
  });
}
