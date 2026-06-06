import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';

void main() {
  group('GeminiIncludeThoughts', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts disabled', () {
      expect(container.read(geminiIncludeThoughtsProvider), isFalse);
      expect(
        container.read(geminiIncludeThoughtsProvider.notifier).includeThoughts,
        isFalse,
      );
    });

    test('toggle flips the state back and forth', () {
      final notifier = container.read(geminiIncludeThoughtsProvider.notifier)
        ..toggle();
      expect(container.read(geminiIncludeThoughtsProvider), isTrue);

      notifier.toggle();
      expect(container.read(geminiIncludeThoughtsProvider), isFalse);
    });

    test('the setter writes the state directly', () {
      final notifier = container.read(geminiIncludeThoughtsProvider.notifier)
        ..includeThoughts = true;
      expect(container.read(geminiIncludeThoughtsProvider), isTrue);
      expect(notifier.includeThoughts, isTrue);

      notifier.includeThoughts = false;
      expect(container.read(geminiIncludeThoughtsProvider), isFalse);
    });

    test('keepAlive: state survives losing all listeners', () async {
      container.read(geminiIncludeThoughtsProvider.notifier).toggle();

      // Read through a temporary listener, then drop it.
      container.listen(geminiIncludeThoughtsProvider, (_, _) {}).close();
      await Future<void>.value();

      expect(container.read(geminiIncludeThoughtsProvider), isTrue);
    });
  });
}
