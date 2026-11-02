import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/state/goal_timeline_rail_width_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// A container whose settings store holds [persisted] for the rail.
Future<(ProviderContainer, MockSettingsDb)> _containerWith({
  String? persisted,
  Future<Map<String, String?>>? load,
}) async {
  await tearDownTestGetIt();
  final mocks = await setUpTestGetIt();
  when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
    (_) => load ?? Future.value({goalTimelineRailWidthKey: persisted}),
  );
  when(
    () => mocks.settingsDb.saveSettingsItem(any(), any()),
  ).thenAnswer((_) async => 1);
  final container = ProviderContainer(overrides: getItServiceOverrides());
  addTearDown(container.dispose);
  return (container, mocks.settingsDb);
}

/// The rail width once the stored one has loaded.
Future<double?> _hydrated(ProviderContainer container) =>
    container.read(goalTimelineRailWidthProvider.future);

void main() {
  tearDown(tearDownTestGetIt);

  group('loading', () {
    test('null until the person has dragged it', () async {
      final (container, _) = await _containerWith();
      expect(await _hydrated(container), isNull);
    });

    test('a stored width is adopted, clamped to the drag range', () async {
      var (container, _) = await _containerWith(persisted: '612.5');
      expect(await _hydrated(container), 612.5);
      (container, _) = await _containerWith(persisted: '5000');
      expect(await _hydrated(container), kGoalTimelineRailDragMaxWidth);
      (container, _) = await _containerWith(persisted: '12');
      expect(await _hydrated(container), kGoalTimelineRailMinWidth);
    });

    test('a stored value that is no width is ignored', () async {
      var (container, _) = await _containerWith(persisted: 'wide');
      expect(await _hydrated(container), isNull);
      (container, _) = await _containerWith(persisted: 'Infinity');
      expect(await _hydrated(container), isNull);
    });

    test('a drag before the load wins over it', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String?>>();
        late ProviderContainer container;
        late MockSettingsDb settingsDb;
        _containerWith(
          load: load.future,
        ).then((value) => (container, settingsDb) = value);
        async.flushMicrotasks();
        double? loaded;
        _hydrated(container).then((value) => loaded = value);
        container.read(goalTimelineRailWidthProvider.notifier).set(500);
        load.complete({goalTimelineRailWidthKey: '700'});
        async.flushMicrotasks();
        expect(loaded, 500);
        expect(container.read(goalTimelineRailWidthProvider).value, 500);

        // The drag's own write lands once it rests, and the stored 700
        // never comes back.
        async.elapse(goalTimelineRailPersistDebounce);
        verify(
          () => settingsDb.saveSettingsItem(goalTimelineRailWidthKey, '500.0'),
        ).called(1);
        expect(container.read(goalTimelineRailWidthProvider).value, 500);
      });
    });

    test('a failing load leaves the rail undragged', () async {
      final (container, settingsDb) = await _containerWith();
      when(
        () => settingsDb.itemsByKeys(any()),
      ).thenAnswer((_) => Future.error(StateError('disk')));
      expect(await _hydrated(container), isNull);
    });
  });

  group('dragging', () {
    test('clamps, and writes once the drag rests', () {
      fakeAsync((async) {
        late MockSettingsDb settingsDb;
        late ProviderContainer container;
        _containerWith().then((value) => (container, settingsDb) = value);
        async.flushMicrotasks();
        final notifier = container.read(goalTimelineRailWidthProvider.notifier)
          ..set(420)
          ..set(450)
          ..set(9000);
        expect(
          container.read(goalTimelineRailWidthProvider).value,
          kGoalTimelineRailDragMaxWidth,
        );
        verifyNever(() => settingsDb.saveSettingsItem(any(), any()));

        async.elapse(goalTimelineRailPersistDebounce);
        verify(
          () => settingsDb.saveSettingsItem(goalTimelineRailWidthKey, '800.0'),
        ).called(1);

        // The same width again writes nothing.
        notifier.set(kGoalTimelineRailDragMaxWidth);
        async.elapse(goalTimelineRailPersistDebounce);
        verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
      });
    });

    test('a failing write keeps the dragged width', () {
      fakeAsync((async) {
        late MockSettingsDb settingsDb;
        late ProviderContainer container;
        _containerWith().then((value) => (container, settingsDb) = value);
        async.flushMicrotasks();
        when(
          () => settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) => Future.error(StateError('disk full')));
        container.read(goalTimelineRailWidthProvider.notifier).set(480);
        async
          ..elapse(goalTimelineRailPersistDebounce)
          ..flushMicrotasks();
        expect(container.read(goalTimelineRailWidthProvider).value, 480);
      });
    });
  });
}
