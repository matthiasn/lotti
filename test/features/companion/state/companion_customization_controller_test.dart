import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const _afro = CompanionCustomization(hairStyle: CompanionHairStyle.afro);
const _locs = CompanionCustomization(
  hairStyle: CompanionHairStyle.locs,
  skinTone: CompanionSkinTone.tone5,
);

String _json(CompanionCustomization c) => jsonEncode(c.toJson());

void main() {
  setUpAll(registerAllFallbackValues);

  late MockSettingsDb db;
  late MockOutboxService outbox;
  late MockDomainLogger logger;
  late StreamController<Set<String>> updates;

  setUp(() {
    db = MockSettingsDb();
    outbox = MockOutboxService();
    logger = MockDomainLogger();
    updates = StreamController<Set<String>>.broadcast();
    when(() => db.itemsByKeys(any())).thenAnswer((_) async => const {});
    when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
  });
  tearDown(() => updates.close());

  /// A container on the mocks, the customization read once.
  ProviderContainer start(FakeAsync async) {
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    final c = ProviderContainer(
      overrides: [
        settingsDbProvider.overrideWithValue(db),
        outboxServiceProvider.overrideWithValue(outbox),
        domainLoggerProvider.overrideWithValue(logger),
        maybeUpdateNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(c.dispose);
    c.listen(companionCustomizationProvider, (_, _) {});
    async.flushMicrotasks();
    return c;
  }

  void stored(Map<String, String> values) =>
      when(() => db.itemsByKeys(any())).thenAnswer((_) async => values);

  List<SyncCompanionCustomization> sent() => verify(
    () => outbox.enqueueMessage(captureAny()),
  ).captured.cast<SyncCompanionCustomization>();

  /// Past the quarter-second debounce, and the writes after it.
  void settle(FakeAsync async) {
    async
      ..elapse(const Duration(milliseconds: 300))
      ..flushMicrotasks();
  }

  group('loading', () {
    test('starts as Lotti with nothing stored, and sends nothing', () {
      fakeAsync((async) {
        final c = start(async);
        settle(async);
        expect(
          c.read(companionCustomizationProvider),
          const CompanionCustomization(),
        );
        verifyNever(() => outbox.enqueueMessage(any()));
      });
    });

    test('reads what is stored, and sends nothing once it is published', () {
      fakeAsync((async) {
        stored({
          companionCustomizationKey: _json(_afro),
          companionCustomizationUpdatedAtKey: '500',
          companionCustomizationSyncedAtKey: '500',
        });
        final c = start(async);
        settle(async);
        expect(c.read(companionCustomizationProvider), _afro);
        verifyNever(() => outbox.enqueueMessage(any()));
      });
    });

    test('publishes, once, a customization never sent to the others', () {
      fakeAsync((async) {
        stored({
          companionCustomizationKey: _json(_afro),
          companionCustomizationUpdatedAtKey: '500',
          companionCustomizationSyncedAtKey: '400',
        });
        start(async);
        settle(async);
        final message = sent().single;
        expect(message.customization, _json(_afro));
        expect(message.updatedAt, 500);
        verify(
          () => db.saveSettingsItem(companionCustomizationSyncedAtKey, '500'),
        ).called(1);
      });
    });

    test('one without a stamp shows, but has nothing to win with and is '
        'not sent', () {
      fakeAsync((async) {
        stored({companionCustomizationKey: _json(_afro)});
        final c = start(async);
        settle(async);
        expect(c.read(companionCustomizationProvider), _afro);
        verifyNever(() => outbox.enqueueMessage(any()));
      });
    });

    test('a change made before the load lands is not undone by it', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String>>();
        when(() => db.itemsByKeys(any())).thenAnswer((_) => load.future);
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer(
          (_) async =>
              (updatedAt: 9, values: {companionCustomizationKey: '{}'}),
        );
        final c = start(async);
        c.read(companionCustomizationProvider.notifier).set(_locs);
        load.complete({companionCustomizationKey: _json(_afro)});
        async.flushMicrotasks();
        expect(c.read(companionCustomizationProvider), _locs);
      });
    });

    test('is known once read — nothing stored counts — or once set; not '
        'while the read is pending', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String>>();
        when(() => db.itemsByKeys(any())).thenAnswer((_) => load.future);
        final c = start(async);
        final controller = c.read(companionCustomizationProvider.notifier);
        expect(controller.loaded, isFalse);

        load.complete(const {});
        async.flushMicrotasks();
        expect(controller.loaded, isTrue);
      });
    });

    test('a read that fails leaves it unknown, so nothing guesses at it', () {
      fakeAsync((async) {
        stored({companionCustomizationKey: 'not json'});
        final c = start(async);
        settle(async);
        expect(c.read(companionCustomizationProvider.notifier).loaded, isFalse);
      });
    });

    test('a change made while the load is out is laid over what it finds: '
        'a stored mute is kept, and only that is written', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String>>();
        when(() => db.itemsByKeys(any())).thenAnswer((_) => load.future);
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer(
          (invocation) async => (
            updatedAt: 9,
            values: Map<String, String>.from(
              invocation.positionalArguments.first as Map,
            ),
          ),
        );
        final c = start(async);
        final controller = c.read(companionCustomizationProvider.notifier)
          ..set(const CompanionCustomization(sass: CompanionSass.warm));
        // Shown at once, written only once the read lands.
        expect(c.read(companionCustomizationProvider).sass, CompanionSass.warm);
        verifyNever(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        );

        load.complete({
          companionCustomizationKey: _json(
            const CompanionCustomization(speaksReplies: false),
          ),
        });
        async.flushMicrotasks();

        expect(
          c.read(companionCustomizationProvider),
          const CompanionCustomization(
            sass: CompanionSass.warm,
            speaksReplies: false,
          ),
        );
        expect(controller.loaded, isTrue);
        final written =
            verify(
                  () => db.saveLocalSettingsGroup(
                    captureAny(),
                    stampKey: any(named: 'stampKey'),
                    timestamp: any(named: 'timestamp'),
                  ),
                ).captured.single
                as Map<String, String>;
        expect(
          written[companionCustomizationKey],
          contains('"speaksReplies":false'),
        );
        expect(written[companionCustomizationKey], contains('"sass":"warm"'));
      });
    });

    test('a part switched off and back on while the load is out counts as '
        'set: the stored mute gives way to the last choice', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String>>();
        when(() => db.itemsByKeys(any())).thenAnswer((_) => load.future);
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer(
          (_) async =>
              (updatedAt: 9, values: {companionCustomizationKey: '{}'}),
        );
        final c = start(async);
        c.read(companionCustomizationProvider.notifier)
          ..set(const CompanionCustomization(speaksReplies: false))
          ..set(const CompanionCustomization());

        load.complete({
          companionCustomizationKey: _json(
            const CompanionCustomization(
              speaksReplies: false,
              sass: CompanionSass.sassy,
            ),
          ),
        });
        async.flushMicrotasks();

        expect(
          c.read(companionCustomizationProvider),
          const CompanionCustomization(sass: CompanionSass.sassy),
        );
      });
    });

    test('a reload sync asks for while the load is out waits, and does not '
        'undo a change made meanwhile', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String>>();
        when(() => db.itemsByKeys(any())).thenAnswer((_) => load.future);
        // Storage as it stands: the default, until the change is written.
        var storedJson = _json(const CompanionCustomization());
        when(
          () => db.itemByKey(companionCustomizationKey),
        ).thenAnswer((_) async => storedJson);
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer((invocation) async {
          final values = Map<String, String>.from(
            invocation.positionalArguments.first as Map,
          );
          storedJson = values[companionCustomizationKey]!;
          return (updatedAt: 9, values: values);
        });
        final c = start(async);
        c
            .read(companionCustomizationProvider.notifier)
            .set(const CompanionCustomization(speaksReplies: false));
        updates.add({settingsNotification});
        async.flushMicrotasks();
        verifyNever(() => db.itemByKey(companionCustomizationKey));
        expect(c.read(companionCustomizationProvider).speaksReplies, isFalse);

        load.complete(const {});
        async.flushMicrotasks();

        // The change is written, and the reload asked for runs after it.
        expect(c.read(companionCustomizationProvider).speaksReplies, isFalse);
        verify(() => db.itemByKey(companionCustomizationKey)).called(1);
        verify(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).called(1);
      });
    });

    test('a change made while a read fails is still stored', () {
      fakeAsync((async) {
        final load = Completer<Map<String, String>>();
        when(() => db.itemsByKeys(any())).thenAnswer((_) => load.future);
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer(
          (_) async =>
              (updatedAt: 9, values: {companionCustomizationKey: '{}'}),
        );
        final c = start(async);
        c.read(companionCustomizationProvider.notifier).set(_locs);

        load.completeError(StateError('disk'));
        async.flushMicrotasks();

        expect(c.read(companionCustomizationProvider), _locs);
        verify(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).called(1);
      });
    });

    test('storage it cannot read is logged, and she stays as she is', () {
      fakeAsync((async) {
        stored({companionCustomizationKey: 'not json'});
        final c = start(async);
        settle(async);
        expect(
          c.read(companionCustomizationProvider),
          const CompanionCustomization(),
        );
        verify(
          () => logger.error(
            LogDomain.settings,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'companionCustomization',
            message: 'Could not load her customization',
          ),
        ).called(1);
        verifyNever(() => outbox.enqueueMessage(any()));
      });
    });
  });

  group('a change', () {
    void storesWithStamp(int updatedAt) =>
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer((invocation) async {
          final values =
              invocation.positionalArguments.first as Map<String, String>;
          return (updatedAt: updatedAt, values: Map.of(values));
        });

    test('shows at once, is stored with a stamp, and is sent with it', () {
      fakeAsync((async) {
        storesWithStamp(777);
        final c = start(async);
        c.read(companionCustomizationProvider.notifier).set(_locs);
        expect(c.read(companionCustomizationProvider), _locs);
        settle(async);

        verify(
          () => db.saveLocalSettingsGroup(
            {companionCustomizationKey: _json(_locs)},
            stampKey: companionCustomizationUpdatedAtKey,
            timestamp: any(named: 'timestamp'),
          ),
        ).called(1);
        final message = sent().single;
        expect(message.customization, _json(_locs));
        expect(message.updatedAt, 777);
        expect(message.status, SyncEntryStatus.update);
        verify(
          () => db.saveSettingsItem(companionCustomizationSyncedAtKey, '777'),
        ).called(1);
      });
    });

    test('keeps, and sends, what a newer version wrote in the parts it '
        'leaves alone', () {
      fakeAsync((async) {
        storesWithStamp(900);
        const newer = {
          'skinTone': 'tone2',
          'hairStyle': 'mohawk',
          'hairColour': 'black',
          'eyes': 'green',
        };
        stored({companionCustomizationKey: jsonEncode(newer)});
        final c = start(async);
        c
            .read(companionCustomizationProvider.notifier)
            .set(
              c
                  .read(companionCustomizationProvider)
                  .copyWith(skinTone: CompanionSkinTone.tone5),
            );
        settle(async);

        final expected = jsonEncode({...newer, 'skinTone': 'tone5'});
        verify(
          () => db.saveLocalSettingsGroup(
            {companionCustomizationKey: expected},
            stampKey: companionCustomizationUpdatedAtKey,
            timestamp: any(named: 'timestamp'),
          ),
        ).called(1);
        expect(sent().single.customization, expected);
      });
    });

    test('a run of taps goes out as one message, the last', () {
      fakeAsync((async) {
        storesWithStamp(800);
        final c = start(async);
        final controller = c.read(companionCustomizationProvider.notifier)
          ..set(_afro);
        async.flushMicrotasks();
        controller.set(_locs);
        settle(async);
        expect(sent().single.customization, _json(_locs));
      });
    });

    test('a write that fails is logged, sends nothing, and still shows', () {
      fakeAsync((async) {
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer((_) => Future.error(StateError('disk full')));
        final c = start(async);
        c.read(companionCustomizationProvider.notifier).set(_locs);
        settle(async);
        expect(c.read(companionCustomizationProvider), _locs);
        verifyNever(() => outbox.enqueueMessage(any()));
        verify(
          () => logger.error(
            LogDomain.settings,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'companionCustomization',
            message: 'Could not store her customization',
          ),
        ).called(1);
      });
    });

    test('a send that fails is logged, and is not marked as published', () {
      fakeAsync((async) {
        storesWithStamp(900);
        when(
          () => outbox.enqueueMessage(any()),
        ).thenAnswer((_) => Future.error(StateError('no outbox')));
        final c = start(async);
        c.read(companionCustomizationProvider.notifier).set(_locs);
        settle(async);
        verifyNever(
          () => db.saveSettingsItem(companionCustomizationSyncedAtKey, any()),
        );
        verify(
          () => logger.error(
            LogDomain.settings,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'companionCustomization',
            message: 'Could not send her customization',
          ),
        ).called(1);
      });
    });
  });

  group('from another device', () {
    test('a synced change reloads her, and is never sent back', () {
      fakeAsync((async) {
        final c = start(async);
        when(
          () => db.itemByKey(companionCustomizationKey),
        ).thenAnswer((_) async => _json(_locs));
        updates.add({settingsNotification});
        settle(async);
        expect(c.read(companionCustomizationProvider), _locs);
        verifyNever(() => outbox.enqueueMessage(any()));
      });
    });

    test('a change after it keeps what a newer device wrote there', () {
      fakeAsync((async) {
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer(
          (invocation) async => (
            updatedAt: 1,
            values: Map.of(
              invocation.positionalArguments.first as Map<String, String>,
            ),
          ),
        );
        final c = start(async);
        const newer = {
          'skinTone': 'tone1',
          'hairStyle': 'mohawk',
          'hairColour': 'silver',
        };
        when(
          () => db.itemByKey(companionCustomizationKey),
        ).thenAnswer((_) async => jsonEncode(newer));
        updates.add({settingsNotification});
        settle(async);
        c
            .read(companionCustomizationProvider.notifier)
            .set(
              c
                  .read(companionCustomizationProvider)
                  .copyWith(hairColour: CompanionHairColour.pink),
            );
        settle(async);
        expect(
          sent().single.customization,
          jsonEncode({...newer, 'hairColour': 'pink'}),
        );
      });
    });

    test('a reload during a save waits for it, so she never shows the value '
        'it replaces', () {
      fakeAsync((async) {
        final saving =
            Completer<({int updatedAt, Map<String, String> values})>();
        when(
          () => db.saveLocalSettingsGroup(
            any(),
            stampKey: any(named: 'stampKey'),
            timestamp: any(named: 'timestamp'),
          ),
        ).thenAnswer((_) => saving.future);
        // Until the save commits, storage still holds the old value.
        var storedJson = _json(_afro);
        when(
          () => db.itemByKey(companionCustomizationKey),
        ).thenAnswer((_) async => storedJson);
        final c = start(async);
        c.read(companionCustomizationProvider.notifier).set(_locs);
        // Another setting synced in while the save is in flight.
        updates.add({settingsNotification});
        async.flushMicrotasks();
        expect(c.read(companionCustomizationProvider), _locs);
        verifyNever(() => db.itemByKey(any()));

        storedJson = _json(_locs);
        saving.complete((
          updatedAt: 950,
          values: {companionCustomizationKey: _json(_locs)},
        ));
        settle(async);
        // The deferred reload runs once the save lands, and reads the winner.
        verify(() => db.itemByKey(companionCustomizationKey)).called(1);
        expect(c.read(companionCustomizationProvider), _locs);
      });
    });

    test('other notifications leave her as she is', () {
      fakeAsync((async) {
        final c = start(async);
        updates.add({'SOMETHING_ELSE'});
        settle(async);
        verifyNever(() => db.itemByKey(any()));
        expect(
          c.read(companionCustomizationProvider),
          const CompanionCustomization(),
        );
      });
    });

    test('a reload that fails is logged, and she stays as she is', () {
      fakeAsync((async) {
        final c = start(async);
        when(
          () => db.itemByKey(companionCustomizationKey),
        ).thenAnswer((_) async => '{broken');
        updates.add({settingsNotification});
        settle(async);
        expect(
          c.read(companionCustomizationProvider),
          const CompanionCustomization(),
        );
        verify(
          () => logger.error(
            LogDomain.settings,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'companionCustomization',
            message: 'Could not reload her customization',
          ),
        ).called(1);
      });
    });
  });
}
