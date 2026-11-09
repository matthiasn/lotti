import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late ProviderContainer container;

  setUp(() async {
    mocks = await setUpTestGetIt();
    container = ProviderContainer(overrides: getItServiceOverrides());
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  const phone = CompanionCardForm.phone;
  const desktop = CompanionCardForm.desktop;

  CompanionCardPlacement read([CompanionCardForm form = phone]) =>
      container.read(companionCardControllerProvider(form));

  CompanionCardController notifier([CompanionCardForm form = phone]) =>
      container.read(companionCardControllerProvider(form).notifier);

  /// Reads the provider, then lets its load from SettingsDb land.
  Future<CompanionCardPlacement> hydrated([
    CompanionCardForm form = phone,
  ]) async {
    read(form);
    await pumpEventQueue();
    return read(form);
  }

  void stored(CompanionCardForm form, String? value) => when(
    () => mocks.settingsDb.itemByKey(form.settingsKey),
  ).thenAnswer((_) async => value);

  test('a placement is a value: equal fields compare and hash alike, and '
      'it prints them', () {
    const a = CompanionCardPlacement(x: 0.25, y: 1, height: 300);
    const b = CompanionCardPlacement(x: 0.25, y: 1, height: 300);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const CompanionCardPlacement(x: 0.25, y: 1, height: 301)));
    expect(a.toString(), 'CompanionCardPlacement(0.25, 1.0, 300.0)');
  });

  group('loading', () {
    test('first run: small, in the bottom-right corner', () async {
      expect(
        await hydrated(),
        const CompanionCardPlacement(x: 1, y: 1, height: 172),
      );
      expect(
        await hydrated(desktop),
        const CompanionCardPlacement(x: 1, y: 1, height: 240),
      );
    });

    test('takes the placement saved for its own form', () async {
      stored(phone, jsonEncode({'x': 0.25, 'y': 0.1, 'h': 300}));
      stored(desktop, jsonEncode({'x': 0.5, 'y': 0.5, 'h': 500}));

      expect(
        await hydrated(),
        const CompanionCardPlacement(x: 0.25, y: 0.1, height: 300),
      );
      expect(
        await hydrated(desktop),
        const CompanionCardPlacement(x: 0.5, y: 0.5, height: 500),
      );
    });

    test('clamps a saved placement into range', () async {
      stored(phone, jsonEncode({'x': -2, 'y': 3, 'h': 10}));

      expect(
        await hydrated(),
        const CompanionCardPlacement(
          x: 0,
          y: 1,
          height: minCompanionCardHeight,
        ),
      );
    });

    for (final (name, value) in [
      ('not JSON', 'corner'),
      ('not an object', '[1, 2, 3]'),
      ('missing a field', jsonEncode({'x': 0.5, 'y': 0.5})),
      ('a field of the wrong type', jsonEncode({'x': 'a', 'y': 0, 'h': 200})),
    ]) {
      test('keeps the first placement when what is saved is $name', () async {
        stored(phone, value);

        expect(await hydrated(), phone.initial);
      });
    }

    test('a move made while the saved placement loads wins over it', () async {
      stored(phone, jsonEncode({'x': 0, 'y': 0, 'h': 300}));
      read();
      notifier().resizeTo(200);
      await pumpEventQueue();

      expect(read(), const CompanionCardPlacement(x: 1, y: 1, height: 200));
    });
  });

  group('changes', () {
    test('moveBy shifts by shares of the room, kept inside it', () async {
      await hydrated();
      notifier().moveBy(-0.4, -0.25);
      expect(read().x, closeTo(0.6, 1e-9));
      expect(read().y, closeTo(0.75, 1e-9));

      notifier().moveBy(-5, 5);
      expect((read().x, read().y), (0.0, 1.0));
    });

    test('resizeTo keeps the height between its bounds', () async {
      await hydrated();
      notifier().resizeTo(50);
      expect(read().height, minCompanionCardHeight);

      notifier().resizeTo(5000);
      expect(read().height, maxCompanionCardHeight);
    });

    test('toggleSize grows small to large and anything larger back to '
        'small', () async {
      await hydrated();
      notifier().toggleSize();
      expect(read().height, phone.largeHeight);

      notifier().toggleSize();
      expect(read().height, phone.smallHeight);

      notifier()
        ..resizeTo(250)
        ..toggleSize();
      expect(read().height, phone.smallHeight);
    });

    test('reset returns to the first placement', () async {
      await hydrated();
      notifier()
        ..moveBy(-1, -1)
        ..resizeTo(500)
        ..reset();

      expect(read(), phone.initial);
    });

    test('inLowerHalf is true from the middle down', () {
      expect(
        const CompanionCardPlacement(x: 0, y: 0.5, height: 200).inLowerHalf,
        isTrue,
      );
      expect(
        const CompanionCardPlacement(x: 0, y: 0.49, height: 200).inLowerHalf,
        isFalse,
      );
    });
  });

  group('saving', () {
    test('writes once after a burst of moves, under its own form', () {
      fakeAsync((async) {
        read();
        async.flushMicrotasks();
        notifier()
          ..moveBy(-0.5, 0)
          ..moveBy(0, -0.5)
          ..resizeTo(200);
        async.elapse(companionCardPersistDebounce * 0.5);
        verifyNever(() => mocks.settingsDb.saveSettingsItem(any(), any()));

        async.elapse(companionCardPersistDebounce);
        verify(
          () => mocks.settingsDb.saveSettingsItem(
            phone.settingsKey,
            jsonEncode({'x': 0.5, 'y': 0.5, 'h': 200.0}),
          ),
        ).called(1);
        verifyNever(
          () => mocks.settingsDb.saveSettingsItem(desktop.settingsKey, any()),
        );
      });
    });

    test('a change that changes nothing is not written', () {
      fakeAsync((async) {
        read();
        async.flushMicrotasks();
        notifier().moveBy(1, 1);
        async.elapse(companionCardPersistDebounce * 2);

        verifyNever(() => mocks.settingsDb.saveSettingsItem(any(), any()));
      });
    });
  });
}
