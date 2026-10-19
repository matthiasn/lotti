import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
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

    test('one from before sync goes out with the oldest stamp, so it never '
        'overrides a real change', () {
      fakeAsync((async) {
        stored({companionCustomizationKey: _json(_afro)});
        start(async);
        settle(async);
        expect(sent().single.updatedAt, 1);
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
