import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';

void main() {
  test('stores and clears detailed inference errors', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = inferenceErrorControllerProvider((
      id: 'entry-1',
      aiResponseType: AiResponseType.audioTranscription,
    ));

    expect(container.read(provider), isNull);

    container
        .read(provider.notifier)
        .setError('HTTP 503: all Voxtral providers failed');
    expect(
      container.read(provider),
      'HTTP 503: all Voxtral providers failed',
    );

    container.read(provider.notifier).setError(null);
    expect(container.read(provider), isNull);
  });
}
