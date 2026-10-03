import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';

void main() {
  final providers = <String, ProviderListenable<Object?>>{
    'matrixServiceProvider': matrixServiceProvider,
    'maintenanceProvider': maintenanceProvider,
    'journalDbProvider': journalDbProvider,
    'loggingServiceProvider': loggingServiceProvider,
    'outboxServiceProvider': outboxServiceProvider,
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

  group('domainLoggerProvider', () {
    tearDown(getIt.reset);

    test('reads the registered logger when there is one', () async {
      await getIt.reset();
      final registered = DomainLogger(loggingService: LoggingService());
      getIt.registerSingleton<DomainLogger>(registered);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(domainLoggerProvider), same(registered));
    });

    test(
      'otherwise needs no wiring: a standalone logger, no domain on',
      () async {
        await getIt.reset();
        // Neither getIt nor loggingServiceProvider is set up, as in a widget
        // test that never thought about logging.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final logger = container.read(domainLoggerProvider);
        expect(logger.enabledDomains, isEmpty);
        expect(container.read(domainLoggerProvider), same(logger));
        expect(
          () => logger.error(LogDomain.ai, StateError('logged, not thrown')),
          returnsNormally,
        );
      },
    );

    test('an override wins over getIt', () async {
      await getIt.reset();
      getIt.registerSingleton<DomainLogger>(
        DomainLogger(loggingService: LoggingService()),
      );
      final generation = DomainLogger(loggingService: LoggingService());
      final container = ProviderContainer(
        overrides: [domainLoggerProvider.overrideWithValue(generation)],
      );
      addTearDown(container.dispose);

      expect(container.read(domainLoggerProvider), same(generation));
    });
  });
}
