import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/providers/service_providers.dart';

void main() {
  final providers = <String, ProviderListenable<Object?>>{
    'matrixServiceProvider': matrixServiceProvider,
    'maintenanceProvider': maintenanceProvider,
    'journalDbProvider': journalDbProvider,
    'loggingDbProvider': loggingDbProvider,
    'loggingServiceProvider': loggingServiceProvider,
    'outboxServiceProvider': outboxServiceProvider,
    'aiConfigRepositoryProvider': aiConfigRepositoryProvider,
    'sentEventRegistryProvider': sentEventRegistryProvider,
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
}
