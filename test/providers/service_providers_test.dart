import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  };

  for (final entry in providers.entries) {
    test('${entry.key} throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reader = container.read;

      expect(
        () => reader(entry.value),
        throwsA(isA<UnimplementedError>()),
      );
    });
  }
}
