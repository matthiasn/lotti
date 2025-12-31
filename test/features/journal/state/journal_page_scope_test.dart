import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:riverpod/misc.dart';

void main() {
  group('journalPageScopeProvider', () {
    test('throws UnimplementedError when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // In Riverpod 3, errors are wrapped in ProviderException
      expect(
        () => container.read(journalPageScopeProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      );
    });

    test('error message explains the required override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // In Riverpod 3, errors are wrapped in ProviderException
      expect(
        () => container.read(journalPageScopeProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => (e.exception as UnimplementedError).message,
            'message',
            contains('journalPageScopeProvider must be overridden'),
          ),
        ),
      );
    });

    test('returns overridden value when properly configured', () {
      final container = ProviderContainer(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(journalPageScopeProvider), isTrue);
    });

    test('returns false when overridden with false', () {
      final container = ProviderContainer(
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(journalPageScopeProvider), isFalse);
    });

    test('nested ProviderScope can override parent value', () {
      final parentContainer = ProviderContainer(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(parentContainer.dispose);

      final childContainer = ProviderContainer(
        parent: parentContainer,
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
        ],
      );
      addTearDown(childContainer.dispose);

      expect(parentContainer.read(journalPageScopeProvider), isTrue);
      expect(childContainer.read(journalPageScopeProvider), isFalse);
    });
  });
}
