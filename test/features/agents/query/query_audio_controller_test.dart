import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_audio_controller.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../tts/test_utils.dart';
import 'query_audio_test_bench.dart';

void main() {
  const key = QueryAudioTestBench.key;
  final provider = queryAudioControllerProvider(key);
  late QueryAudioTestBench bench;
  late ProviderContainer container;
  late ProviderSubscription<QueryAudioState> subscription;
  late QueryAudioController controller;
  setUpAll(registerAllFallbackValues);
  setUp(() async {
    await setUpTestGetIt();
    getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    bench = QueryAudioTestBench();
    container = ProviderContainer(overrides: bench.overrides);
    subscription = container.listen(provider, (_, _) {});
    controller = container.read(provider.notifier);
    await container.read(configFlagProvider('private').future);
    await container.read(configFlagProvider(enableAiSummaryTtsFlag).future);
    await container.read(queryChatDataProvider(key.home).future);
  });
  tearDown(() async {
    await controller.stop();
    subscription.close();
    container.dispose();
    await bench.close();
    await tearDownTestGetIt();
  });
  Future<void> play({bool generate = false}) => controller.playEvidence(
    actionId: 'answer:0',
    evidence: bench.evidence,
    generate: generate,
  );

  test(
    'cached evidence opens only its bounded original recording without inference',
    () async {
      await play();
      final media =
          verify(
                () => bench.player.open(captureAny(), play: false),
              ).captured.single
              as Media;
      expect(media.uri, bench.file.path);
      expect(media.start, const Duration(seconds: 95));
      expect(media.end, const Duration(seconds: 155));
      verify(bench.player.play).called(1);
      expect(bench.requests, 0);
      expect(bench.writes, 0);
      expect(container.read(provider).status, QueryAudioStatus.playing);
      bench.completion.add(true);
      await container.pump();
      expect(container.read(provider).status, QueryAudioStatus.idle);
      verify(bench.player.dispose).called(1);
    },
  );

  test(
    'explicit enrichment saves timing without changing the original note',
    () async {
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      final before = bench.audio;
      await play(generate: true);
      expect(bench.requests, 1);
      expect(bench.writes, 1);
      expect(bench.audio.entryText, before.entryText);
      expect(bench.audio.data.transcripts, before.data.transcripts);
      expect(
        bench
            .audio
            .data
            .transcriptTimings[bench.evidence.fingerprint]!
            .sourceFingerprint,
        bench.evidence.fingerprint,
      );
      expect(container.read(provider).status, QueryAudioStatus.playing);
    },
  );

  test(
    'missing timing never uploads automatically and unsupported profiles stay local',
    () async {
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      await play();
      expect(container.read(provider).status, QueryAudioStatus.stale);
      bench.profile = null;
      await play(generate: true);
      expect(container.read(provider).status, QueryAudioStatus.unavailable);
      expect(bench.requests, 0);
      expect(bench.playerCreations, 0);
    },
  );

  test('changed audio requires another explicit preparation', () async {
    bench.bytes = Uint8List.fromList([4, 5, 6]);
    await play();
    expect(container.read(provider).status, QueryAudioStatus.stale);
    expect(bench.requests, 0);
    await play(generate: true);
    expect(bench.requests, 1);
    expect(container.read(provider).status, QueryAudioStatus.playing);
  });

  test(
    'oversized preparation is rejected before reading or uploading bytes',
    () async {
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      when(bench.file.lengthSync).thenReturn(500000000);
      await play(generate: true);
      expect(container.read(provider).status, QueryAudioStatus.tooLarge);
      expect(bench.requests, 0);
      verifyNever(bench.file.openRead);
      verifyNever(bench.file.readAsBytes);
    },
  );

  test(
    'missing recordings and unmatched quotes produce specific recoverable states',
    () async {
      when(bench.file.existsSync).thenReturn(false);
      await play();
      expect(container.read(provider).status, QueryAudioStatus.missingFile);
      when(bench.file.existsSync).thenReturn(true);
      final timing =
          bench.audio.data.transcriptTimings[bench.evidence.fingerprint]!;
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(
          transcriptTimings: {
            timing.sourceFingerprint: timing.copyWith(
              segments: [
                timing.segments.single.copyWith(
                  text: 'A different discussion.',
                ),
              ],
            ),
          },
        ),
      );
      await play();
      expect(container.read(provider).status, QueryAudioStatus.unmatched);
      expect(bench.playerCreations, 0);
    },
  );

  test(
    'historical text can play its existing timing but cannot be retranscribed as current text',
    () async {
      final original = bench.audio;
      bench.audio = original.copyWith(
        entryText: const EntryText(plainText: 'Edited note.'),
      );
      await play();
      expect(container.read(provider).status, QueryAudioStatus.playing);
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      await play(generate: true);
      expect(container.read(provider).status, QueryAudioStatus.unmatched);
      expect(bench.requests, 0);
    },
  );

  for (final hidden in [
    'private source',
    'private category',
    'private chat',
    'private other source',
    'deleted source',
    'missing source',
    'missing home',
    'deleted chat',
    'different scope',
  ]) {
    test('$hidden blocks audio before file or provider access', () async {
      switch (hidden) {
        case 'private source':
          bench.audio = bench.audio.copyWith(
            meta: bench.audio.meta.copyWith(private: true),
          );
        case 'private category':
          bench.categories[0] = bench.categories[0].copyWith(private: true);
        case 'private chat':
          bench.addEvent(
            'private',
            const QueryChatEventData.renamed(
              title: 'Private title',
              private: true,
            ),
          );
        case 'private other source':
          bench.add('other', category: categoryMindfulness.id, private: true);
          bench.addEvent(
            'other-answer',
            QueryChatEventData.answer(
              questionId: 'other-question',
              text: 'hidden',
              coverage: const QueryCoverage(),
              dependencies: [bench.evidence.source.copyWith(id: 'other')],
            ),
          );
        case 'deleted source':
          bench.audio = bench.audio.copyWith(
            meta: bench.audio.meta.copyWith(deletedAt: DateTime(2026, 7, 17)),
          );
        case 'missing source':
          bench.entries.remove('meeting');
        case 'missing home':
          bench.entries.remove('task');
        case 'deleted chat':
          bench.addEvent(
            'deleted',
            const QueryChatEventData.deleted(forget: false),
          );
        case 'different scope':
          bench.events[0] = bench.events[0].copyWith(
            data: const QueryChatEventData.created(
              scope: QueryScope(kind: QueryScopeKind.task, id: 'other'),
              title: 'Other',
            ),
          );
      }
      await play(generate: true);
      expect(container.read(provider).status, QueryAudioStatus.idle);
      expect(bench.requests, 0);
      expect(bench.playerCreations, 0);
      verifyNever(bench.file.openRead);
    });
  }

  test(
    'a caller cannot play evidence that is absent from the saved answer',
    () async {
      await controller.playEvidence(
        actionId: 'forged',
        evidence: bench.evidence.copyWith(summary: 'not saved'),
      );
      expect(bench.playerCreations, 0);
      expect(container.read(provider).status, QueryAudioStatus.idle);
    },
  );

  test('privacy loss during native open prevents the late play call', () async {
    final pending = Completer<void>();
    final started = Completer<void>();
    when(() => bench.player.open(any(), play: any(named: 'play'))).thenAnswer((
      _,
    ) {
      started.complete();
      return pending.future;
    });
    final playing = play();
    await started.future;
    bench.audio = bench.audio.copyWith(
      meta: bench.audio.meta.copyWith(private: true),
    );
    bench.history.add(bench.snapshot());
    await container.pump();
    pending.complete();
    await playing;
    verifyNever(bench.player.play);
    verify(bench.player.dispose).called(1);
    expect(container.read(provider).status, QueryAudioStatus.idle);
  });

  for (final stopAt in ['privacy', 'lockdown', 'navigation']) {
    test(
      '$stopAt cancels pending timing without a write or playback',
      () async {
        final pending = Completer<void>();
        final started = Completer<void>();
        bench.audio = bench.audio.copyWith(
          data: bench.audio.data.copyWith(transcriptTimings: {}),
        );
        bench.beforeResponse = () {
          started.complete();
          return pending.future;
        };
        final playing = play(generate: true);
        await started.future;
        switch (stopAt) {
          case 'privacy':
            bench.audio = bench.audio.copyWith(
              meta: bench.audio.meta.copyWith(private: true),
            );
            bench.history.add(bench.snapshot());
          case 'lockdown':
            container
                .read(lockdownControllerProvider.notifier)
                .lockToCategory('other');
          case 'navigation':
            subscription.close();
        }
        await container.pump();
        pending.complete();
        await playing;
        expect(bench.writes, 0);
        expect(bench.playerCreations, 0);
      },
    );
  }

  test(
    'source edits while timing is generated cannot be overwritten',
    () async {
      bench.audio = bench.audio.copyWith(
        data: bench.audio.data.copyWith(transcriptTimings: {}),
      );
      bench.beforeResponse = () async {
        bench.audio = bench.audio.copyWith(
          entryText: const EntryText(plainText: 'A new decision.'),
        );
      };
      await play(generate: true);
      expect(bench.audio.entryText!.plainText, 'A new decision.');
      expect(bench.writes, 0);
      expect(bench.playerCreations, 0);
    },
  );

  test('a refused timing write never proceeds to playback', () async {
    bench.audio = bench.audio.copyWith(
      data: bench.audio.data.copyWith(transcriptTimings: {}),
    );
    when(
      () => bench.persistence.updateDbEntity(any()),
    ).thenAnswer((_) async => false);
    await play(generate: true);
    expect(bench.requests, 1);
    expect(bench.playerCreations, 0);
  });

  test(
    'native playback failure releases the player and can be retried',
    () async {
      when(bench.player.play).thenThrow(StateError('native failure'));
      await play();
      expect(container.read(provider).status, QueryAudioStatus.failed);
      verify(bench.player.dispose).called(1);
      when(bench.player.play).thenAnswer((_) async {});
      await play();
      expect(container.read(provider).status, QueryAudioStatus.playing);
    },
  );

  test(
    'read aloud uses the saved answer and the local speech engine',
    () async {
      await controller.speakAnswer(answerId: 'answer');
      expect(bench.engine.calls.single.text, 'Keep the feeder latch.');
      expect(bench.speechPlayer.playCount, 1);
      expect(bench.requests, 0);
      expect(container.read(provider).status, QueryAudioStatus.playing);
      bench.speechPlayer.complete();
      await container.pump();
      expect(container.read(provider).status, QueryAudioStatus.idle);
    },
  );

  test(
    'a disabled speech flag or unknown answer cannot trigger synthesis',
    () async {
      await controller.speakAnswer(answerId: 'question');
      bench.ttsEnabled.add(false);
      await container.pump();
      await controller.speakAnswer(answerId: 'answer');
      expect(bench.engine.calls, isEmpty);
      expect(bench.speechPlayer.playCount, 0);
    },
  );

  test(
    'hiding private entries while speech is synthesized discards the late WAV',
    () async {
      final pending = Completer<File>();
      final started = Completer<void>();
      bench
        ..engine = FakeTtsEngine(
          pendingSynthesis: pending.future,
          onSynthesize: started.complete,
        )
        ..showPrivate = true;
      bench.privacy.add(true);
      await container.pump();
      final speaking = controller.speakAnswer(answerId: 'answer');
      await started.future;
      bench.showPrivate = false;
      bench.privacy.add(false);
      await container.pump();
      pending.complete(File('/tmp/nonexistent-private-query.wav'));
      await speaking;
      expect(bench.speechPlayer.playCount, 0);
      expect(container.read(provider).status, QueryAudioStatus.idle);
    },
  );
}
