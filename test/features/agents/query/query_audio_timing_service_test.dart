import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/agents/query/query_audio_timing_service.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';

import '../test_data/ai_config_factories.dart';
import 'query_audio_test_utils.dart';

void main() {
  final provider = testInferenceProvider(
    inferenceProviderType: InferenceProviderType.mistral,
  ).copyWith(name: 'Mistral', baseUrl: 'https://api.mistral.ai/v1');
  ResolvedProfile profile({
    String? model = 'voxtral-mini-latest',
    AiConfigInferenceProvider? transcriptionProvider,
  }) => ResolvedProfile(
    thinkingModelId: 'thinking',
    thinkingProvider: provider,
    transcriptionProvider: transcriptionProvider ?? provider,
    transcriptionModelId: model,
  );
  final bytes = Uint8List.fromList([1, 2, 3]);
  final response = jsonEncode({
    'text': queryAudioWords,
    'segments': [
      {'text': queryAudioWords, 'start': 120.125, 'end': 130.5},
    ],
  });

  test('only explicitly configured timed models are supported', () {
    expect(QueryAudioTimingService.supports(null), isFalse);
    for (final model in [
      null,
      '',
      'voxtral-mini-2507',
      'voxtral-small-latest',
      'voxtral-mini-transcribe-realtime-2602',
    ]) {
      expect(QueryAudioTimingService.supports(profile(model: model)), isFalse);
    }
    expect(QueryAudioTimingService.supports(profile()), isTrue);
    expect(
      QueryAudioTimingService.supports(
        profile(model: 'voxtral-mini-transcribe-2602'),
      ),
      isTrue,
    );
    expect(
      QueryAudioTimingService.supports(
        profile(transcriptionProvider: testInferenceProvider()),
      ),
      isFalse,
    );
  });

  test(
    'binds actual provider timing to submitted audio and saved text',
    () async {
      http.MultipartRequest? request;
      final client = MockClient.streaming((value, body) async {
        request = value as http.MultipartRequest;
        await body.drain<void>();
        return http.StreamedResponse(Stream.value(utf8.encode(response)), 200);
      });
      final service = QueryAudioTimingService(
        createRepository: () =>
            MistralTranscriptionRepository(httpClient: client),
      );
      var gates = 0;
      final created = DateTime(2026, 7, 17);
      final result = await withClock(
        Clock.fixed(created),
        () => service.generate(
          profile: profile(),
          audioBytes: bytes,
          evidence: audioEvidence(),
          cancellation: QueryCancellation(),
          authorize: () async {
            gates++;
          },
          agentId: 'agent',
          chatId: 'chat',
        ),
      );
      expect(gates, 2);
      expect(
        request!.url.toString(),
        'https://api.mistral.ai/v1/audio/transcriptions',
      );
      expect(request!.fields['model'], 'voxtral-mini-latest');
      expect(request!.fields['timestamp_granularities'], 'segment');
      expect(result.audioSha256, sha256.convert(bytes).toString());
      expect(result.sourceFingerprint, audioEvidence().fingerprint);
      expect(result.createdAt, created);
      expect(result.segments.single.startMilliseconds, 120125);
      expect(result.segments.single.endMilliseconds, 130500);
    },
  );

  test('denied access and unsupported routing never send audio', () async {
    var calls = 0;
    final service = QueryAudioTimingService(
      createRepository: () => MistralTranscriptionRepository(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(response, 200);
        }),
      ),
    );
    for (final unsupported in [true, false]) {
      await expectLater(
        service.generate(
          profile: profile(
            model: unsupported ? 'unsupported' : 'voxtral-mini-latest',
          ),
          audioBytes: bytes,
          evidence: audioEvidence(),
          cancellation: QueryCancellation(),
          authorize: () async {
            throw const QueryCancelled();
          },
          agentId: 'agent',
          chatId: 'chat',
        ),
        throwsA(
          unsupported
              ? isA<QueryAudioTimingUnavailable>()
              : isA<QueryCancelled>(),
        ),
      );
    }
    expect(calls, 0);
  });

  test('cancellation while waiting discards a late timing response', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final token = QueryCancellation();
    final service = QueryAudioTimingService(
      createRepository: () => MistralTranscriptionRepository(
        httpClient: MockClient((_) {
          started.complete();
          return pending.future;
        }),
      ),
    );
    final result = service.generate(
      profile: profile(),
      audioBytes: bytes,
      evidence: audioEvidence(),
      cancellation: token,
      authorize: () async {},
      agentId: 'agent',
      chatId: 'chat',
    );
    final assertion = expectLater(result, throwsA(isA<QueryCancelled>()));
    await started.future;
    token.cancel();
    pending.complete(http.Response(response, 200));
    await assertion;
  });

  test('visibility is checked again after the provider completes', () async {
    var gates = 0;
    final service = QueryAudioTimingService(
      createRepository: () => MistralTranscriptionRepository(
        httpClient: MockClient((_) async => http.Response(response, 200)),
      ),
    );
    await expectLater(
      service.generate(
        profile: profile(),
        audioBytes: bytes,
        evidence: audioEvidence(),
        cancellation: QueryCancellation(),
        authorize: () async {
          if (++gates == 2) throw const QueryCancelled();
        },
        agentId: 'agent',
        chatId: 'chat',
      ),
      throwsA(isA<QueryCancelled>()),
    );
    expect(gates, 2);
  });
}
