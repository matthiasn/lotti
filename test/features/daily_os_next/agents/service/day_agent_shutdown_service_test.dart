import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_shutdown_service.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../agents/test_data/template_factories.dart';

final _day = DateTime(2026, 10, 3);
const _dayId = 'dayplan-2026-10-03';
final _tomorrow = DateTime(2026, 10, 4);
final String _reflectionId = MetadataService.deterministicId(
  'daily_os_reflection:$_dayId',
);

Metadata _meta(String id, DateTime from, DateTime to) => Metadata(
  id: id,
  createdAt: from,
  updatedAt: to,
  dateFrom: from,
  dateTo: to,
);

JournalEntry _entry(String id, DateTime from, int minutes, {String? text}) =>
    JournalEntry(
      meta: _meta(id, from, from.add(Duration(minutes: minutes))),
      entryText: text == null ? null : EntryText(plainText: text),
    );

Task _task(
  String id,
  String title, {
  TaskStatus? status,
  List<TaskStatus> history = const [],
  DateTime? due,
}) {
  final open = TaskStatus.open(
    id: '$id-open',
    createdAt: DateTime(2026, 9),
    utcOffset: 0,
  );
  return Task(
    meta: _meta(id, DateTime(2026, 9), DateTime(2026, 9)),
    data: TaskData(
      status: status ?? open,
      title: title,
      statusHistory: [open, ...history],
      dateFrom: DateTime(2026, 9),
      dateTo: DateTime(2026, 9),
      due: due,
    ),
  );
}

EntryLink _basic(String from, String to) => EntryLink.basic(
  id: '$from>$to',
  fromId: from,
  toId: to,
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
  vectorClock: null,
);

EntryLink _ratingLink(String rating, String entry) => EntryLink.rating(
  id: '$rating>$entry',
  fromId: rating,
  toId: entry,
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
  vectorClock: null,
);

RatingEntry _rating(String id, String target, double energy) => RatingEntry(
  meta: _meta(id, _day, _day),
  data: RatingData(
    targetId: target,
    dimensions: [
      const RatingDimension(key: 'focus', value: 0.1),
      RatingDimension(key: 'energy', value: energy),
    ],
  ),
);

PlannedBlock _planned(
  String id,
  String? taskId,
  int hour, {
  bool dropped = false,
}) => PlannedBlock(
  id: id,
  categoryId: 'work',
  startTime: DateTime(2026, 10, 3, hour),
  endTime: DateTime(2026, 10, 3, hour + 1),
  taskId: taskId,
  state: dropped ? PlannedBlockState.dropped : PlannedBlockState.committed,
);

