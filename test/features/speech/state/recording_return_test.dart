import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recording_return.dart';

void main() {
  group('RecordingOriginScroll', () {
    late RecordingOriginScroll scroll;
    setUp(() => scroll = RecordingOriginScroll());

    test('remembers the last offset each route reported', () {
      scroll
        ..report('/tasks/t-1', 100)
        ..report('/tasks/t-1', 180)
        ..report('/projects/p-1', 40);
      expect(scroll.offsetFor('/tasks/t-1'), 180);
      expect(scroll.offsetFor('/projects/p-1'), 40);
      expect(scroll.offsetFor('/calendar'), isNull);
    });

    test('forget drops a route', () {
      scroll
        ..report('/tasks/t-1', 100)
        ..forget('/tasks/t-1');
      expect(scroll.offsetFor('/tasks/t-1'), isNull);
    });

    test('a requested restore is handed to its route once', () {
      scroll.requestRestore('/tasks/t-1', 240);
      expect(scroll.takeRestore('/tasks/t-1'), 240);
      expect(scroll.takeRestore('/tasks/t-1'), isNull);
    });

    test("another route's page gets nothing, and leaves the restore owed", () {
      scroll.requestRestore('/tasks/t-1', 240);
      expect(scroll.takeRestore('/tasks/t-2'), isNull);
      expect(scroll.takeRestore('/tasks/t-1'), 240);
    });

    test('a newer request replaces an older one', () {
      scroll
        ..requestRestore('/tasks/t-1', 240)
        ..requestRestore('/tasks/t-2', 60);
      expect(scroll.takeRestore('/tasks/t-1'), isNull);
      expect(scroll.takeRestore('/tasks/t-2'), 60);
    });
  });

  group('recordingArrivalProvider', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('starts with no arrival', () {
      expect(container.read(recordingArrivalProvider), isNull);
    });

    test('each arrival is a new value, even at the same subject', () {
      final arrivals = <RecordingArrival?>[];
      container.listen(
        recordingArrivalProvider,
        (_, next) => arrivals.add(next),
      );
      container.read(recordingArrivalProvider.notifier)
        ..arrive('task-1')
        ..arrive('task-1')
        ..arrive('task-2');
      expect(arrivals, [
        (subjectId: 'task-1', serial: 1),
        (subjectId: 'task-1', serial: 2),
        (subjectId: 'task-2', serial: 3),
      ]);
    });
  });
}
