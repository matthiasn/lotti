import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/state/purge_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingDb extends Mock implements LoggingDb {}

class FakeLogEntry extends Fake implements LogEntry {}

void main() {
  late MockJournalDb mockDb;
  late MockLoggingDb mockLoggingDb;
  late ProviderContainer container;
  late PurgeController controller;

  setUpAll(() {
    registerFallbackValue(FakeLogEntry());
  });

  setUp(() async {
    mockDb = MockJournalDb();
    mockLoggingDb = MockLoggingDb();

    await getIt.reset();

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<LoggingDb>(mockLoggingDb);

    container = ProviderContainer();
    controller = container.read(purgeControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
  });

  group('PurgeController', () {
    test('initial state should be correct', () {
      final state = container.read(purgeControllerProvider);
      expect(state.progress, 0);
      expect(state.isPurging, false);
      expect(state.error, isNull);
    });

    test('purgeDeleted should update state correctly', () async {
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.fromIterable([0.25, 0.5, 0.75, 1.0]),
      );

      final purgeFuture = controller.purgeDeleted();

      var state = container.read(purgeControllerProvider);
      expect(state.isPurging, true);
      expect(state.progress, 0);

      await purgeFuture;

      state = container.read(purgeControllerProvider);
      expect(state.isPurging, false);
      expect(state.progress, 1.0);
      expect(state.error, isNull);
    });

    test('purgeDeleted should handle errors gracefully', () async {
      const testError = 'Test error';

      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.error(Exception(testError)),
      );

      LogEntry? capturedLogEntry;
      when(() => mockLoggingDb.log(any())).thenAnswer((invocation) {
        capturedLogEntry = invocation.positionalArguments.first as LogEntry;
        return Future.value(1);
      });

      final purgeFuture = controller.purgeDeleted();

      var state = container.read(purgeControllerProvider);
      expect(state.isPurging, true);
      expect(state.progress, 0);

      await purgeFuture;

      state = container.read(purgeControllerProvider);
      expect(state.isPurging, false);
      expect(state.progress, 0);
      expect(state.error, contains(testError));

      expect(capturedLogEntry, isNotNull);
      expect(capturedLogEntry!.message, contains(testError));
      expect(capturedLogEntry!.domain, equals('PurgeController'));
      expect(capturedLogEntry!.subDomain, equals('purgeDeleted'));
      expect(capturedLogEntry!.level, equals('ERROR'));
      expect(capturedLogEntry!.type, equals('EXCEPTION'));
    });

    test('purgeDeleted should update progress incrementally', () async {
      when(() => mockDb.purgeDeleted()).thenAnswer(
        (_) => Stream.fromIterable([0.25, 0.5, 0.75, 1.0]),
      );

      final states = <PurgeState>[];
      final sub = container.listen<PurgeState>(
        purgeControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      await controller.purgeDeleted();

      expect(states.length, 7);
      expect(states[0].progress, 0);
      expect(states[0].isPurging, false);
      expect(states[1].progress, 0);
      expect(states[1].isPurging, true);
      expect(states[2].progress, 0.25);
      expect(states[3].progress, 0.5);
      expect(states[4].progress, 0.75);
      expect(states[5].progress, 1.0);
      expect(states[5].isPurging, true);
      expect(states[6].progress, 1.0);
      expect(states[6].isPurging, false);

      sub.close();
    });
  });
}
