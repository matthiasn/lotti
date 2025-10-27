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
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class _MockJournalDb extends Mock implements JournalDb {}

void main() {
  late _MockJournalDb db;
  late ProviderContainer container;

  setUp(() async {
    db = _MockJournalDb();
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
    final labels = <LabelDefinition>[
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
    ];

    when(() => db.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    // includePrivateLabelsInPromptsFlag intentionally not stubbed (unset → false)
    when(() => db.getAllLabelDefinitions()).thenAnswer((_) async => labels);
    when(() => db.getLabelUsageCounts())
        .thenAnswer((_) async => <String, int>{});

    final helper = PromptBuilderHelper(
      aiInputRepository: container.read(aiInputRepositoryProvider),
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
    when(() => db.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => db.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => true);

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

    final helper = PromptBuilderHelper(
      aiInputRepository: container.read(aiInputRepositoryProvider),
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
