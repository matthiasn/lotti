import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_audio_controller.dart';
import 'package:lotti/features/agents/query/query_audio_timing_service.dart';
import 'package:lotti/features/agents/query/query_audio_timing_writer.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../tts/test_utils.dart';
import '../test_data/ai_config_factories.dart';
import 'query_audio_test_utils.dart';
import 'query_test_utils.dart';

/// Synthetic penguin source, real timing service/writer and controllable
/// native boundaries, shared by controller and interaction tests.
class QueryAudioTestBench extends QueryTestBench {
  QueryAudioTestBench({this.useDefaultAudioServices = false}) {
    entries['task'] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'task',
        categoryId: categoryMindfulness.id,
      ),
    );
    audio = testAudioEntry.copyWith(
      meta: testAudioEntry.meta.copyWith(
        id: 'meeting',
        categoryId: categoryMindfulness.id,
        private: false,
      ),
      data: testAudioEntry.data.copyWith(
        audioFile: 'habitat.m4a',
        duration: const Duration(minutes: 10),
      ),
      entryText: const EntryText(plainText: queryAudioWords),
    );
    final document = QuerySourceDocument.fromEntry(audio)!;
    evidence = audioEvidence().copyWith(
      source: QuerySourceRef(
        id: 'meeting',
        private: false,
        categoryPrivate: false,
        categoryId: categoryMindfulness.id,
      ),
      fingerprint: document.fingerprint,
      textVersion: document.version,
    );
    audio = audio.copyWith(
      data: audio.data.copyWith(
        transcriptTimings: {
          evidence.fingerprint: audioTiming().copyWith(
            sourceFingerprint: evidence.fingerprint,
            sourceVersion: evidence.textVersion,
            audioSha256: sha256.convert(bytes).toString(),
          ),
        },
      ),
    );
    addEvent(
      'created',
      const QueryChatEventData.created(scope: scope, title: 'Feeder decision'),
    );
    addEvent(
      'question',
      const QueryChatEventData.question(text: 'What did we decide?'),
    );
    addEvent(
      'answer',
      QueryChatEventData.answer(
        questionId: 'question',
        text: 'Keep the feeder latch.',
        coverage: const QueryCoverage(checked: 1),
        evidence: [evidence],
        dependencies: [evidence.source],
      ),
    );
    when(
      () => store.load(any()),
    ).thenAnswer((_) async => QueryChatProjection(events));
    when(() => file.path).thenReturn('/tmp/penguin-habitat.m4a');
    when(file.existsSync).thenReturn(true);
    when(file.lengthSync).thenAnswer((_) => bytes.length);
    when(file.openRead).thenAnswer((_) => Stream.value(bytes));
    when(file.readAsBytes).thenAnswer((_) async => bytes);
    when(() => player.stream).thenReturn(playerStream);
    when(() => playerStream.completed).thenAnswer((_) => completion.stream);
    when(
      () => player.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});
    when(player.play).thenAnswer((_) async {});
    when(player.dispose).thenAnswer((_) async {});
    when(
      () => db.journalEntityById('meeting'),
    ).thenAnswer((_) async => entries['meeting']);
    when(
      () => persistence.updateMetadata(any()),
    ).thenAnswer((call) async => call.positionalArguments.first as Metadata);
    when(() => persistence.updateDbEntity(any())).thenAnswer((call) async {
      final updated = call.positionalArguments.first as JournalAudio;
      audio = updated;
      writes++;
      if (!timingWritten.isCompleted) timingWritten.complete();
      history.add(snapshot());
      return true;
    });
    final provider = testInferenceProvider(
      inferenceProviderType: InferenceProviderType.mistral,
    );
    profile = ResolvedProfile(
      thinkingModelId: 'thinking',
      thinkingProvider: provider,
      transcriptionProvider: provider,
      transcriptionModelId: 'voxtral-mini-latest',
    );
  }

  static const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
  static const QueryChatKey home = (agentId: 'agent', scope: scope);
  static const QueryAudioChatKey key = (home: home, chatId: 'chat');
  final bool useDefaultAudioServices;
  final store = MockQueryChatStore();
  final persistence = MockPersistenceLogic();
  final file = MockIoFile();
  final player = MockPlayer();
  final playerStream = MockPlayerStream();
  final completion = StreamController<bool>.broadcast(sync: true);
  final history = StreamController<QueryChatData>.broadcast(sync: true);
  final privacy = StreamController<bool>.broadcast(sync: true);
  final ttsEnabled = StreamController<bool>.broadcast(sync: true);
  final speechPlayer = FakeTtsAudioPlayer();
  FakeTtsEngine engine = FakeTtsEngine();
  final events = <AgentQueryChatEventEntity>[];
  Uint8List bytes = Uint8List.fromList([1, 2, 3]);
  late QueryEvidence evidence;
  ResolvedProfile? profile;
  int requests = 0;
  int writes = 0;
  final timingWritten = Completer<void>();
  int playerCreations = 0;
  Future<void> Function()? beforeResponse;

  JournalAudio get audio => entries['meeting']! as JournalAudio;
  set audio(JournalAudio value) => entries['meeting'] = value;

  void addEvent(String id, QueryChatEventData data) => events.add(
    AgentQueryChatEventEntity(
      id: id,
      agentId: 'agent',
      chatId: 'chat',
      data: data,
      createdAt: DateTime(
        2026,
        7,
        17,
        10,
      ).add(Duration(seconds: events.length)),
      vectorClock: null,
    ),
  );

  QueryChatData snapshot() => QueryChatData(
    projection: QueryChatProjection(events),
    access: QueryAccessSnapshot(
      showPrivate: showPrivate,
      categories: {for (final c in categories) c.id: c},
      entries: {...entries},
    ),
  );

  List<Override> get overrides => [
    queryChatStoreProvider.overrideWithValue(store),
    querySourceAccessProvider.overrideWithValue(crawler.access),
    queryChatDataProvider(home).overrideWith((ref) async* {
      yield snapshot();
      yield* history.stream;
    }),
    configFlagProvider('private').overrideWith((ref) async* {
      yield showPrivate;
      yield* privacy.stream;
    }),
    configFlagProvider(enableAiSummaryTtsFlag).overrideWith((ref) async* {
      yield true;
      yield* ttsEnabled.stream;
    }),
    if (!useDefaultAudioServices)
      queryAudioFileProvider.overrideWithValue((_) async => file),
    queryProfileProvider(home).overrideWith((ref) async => profile),
    journalDbProvider.overrideWithValue(db),
    if (!useDefaultAudioServices)
      queryAudioTimingWriterProvider.overrideWithValue(
        QueryAudioTimingWriter(journal: db, persistence: persistence),
      ),
    if (!useDefaultAudioServices)
      queryAudioTimingServiceProvider.overrideWithValue(
        QueryAudioTimingService(
          createRepository: () => MistralTranscriptionRepository(
            httpClient: createTimingClient(),
          ),
        ),
      ),
    playerFactoryProvider.overrideWithValue(() {
      playerCreations++;
      return player;
    }),
    ttsEngineProvider.overrideWith((ref) => engine),
    ttsModelRepositoryProvider.overrideWithValue(FakeTtsModelRepository()),
    ttsAudioPlayerProvider.overrideWithValue(speechPlayer),
  ];

  http.Client createTimingClient() => MockClient((_) async {
    requests++;
    await beforeResponse?.call();
    return http.Response(
      jsonEncode({
        'text': queryAudioWords,
        'segments': [
          {'text': queryAudioWords, 'start': 120, 'end': 130},
        ],
      }),
      200,
    );
  });

  Future<void> close() async {
    await completion.close();
    await history.close();
    await privacy.close();
    await ttsEnabled.close();
    await speechPlayer.dispose();
  }
}
