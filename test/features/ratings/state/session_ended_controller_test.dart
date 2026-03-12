import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ratings/state/session_ended_controller.dart';

void main() {
  group('SessionEndedController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initializes with empty set', () {
      final state = container.read(sessionEndedControllerProvider);
      expect(state, isEmpty);
    });

    test('markSessionEnded adds entry ID to state', () {
      container
          .read(sessionEndedControllerProvider.notifier)
          .markSessionEnded('entry-1');

      final state = container.read(sessionEndedControllerProvider);
      expect(state, contains('entry-1'));
    });

    test('markSessionEnded supports multiple entries', () {
      container.read(sessionEndedControllerProvider.notifier)
        ..markSessionEnded('entry-1')
        ..markSessionEnded('entry-2');

      final state = container.read(sessionEndedControllerProvider);
      expect(state, containsAll(['entry-1', 'entry-2']));
    });

    test('markSessionEnded is idempotent for same ID', () {
      container.read(sessionEndedControllerProvider.notifier)
        ..markSessionEnded('entry-1')
        ..markSessionEnded('entry-1');

      final state = container.read(sessionEndedControllerProvider);
      expect(state, hasLength(1));
      expect(state, contains('entry-1'));
    });

    test('clearSessionEnded removes entry ID from state', () {
      container.read(sessionEndedControllerProvider.notifier)
        ..markSessionEnded('entry-1')
        ..markSessionEnded('entry-2')
        ..clearSessionEnded('entry-1');

      final state = container.read(sessionEndedControllerProvider);
      expect(state, isNot(contains('entry-1')));
      expect(state, contains('entry-2'));
    });

    test('clearSessionEnded is a no-op for absent ID', () {
      container.read(sessionEndedControllerProvider.notifier)
        ..markSessionEnded('entry-1')
        ..clearSessionEnded('non-existent');

      final state = container.read(sessionEndedControllerProvider);
      expect(state, hasLength(1));
      expect(state, contains('entry-1'));
    });

    test('state survives across reads (keepAlive)', () {
      container
          .read(sessionEndedControllerProvider.notifier)
          .markSessionEnded('entry-1');

      // Read again — state should persist because keepAlive: true
      final state = container.read(sessionEndedControllerProvider);
      expect(state, contains('entry-1'));
    });
  });
}
