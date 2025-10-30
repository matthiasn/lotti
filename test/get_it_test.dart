import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoggingService extends Mock implements LoggingService {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockMaintenance extends Mock implements Maintenance {}

void main() {
  setUp(() async {
    // Use a dedicated scope per test to avoid cross-file contamination
    getIt.pushNewScope();
  });

  tearDown(() async {
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('safeLog', () {
    test('delegates to logging service on success messages', () {
      final loggingService = _MockLoggingService();
      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<LoggingService>(loggingService);

      safeLogForTesting('hello', isError: false);

      verify(
        () => loggingService.captureEvent(
          'hello',
          domain: 'SERVICE_REGISTRATION',
        ),
      ).called(1);
    });

    test('falls back to print when logging service missing', () {
      final prints = <String>[];

      runZoned(
        () => safeLogForTesting('fallback', isError: false),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String line) => prints.add(line),
        ),
      );

      expect(
        prints.single,
        contains('SERVICE_REGISTRATION: fallback'),
      );
    });

    test('prints when logging service throws', () {
      final loggingService = _MockLoggingService();
      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenThrow(Exception('fail'));

      getIt.registerSingleton<LoggingService>(loggingService);

      final prints = <String>[];

      runZoned(
        () => safeLogForTesting('failure', isError: true),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String line) => prints.add(line),
        ),
      );

      expect(
        prints.single,
        contains(
            'SERVICE_REGISTRATION: failure (logging failed: Exception: fail)'),
      );
    });
  });

  group('registerLazyServiceForTesting', () {
    test('registers lazy singleton and logs lifecycle events', () {
      final loggingService = _MockLoggingService();
      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<LoggingService>(loggingService);

      registerLazyServiceForTesting<String>(() => 'value', 'TestService');

      verify(
        () => loggingService.captureEvent(
          'Successfully registered lazy TestService',
          domain: 'SERVICE_REGISTRATION',
        ),
      ).called(1);

      final resolved = getIt<String>();

      expect(resolved, 'value');
      verify(
        () => loggingService.captureEvent(
          'Successfully created lazy instance of TestService',
          domain: 'SERVICE_REGISTRATION',
        ),
      ).called(1);
    });

    test('logs and rethrows when factory fails', () {
      final loggingService = _MockLoggingService();
      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<LoggingService>(loggingService);

      registerLazyServiceForTesting<int>(
        () => throw StateError('broken'),
        'BrokenService',
      );

      expect(getIt.call<int>, throwsA(isA<StateError>()));

      verify(
        () => loggingService.captureEvent(
          any<String>(
              that:
                  contains('Failed to create lazy instance of BrokenService')),
          domain: 'SERVICE_REGISTRATION',
          subDomain: 'error',
        ),
      ).called(1);
    });

    test('logs registration failure when duplicate service detected', () {
      final loggingService = _MockLoggingService();
      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      getIt.registerSingleton<LoggingService>(loggingService);

      registerLazyServiceForTesting<String>(() => 'first', 'DupService');

      registerLazyServiceForTesting<String>(() => 'second', 'DupService');

      final captured = verify(
        () => loggingService.captureEvent(
          captureAny<String>(),
          domain: 'SERVICE_REGISTRATION',
          subDomain: 'error',
        ),
      ).captured;

      expect(
        captured.cast<String>().any(
              (message) =>
                  message.contains('Failed to register lazy DupService'),
            ),
        isTrue,
      );
    });
  });

  group('checkAndRemoveActionItemSuggestionsForTesting', () {
    late _MockLoggingService loggingService;
    late _MockSettingsDb settingsDb;
    late _MockMaintenance maintenance;

    setUp(() {
      loggingService = _MockLoggingService();
      settingsDb = _MockSettingsDb();
      maintenance = _MockMaintenance();

      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) {});

      getIt
        ..registerSingleton<LoggingService>(loggingService)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<Maintenance>(maintenance);
    });

    test('runs maintenance when flag missing', () async {
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => maintenance.removeActionItemSuggestions(
          triggeredAtAppStart: any(named: 'triggeredAtAppStart'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      await checkAndRemoveActionItemSuggestionsForTesting();

      verify(
        () => maintenance.removeActionItemSuggestions(
          triggeredAtAppStart: true,
        ),
      ).called(1);
      verify(
        () => settingsDb.saveSettingsItem(
          'maintenance_actionItemSuggestionsRemoved',
          'true',
        ),
      ).called(1);
      verify(
        () => loggingService.captureEvent(
          any<String>(
              that: contains(
                  'Automatic removal of action item suggestions completed')),
          domain: 'MAINTENANCE',
          subDomain: 'startup',
        ),
      ).called(1);
    });

    test('logs exception when maintenance task fails', () async {
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => maintenance.removeActionItemSuggestions(
          triggeredAtAppStart: any(named: 'triggeredAtAppStart'),
        ),
      ).thenThrow(Exception('db failure'));

      await checkAndRemoveActionItemSuggestionsForTesting();

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'MAINTENANCE',
          subDomain: 'startup_removeActionItemSuggestions',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });

    test('skips maintenance when flag already set', () async {
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => 'true');

      await checkAndRemoveActionItemSuggestionsForTesting();

      verifyNever(() => maintenance.removeActionItemSuggestions(
            triggeredAtAppStart: any(named: 'triggeredAtAppStart'),
          ));
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });
  });
}