Stream<CreateChatCompletionStreamResponse> _streamOf(String text) =>
    Stream.fromIterable([
      CreateChatCompletionStreamResponse(
        id: 'chunk',
        object: 'chat.completion.chunk',
        created: 0,
        choices: [
          ChatCompletionStreamResponseChoice(
            index: 0,
            delta: ChatCompletionStreamResponseDelta(content: text),
          ),
        ],
      ),
    ]);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockPersistenceLogic persistence;
  late MockDayAgentService dayAgentService;
  late MockDayAgentPlanService planService;
  late MockDayAgentCaptureService captureService;
  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockAgentTemplateService templateService;
  late MockProfileResolver profileResolver;
  late MockCloudInferenceRepository inference;
  late DayAgentShutdownService service;
  late Map<String, JournalEntity> entities;
  late List<String> prompts;
  var modelAnswer = 'Start with the invoices.';

  final dayAgent = makeTestIdentity(agentId: 'day-agent', kind: 'day_agent');
  final planner = makeTestIdentity(agentId: 'planner', kind: 'day_agent');
  final invoices = _task('invoices', 'Invoices', due: _day);
  final deck = _task(
    'deck',
    'Deck',
    status: TaskStatus.done(
      id: 'deck-done',
      createdAt: DateTime(2026, 10, 3, 11, 30),
      utcOffset: 0,
    ),
    history: [
      TaskStatus.done(
        id: 'deck-done',
        createdAt: DateTime(2026, 10, 3, 11, 30),
        utcOffset: 0,
      ),
    ],
  );
  final docs = _task('docs', 'Docs');
  final call = _task('call', 'Call the bank', due: _day);
  final moved = _task('moved', 'Moved one', due: _tomorrow);
  final rejected = TaskStatus.rejected(
    id: 'gone-rejected',
    createdAt: DateTime(2026, 10, 3, 17),
    utcOffset: 0,
  );
  final gone = _task('gone', 'Gone', status: rejected, history: [rejected]);
  final lastWeek = _entry('e0', DateTime(2026, 10, 2, 9), 30);
  final morning = _entry('e1', DateTime(2026, 10, 3, 9), 60);
  final lateMorning = _entry('e2', DateTime(2026, 10, 3, 11), 30);

  void stubDay({
    bool withPlan = true,
    List<Task> dueToday = const [],
    List<Task> closedSince = const [],
    List<JournalEntity> extraEntries = const [],
    JournalEntity? reflection,
    List<JournalEntity> reflectionLinks = const [],
  }) {
    entities = {
      for (final e in <JournalEntity>[
        invoices,
        deck,
        docs,
        call,
        moved,
        gone,
        lastWeek,
        morning,
        lateMorning,
        _rating('r0', 'e0', 0.6),
        _rating('r1', 'e1', 0.8),
        ?reflection,
      ])
        e.meta.id: e,
    };
    when(
      () => journalDb.sortedCalendarEntries(
        rangeStart: DateTime(2026, 9, 26),
        rangeEnd: _tomorrow,
      ),
    ).thenAnswer(
      (_) async => [lastWeek, morning, lateMorning, ...extraEntries],
    );
    when(() => journalDb.basicLinksForEntryIds(any())).thenAnswer(
      (_) async => [
        _basic('deck', 'e0'),
        _basic('invoices', 'e1'),
        _basic('deck', 'e2'),
      ],
    );
    when(() => journalDb.linksForEntryIds(any())).thenAnswer(
      (_) async => [_ratingLink('r0', 'e0'), _ratingLink('r1', 'e1')],
    );
    when(() => journalDb.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
      (call) async => [
        for (final id in call.positionalArguments.first as Set<String>)
          ?entities[id],
      ],
    );
    when(
      () => journalDb.getTasksDueOn(_day),
    ).thenAnswer((_) async => dueToday);
    when(
      () => journalDb.getTasksClosedSince(_day),
    ).thenAnswer((_) async => closedSince);
    when(
      () => journalDb.journalEntityById(_reflectionId),
    ).thenAnswer((_) async => reflection);
    when(
      () => journalDb.getLinkedEntities(_reflectionId),
    ).thenAnswer((_) async => reflectionLinks);
    when(
      () => dayAgentService.getDayAgentForDate(_day),
    ).thenAnswer((_) async => withPlan ? dayAgent : null);
    when(
      () => planService.draftPlanForDay(agentId: 'day-agent', dayId: _dayId),
    ).thenAnswer(
      (_) async => makeTestDayPlan(
        agentId: 'day-agent',
        dayId: _dayId,
        planDate: _day,
        data: DayPlanData(
          planDate: _day,
          status: DayPlanStatus.committed(committedAt: _day),
          plannedBlocks: [
            _planned('b-docs', 'docs', 13),
            _planned('b-invoices', 'invoices', 9),
            _planned('b-dropped', 'call', 15, dropped: true),
            _planned('b-moved', 'moved', 16),
            _planned('b-gone', 'gone', 17),
            _planned('b-buffer', null, 12),
          ],
        ),
      ),
    );
  }

  setUp(() {
    journalDb = MockJournalDb();
    persistence = MockPersistenceLogic();
    dayAgentService = MockDayAgentService();
    planService = MockDayAgentPlanService();
    captureService = MockDayAgentCaptureService();
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    templateService = MockAgentTemplateService();
    profileResolver = MockProfileResolver();
    inference = MockCloudInferenceRepository();
    prompts = [];
    modelAnswer = 'Start with the invoices.';

    when(
      () => dayAgentService.getOrCreatePlannerAgent(),
    ).thenAnswer((_) async => planner);
    when(
      () => templateService.getTemplateForAgent(any()),
    ).thenAnswer((_) async => makeTestTemplate());
    when(
      () => templateService.getActiveVersion(any()),
    ).thenAnswer((_) async => makeTestTemplateVersion());
    when(
      () => profileResolver.resolve(
        agentConfig: any(named: 'agentConfig'),
        template: any(named: 'template'),
        version: any(named: 'version'),
      ),
    ).thenAnswer(
      (_) async => ResolvedProfile(
        thinkingModelId: 'thinker',
        thinkingProvider: testInferenceProvider(),
        thinkingModel: testAiModel(),
      ),
    );
    when(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        geminiThinkingMode: any(named: 'geminiThinkingMode'),
        reasoningEffort: any(named: 'reasoningEffort'),
        impactCollector: any(named: 'impactCollector'),
      ),
    ).thenAnswer((call) {
      prompts.add(call.positionalArguments.first as String);
      return _streamOf(modelAnswer);
    });
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => agentRepository.getEntity(any())).thenAnswer((_) async => null);

    service = DayAgentShutdownService(
      journalDb: journalDb,
      persistenceLogic: persistence,
      dayAgentService: dayAgentService,
      planService: planService,
      captureService: captureService,
      agentRepository: agentRepository,
      syncService: syncService,
      templateService: templateService,
      profileResolver: profileResolver,
      inferenceRepository: inference,
      categoryById: (_) => null,
      eventsEnabled: () async => false,
    );
  });

  group('shutdownDay', () {
    test('builds the day from recorded time, the plan and ratings', () async {
      stubDay(dueToday: [call, invoices]);

      final day = await service.shutdownDay(DateTime(2026, 10, 3, 19));

      expect(
        day.completed.map((i) => (i.taskId, i.durationMinutes, i.doneToday)),
        [('invoices', 60, false), ('deck', 30, true)],
      );
      // Plan order first (dropped, re-placed, closed and untasked blocks
      // out), then the due tasks not already listed, by title.
      expect(day.carryover.map((i) => (i.taskId, i.loggedMinutes)), [
        ('invoices', 60),
        ('docs', 0),
        ('call', 0),
      ]);
      expect(day.carryover.first.suggestedDate, _tomorrow);
      expect(day.metrics.focusMinutes, 90);
      expect(day.metrics.contextSwitches, 1);
      expect(day.metrics.contextSwitchesWeekAvg, 0);
      expect(day.metrics.energyScore, closeTo(8, 1e-9));
      expect(day.metrics.energyDeltaVsWeek, closeTo(2, 1e-9));
    });

    test(
      'a recording across midnight is left out, as on the timeline',
      () async {
        stubDay(
          extraEntries: [_entry('late', DateTime(2026, 10, 2, 23, 30), 60)],
        );

        final day = await service.shutdownDay(_day);

        expect(day.metrics.focusMinutes, 90);
        expect(day.completed.map((i) => i.durationMinutes), [60, 30]);
        // Nor is it credited to the day it started: that day keeps one run.
        expect(day.metrics.contextSwitchesWeekAvg, 0);
      },
    );

    test('finds a task done that day with no time, plan or due date', () async {
      final adHoc = _task(
        'adhoc',
        'Ship the hotfix',
        status: TaskStatus.done(
          id: 'adhoc-done',
          createdAt: DateTime(2026, 10, 3, 16),
          utcOffset: 0,
        ),
        history: [
          TaskStatus.done(
            id: 'adhoc-done',
            createdAt: DateTime(2026, 10, 3, 16),
            utcOffset: 0,
          ),
        ],
      );
      stubDay(closedSince: [adHoc]);

      final day = await service.shutdownDay(_day);

      expect(
        day.completed.last,
        isA<CompletedItem>()
            .having((i) => i.taskId, 'taskId', 'adhoc')
            .having((i) => i.doneToday, 'done', true)
            .having((i) => i.durationMinutes, 'minutes', 0),
      );
    });

    test('without a day agent only the due tasks carry forward', () async {
      stubDay(withPlan: false, dueToday: [call]);

      final day = await service.shutdownDay(_day);

      expect(day.carryover.map((i) => i.taskId), ['call']);
      verifyNever(
        () => planService.draftPlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });
  });

  group('recordCarryoverDecision', () {
    setUp(() {
      when(
        () => captureService.applyTriage(
          agentId: any(named: 'agentId'),
          taskId: any(named: 'taskId'),
          action: any(named: 'action'),
          deferTo: any(named: 'deferTo'),
        ),
      ).thenAnswer((_) async => invoices);
    });

    test('tomorrow defers to the day after the shutdown day', () async {
      await service.recordCarryoverDecision(
        forDate: DateTime(2026, 10, 3, 22),
        taskId: 'invoices',
        action: CarryoverAction.tomorrow,
      );
      verify(
        () => captureService.applyTriage(
          agentId: 'planner',
          taskId: 'invoices',
          action: 'defer',
          deferTo: _tomorrow,
        ),
      ).called(1);
    });

    test('a picked date defers to it', () async {
      final picked = DateTime(2026, 10, 9);
      await service.recordCarryoverDecision(
        forDate: _day,
        taskId: 'docs',
        action: CarryoverAction.pickDate,
        when: picked,
      );
      verify(
        () => captureService.applyTriage(
          agentId: 'planner',
          taskId: 'docs',
          action: 'defer',
          deferTo: picked,
        ),
      ).called(1);
    });

    test('a pick without a date is refused before any write', () async {
      await expectLater(
        service.recordCarryoverDecision(
          forDate: _day,
          taskId: 'docs',
          action: CarryoverAction.pickDate,
        ),
        throwsArgumentError,
      );
      verifyNever(
        () => captureService.applyTriage(
          agentId: any(named: 'agentId'),
          taskId: any(named: 'taskId'),
          action: any(named: 'action'),
          deferTo: any(named: 'deferTo'),
        ),
      );
    });

    test('drop drops through triage', () async {
      await service.recordCarryoverDecision(
        forDate: _day,
        taskId: 'call',
        action: CarryoverAction.drop,
      );
      verify(
        () => captureService.applyTriage(
          agentId: 'planner',
          taskId: 'call',
          action: 'drop',
        ),
      ).called(1);
    });
  });

  group('reflection', () {
    setUp(() {
      when(
        () => persistence.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          uuidV5Input: any(named: 'uuidV5Input'),
        ),
      ).thenAnswer((call) async {
        final at = call.namedArguments[#dateFrom] as DateTime;
        return _meta(
          MetadataService.deterministicId(
            call.namedArguments[#uuidV5Input] as String,
          ),
          at,
          at,
        );
      });
      when(
        () => persistence.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => persistence.updateJournalEntityText(any(), any(), any()),
      ).thenAnswer((_) async => true);
    });

    test('the first reflection of a day creates its entry', () async {
      stubDay();
      await withClock(Clock.fixed(DateTime(2026, 10, 3, 21)), () async {
        await service.recordReflection(forDate: _day, text: '  Sharp day.  ');
      });

      final created =
          verify(() => persistence.createDbEntity(captureAny())).captured.single
              as JournalEntry;
      expect(created.meta.id, _reflectionId);
      expect(created.entryText?.plainText, 'Sharp day.');
      expect(created.meta.dateFrom, DateTime(2026, 10, 3, 21));
    });

    test('a reflection on a past day is filed at its end', () async {
      stubDay();
      await withClock(Clock.fixed(DateTime(2026, 10, 5, 8)), () async {
        await service.recordReflection(forDate: _day, text: 'Late thought.');
      });

      final created =
          verify(() => persistence.createDbEntity(captureAny())).captured.single
              as JournalEntry;
      expect(created.meta.dateFrom, DateTime(2026, 10, 3, 23, 59));
    });

    test('later reflections append to the day entry', () async {
      stubDay(reflection: _entry(_reflectionId, _day, 0, text: 'First.'));

      await service.recordReflection(forDate: _day, text: 'Second.');

      final text =
          verify(
                () => persistence.updateJournalEntityText(
                  _reflectionId,
                  captureAny(),
                  any(),
                ),
              ).captured.single
              as EntryText;
      expect(text.plainText, 'First.\n\nSecond.');
      verifyNever(() => persistence.createDbEntity(any()));
    });

    test('a reflection into an empty entry replaces nothing', () async {
      stubDay(reflection: _entry(_reflectionId, _day, 0, text: ''));
      await service.recordReflection(forDate: _day, text: 'Spoken first.');
      final text =
          verify(
                () => persistence.updateJournalEntityText(
                  _reflectionId,
                  captureAny(),
                  any(),
                ),
              ).captured.single
              as EntryText;
      expect(text.plainText, 'Spoken first.');
    });

    test('a blank reflection writes nothing', () async {
      stubDay();
      await service.recordReflection(forDate: _day, text: '   ');
      verifyNever(() => persistence.createDbEntity(any()));
    });

    test('ensureReflectionEntry reuses the day entry', () async {
      stubDay(reflection: _entry(_reflectionId, _day, 0));
      expect(await service.ensureReflectionEntry(_day), _reflectionId);
      verifyNever(() => persistence.createDbEntity(any()));
    });

    test('ensureReflectionEntry creates an empty entry when missing', () async {
      stubDay();
      expect(await service.ensureReflectionEntry(_day), _reflectionId);
      final created =
          verify(() => persistence.createDbEntity(captureAny())).captured.single
              as JournalEntry;
      expect(created.entryText?.plainText, isEmpty);
    });
  });

  group('tomorrowNote', () {
    test('writes, stores and syncs a note from the day facts', () async {
      stubDay(
        dueToday: [call],
        reflection: _entry(_reflectionId, _day, 0, text: 'Calls drain me.'),
      );

      final note = await service.tomorrowNote(_day);

      expect(note.body, 'Start with the invoices.');
      final prompt = prompts.single;
      expect(prompt, contains('Day: $_dayId'));
      expect(prompt, contains('- Deck (): 30m, done'));
      expect(prompt, contains('- Invoices: 60m in'));
      expect(prompt, contains('- Call the bank: not started'));
      expect(prompt, contains('- Moved one → dayplan-2026-10-04'));
      expect(prompt, contains('Dropped by the user:\n- Gone'));
      expect(prompt, contains('Calls drain me.'));
      final stored =
          verify(() => syncService.upsertEntity(captureAny())).captured.single
              as TomorrowNoteEntity;
      expect(stored.id, 'day_agent_tomorrow_note:$_dayId');
      expect(stored.agentId, 'day-agent');
      expect(stored.text, 'Start with the invoices.');
      expect(stored.inputFingerprint, isNotEmpty);
    });

    test(
      'a due-only task moved in this session still reads as moved',
      () async {
        when(
          () => captureService.applyTriage(
            agentId: any(named: 'agentId'),
            taskId: any(named: 'taskId'),
            action: any(named: 'action'),
            deferTo: any(named: 'deferTo'),
          ),
        ).thenAnswer((_) async => call);
        final callMoved = _task('call', 'Call the bank', due: _tomorrow);
        // After the decision the task is no longer due on the day, so the
        // due query stops returning it.
        stubDay(withPlan: false);
        entities['call'] = callMoved;
        await service.recordCarryoverDecision(
          forDate: _day,
          taskId: 'call',
          action: CarryoverAction.tomorrow,
        );

        final day = await service.shutdownDay(_day);
        await service.tomorrowNote(_day);

        expect(day.carryover, isEmpty);
        expect(
          prompts.single,
          contains('- Call the bank → dayplan-2026-10-04'),
        );
      },
    );

    test('an unplanned task dropped that day reads as dropped', () async {
      stubDay(withPlan: false, closedSince: [gone]);

      await service.tomorrowNote(_day);

      expect(prompts.single, contains('Dropped by the user:\n- Gone'));
    });

    test(
      'a spoken reflection reaches the note through its recordings',
      () async {
        JournalAudio recording(String id, int hour, String transcript) =>
            JournalAudio(
              meta: _meta(
                id,
                DateTime(2026, 10, 3, hour),
                DateTime(2026, 10, 3, hour, 1),
              ),
              data: AudioData(
                dateFrom: DateTime(2026, 10, 3, hour),
                dateTo: DateTime(2026, 10, 3, hour, 1),
                duration: const Duration(minutes: 1),
                audioFile: '',
                audioDirectory: '',
                transcripts: [
                  AudioTranscript(
                    created: DateTime(2026, 10, 3, hour, 2),
                    library: 'test',
                    model: 'test',
                    detectedLanguage: 'en',
                    transcript: transcript,
                  ),
                ],
              ),
            );
        stubDay(
          reflection: _entry(_reflectionId, _day, 0, text: ''),
          reflectionLinks: [
            recording('later', 21, 'Mornings are best.'),
            recording('earlier', 20, 'Calls drained me.'),
            _entry('not-audio', _day, 5, text: 'Ignored link.'),
          ],
        );

        await service.tomorrowNote(_day);

        expect(
          prompts.single,
          contains(
            "The user's reflection on the day:\n"
            'Calls drained me.\n\nMornings are best.',
          ),
        );
        expect(prompts.single, isNot(contains('Ignored link.')));
      },
    );

    test('the same facts reuse the stored note without a model call', () async {
      stubDay();
      await service.tomorrowNote(_day);
      final stored =
          verify(() => syncService.upsertEntity(captureAny())).captured.single
              as TomorrowNoteEntity;
      when(
        () => agentRepository.getEntity(stored.id),
      ).thenAnswer((_) async => stored);

      final again = await service.tomorrowNote(_day);

      expect(again.body, stored.text);
      expect(prompts, hasLength(1));
    });

    test('changed facts rewrite the note and keep its creation time', () async {
      stubDay();
      final earlier = AgentDomainEntity.tomorrowNote(
        id: 'day_agent_tomorrow_note:$_dayId',
        agentId: 'day-agent',
        dayId: _dayId,
        text: 'Old note.',
        inputFingerprint: 'other-facts',
        createdAt: DateTime(2026, 10, 3, 18),
        updatedAt: DateTime(2026, 10, 3, 18),
        vectorClock: null,
      );
      when(
        () => agentRepository.getEntity(earlier.id),
      ).thenAnswer((_) async => earlier);

      final note = await service.tomorrowNote(_day);

      expect(note.body, 'Start with the invoices.');
      final stored =
          verify(() => syncService.upsertEntity(captureAny())).captured.single
              as TomorrowNoteEntity;
      expect(stored.createdAt, DateTime(2026, 10, 3, 18));
    });

    test('without a day agent the planner writes it', () async {
      stubDay(withPlan: false);
      await service.tomorrowNote(_day);
      final stored =
          verify(() => syncService.upsertEntity(captureAny())).captured.single
              as TomorrowNoteEntity;
      expect(stored.agentId, 'planner');
    });

    test('no inference profile is a typed, user-actionable failure', () async {
      stubDay();
      when(
        () => profileResolver.resolve(
          agentConfig: any(named: 'agentConfig'),
          template: any(named: 'template'),
          version: any(named: 'version'),
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.tomorrowNote(_day),
        throwsA(
          isA<TomorrowNoteUnavailableException>().having(
            (e) => e.failure,
            'failure',
            TomorrowNoteFailure.noInferenceProvider,
          ),
        ),
      );
      expect(prompts, isEmpty);
    });

    test('an agent without a template has no profile either', () async {
      stubDay();
      when(
        () => templateService.getTemplateForAgent(any()),
      ).thenAnswer((_) async => null);
      await expectLater(
        service.tomorrowNote(_day),
        throwsA(isA<TomorrowNoteUnavailableException>()),
      );
    });

    test('a template without an active version has no profile', () async {
      stubDay();
      when(
        () => templateService.getActiveVersion(any()),
      ).thenAnswer((_) async => null);
      await expectLater(
        service.tomorrowNote(_day),
        throwsA(isA<TomorrowNoteUnavailableException>()),
      );
    });

    test('an empty answer is not stored', () async {
      stubDay();
      modelAnswer = '   ';
      await expectLater(
        service.tomorrowNote(_day),
        throwsA(
          isA<TomorrowNoteUnavailableException>().having(
            (e) => e.failure,
            'failure',
            TomorrowNoteFailure.emptyResponse,
          ),
        ),
      );
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('an over-long answer is cut to the stored limit', () async {
      stubDay();
      modelAnswer = 'x' * 600;
      final note = await service.tomorrowNote(_day);
      expect(note.body.length, DayAgentShutdownService.tomorrowNoteMaxChars);
      expect(note.body, endsWith('…'));
    });
  });

  test('the failure names its cause', () {
    expect(
      const TomorrowNoteUnavailableException(
        TomorrowNoteFailure.emptyResponse,
      ).toString(),
      contains('emptyResponse'),
    );
  });
}
