import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';
import '../test_utils.dart';

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenForPlaybackFailure(ref, context, 'mine');
    return const SizedBox.shrink();
  }
}

void main() {
  Future<TtsPlaybackController> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          ttsEngineProvider.overrideWithValue(
            FakeTtsEngine(throwOnSynthesize: true),
          ),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
          ttsAudioPlayerProvider.overrideWithValue(FakeTtsAudioPlayer()),
          ttsModelRepositoryProvider.overrideWithValue(
            FakeTtsModelRepository(),
          ),
        ],
        child: const _Host(),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    ).read(ttsPlaybackControllerProvider.notifier);
  }

  testWidgets('a failed utterance of its own shows an error toast', (
    tester,
  ) async {
    final voice = await pump(tester);

    await voice.speak(sourceId: 'mine', text: 'Hello');
    await tester.pump();

    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets("another source's failure shows nothing", (tester) async {
    final voice = await pump(tester);

    await voice.speak(sourceId: 'theirs', text: 'Hello');
    await tester.pump();

    expect(find.text('Error'), findsNothing);
  });
}
