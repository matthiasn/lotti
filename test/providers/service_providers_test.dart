import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/providers/service_providers.dart';

void main() {
  final providers = <String, ProviderListenable<Object?>>{
    'matrixServiceProvider': matrixServiceProvider,
    'maintenanceProvider': maintenanceProvider,
    'journalDbProvider': journalDbProvider,
    'loggingServiceProvider': loggingServiceProvider,
    'outboxServiceProvider': outboxServiceProvider,
    'aiConfigRepositoryProvider': aiConfigRepositoryProvider,
    'syncDatabaseProvider': syncDatabaseProvider,
  };

  for (final entry in providers.entries) {
    test('${entry.key} throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reader = container.read;

      // In Riverpod 3, errors are wrapped in ProviderException
      expect(
        () => reader(entry.value),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      );
    });
  }

  test(
    'outboxLoginGateStreamProvider surfaces an error when not overridden',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // This StreamProvider delegates to outboxServiceProvider, which throws
      // UnimplementedError when not overridden. Reading the StreamProvider does
      // not throw on read; instead the dependency failure is captured into the
      // AsyncValue's error state. In Riverpod 3 the watched dependency's error
      // surfaces wrapped in a ProviderException whose message carries the
      // originating UnimplementedError.
      final state = container.read(outboxLoginGateStreamProvider);

      expect(state.hasError, isTrue);
      expect(state.hasValue, isFalse);
      expect(state.error, isA<ProviderException>());
      expect(state.error.toString(), contains('UnimplementedError'));
    },
  );
}
