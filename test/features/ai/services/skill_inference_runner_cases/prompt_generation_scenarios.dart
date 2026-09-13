part of '../skill_inference_runner_test.dart';

enum _GeneratedPromptStreamPartKind { text, whitespace, empty }

class _GeneratedPromptStreamPart {
  const _GeneratedPromptStreamPart({
    required this.kind,
    required this.seed,
  });

  final _GeneratedPromptStreamPartKind kind;
  final int seed;

  String get content => switch (kind) {
    _GeneratedPromptStreamPartKind.text => 'chunk-$seed ',
    _GeneratedPromptStreamPartKind.whitespace => seed.isEven ? ' ' : '\n\t',
    _GeneratedPromptStreamPartKind.empty => '',
  };

  @override
  String toString() {
    return '_GeneratedPromptStreamPart(kind: $kind, seed: $seed)';
  }
}

class _GeneratedPromptStreamScenario {
  const _GeneratedPromptStreamScenario({
    required this.parts,
    required this.includeLinkedTask,
  });

  final List<_GeneratedPromptStreamPart> parts;
  final bool includeLinkedTask;

  String get rawResponse => parts.map((part) => part.content).join();

  String get expectedResponse => rawResponse.trim();

  bool get shouldPersist => expectedResponse.isNotEmpty;

  @override
  String toString() {
    return '_GeneratedPromptStreamScenario('
        'includeLinkedTask: $includeLinkedTask, parts: $parts)';
  }
}

enum _GeneratedPromptSourceKind {
  journalEntry,
  journalAudio,
  missingEntity,
  taskEntity,
}

class _GeneratedPromptGenerationScenario {
  const _GeneratedPromptGenerationScenario({
    required this.streamScenario,
    required this.sourceKind,
    required this.useHighEndModel,
  });

  final _GeneratedPromptStreamScenario streamScenario;
  final _GeneratedPromptSourceKind sourceKind;
  final bool useHighEndModel;

  bool get hasTextBearingEntity =>
      sourceKind == _GeneratedPromptSourceKind.journalEntry ||
      sourceKind == _GeneratedPromptSourceKind.journalAudio;

  bool get shouldPersist =>
      hasTextBearingEntity && streamScenario.shouldPersist;

  String get expectedModel =>
      useHighEndModel ? 'models/gemini-pro' : 'models/gemini-flash';

  @override
  String toString() {
    return '_GeneratedPromptGenerationScenario('
        'sourceKind: $sourceKind, useHighEndModel: $useHighEndModel, '
        'streamScenario: $streamScenario)';
  }
}

extension _AnyGeneratedPromptStreamScenario on glados.Any {
  glados.Generator<_GeneratedPromptStreamPartKind> get promptStreamPartKind =>
      glados.AnyUtils(this).choose(_GeneratedPromptStreamPartKind.values);

  glados.Generator<_GeneratedPromptSourceKind> get promptSourceKind =>
      glados.AnyUtils(this).choose(_GeneratedPromptSourceKind.values);

  glados.Generator<_GeneratedPromptStreamPart> get promptStreamPart =>
      glados.CombinableAny(this).combine2(
        promptStreamPartKind,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedPromptStreamPartKind kind,
          int seed,
        ) => _GeneratedPromptStreamPart(
          kind: kind,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedPromptStreamScenario> get promptStreamScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 8, promptStreamPart),
        glados.AnyUtils(this).choose([false, true]),
        (
          List<_GeneratedPromptStreamPart> parts,
          bool includeLinkedTask,
        ) => _GeneratedPromptStreamScenario(
          parts: parts,
          includeLinkedTask: includeLinkedTask,
        ),
      );

  glados.Generator<_GeneratedPromptGenerationScenario>
  get promptGenerationScenario => glados.CombinableAny(this).combine3(
    promptStreamScenario,
    promptSourceKind,
    glados.AnyUtils(this).choose([false, true]),
    (
      _GeneratedPromptStreamScenario streamScenario,
      _GeneratedPromptSourceKind sourceKind,
      bool useHighEndModel,
    ) => _GeneratedPromptGenerationScenario(
      streamScenario: streamScenario,
      sourceKind: sourceKind,
      useHighEndModel: useHighEndModel,
    ),
  );
}

class _GeneratedSkillRunnerBench {
  _GeneratedSkillRunnerBench._({
    required this.cloudRepository,
    required this.aiInputRepository,
    required this.journalRepository,
    required this.loggingService,
    required this.promptBuilderHelper,
    required this.taskSummaryResolver,
    required this.container,
    required this.runner,
  });

  factory _GeneratedSkillRunnerBench.create() {
    final cloudRepository = MockCloudInferenceRepository();
    final aiInputRepository = MockAiInputRepository();
    final journalRepository = MockJournalRepository();
    final loggingService = MockDomainLogger();
    final promptBuilderHelper = MockPromptBuilderHelper();
    final taskSummaryResolver = MockTaskSummaryResolver();
    final container = ProviderContainer();

    late final Ref capturedRef;
    final refProvider = Provider<void>((ref) {
      capturedRef = ref;
    });
    container.read(refProvider);

    final runner = SkillInferenceRunner(
      ref: capturedRef,
      cloudRepository: cloudRepository,
      aiInputRepository: aiInputRepository,
      journalRepository: journalRepository,
      loggingService: loggingService,
      promptBuilderHelper: promptBuilderHelper,
      taskSummaryResolver: taskSummaryResolver,
    );

    return _GeneratedSkillRunnerBench._(
      cloudRepository: cloudRepository,
      aiInputRepository: aiInputRepository,
      journalRepository: journalRepository,
      loggingService: loggingService,
      promptBuilderHelper: promptBuilderHelper,
      taskSummaryResolver: taskSummaryResolver,
      container: container,
      runner: runner,
    );
  }

  final MockCloudInferenceRepository cloudRepository;
  final MockAiInputRepository aiInputRepository;
  final MockJournalRepository journalRepository;
  final MockDomainLogger loggingService;
  final MockPromptBuilderHelper promptBuilderHelper;
  final MockTaskSummaryResolver taskSummaryResolver;
  final ProviderContainer container;
  final SkillInferenceRunner runner;

  InferenceStatus promptStatus(String id) {
    return container.read(
      inferenceStatusControllerProvider((
        id: id,
        aiResponseType: AiResponseType.promptGeneration,
      )),
    );
  }

  void stubLoggingException() => _stubLoggingExceptionFor(loggingService);

  void stubLoggingEvent() => _stubLoggingEventFor(loggingService);

  void dispose() {
    container.dispose();
  }
}
