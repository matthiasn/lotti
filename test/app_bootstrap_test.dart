import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/inert_outbox_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:path/path.dart' as p;

import 'helpers/db_settle.dart';
import 'helpers/entity_factories.dart';

/// Recursive snapshot of a directory subtree: relative path -> file length.
/// [exclude] prunes subtrees (e.g. the guest worlds container).
Map<String, int> snapshotTree(Directory dir, {Set<String> exclude = const {}}) {
  final result = <String, int>{};
  if (!dir.existsSync()) return result;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: dir.path);
    final top = p.split(rel).first;
    if (exclude.contains(top)) continue;
    result[rel] = entity.lengthSync();
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory osRoot;
  var keychainReads = 0;

  void mockChannels() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => osRoot.path,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          if (call.method == 'read' || call.method == 'readAll') {
            keychainReads++;
          }
          return null;
        },
      )
      ..setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (MethodCall call) async => null,
      );
  }

  void unmockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'plugins.flutter.io/path_provider',
      'plugins.it_nomads.com/flutter_secure_storage',
      'window_manager',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  }

  setUp(() async {
    await getIt.reset();
    osRoot = Directory.systemTemp.createTempSync('lotti_boot_');
    keychainReads = 0;
    mockChannels();
  });

  tearDown(() async {
    await settlePendingDbWork();
    await ServiceDisposer(getIt, (e, s, n) {}).disposeAll();
    await getIt.reset();
    unmockChannels();
    if (osRoot.existsSync()) {
      await osRoot.delete(recursive: true);
    }
  });

  group('resolveActiveProfile', () {
    test(
      'no registry file resolves to the real world at the OS root',
      () async {
        final info = await resolveActiveProfile();

        expect(info.active.id, Profile.realProfileId);
        expect(info.activeRoot.path, osRoot.path);
        expect(info.realRoot.path, osRoot.path);
      },
    );

    test('active guest marker resolves to the guest root', () async {
      final registry = ProfileRegistry(realRoot: osRoot);
      final guest = await registry.createGuestProfile(name: 'Demo');
      await registry.setActiveProfile(guest.id);

      final info = await resolveActiveProfile();

      expect(info.active.id, guest.id);
      expect(info.activeRoot.path, registry.rootFor(guest).path);
      expect(info.realRoot.path, osRoot.path);
    });
  });

  group('guest boot isolation audit', () {
    test(
      'a full guest bootstrap never touches the real world, constructs no '
      'Matrix stack, reads no keychain, and mints its own host id',
      () async {
        // Canary content standing in for a real user's world.
        File(
          p.join(osRoot.path, 'db.sqlite'),
        ).writeAsStringSync('real journal');
        Directory(
          p.join(osRoot.path, 'images', '2026-08-01'),
        ).createSync(recursive: true);
        File(
          p.join(osRoot.path, 'images', '2026-08-01', 'photo.jpg'),
        ).writeAsStringSync('real photo');

        final registry = ProfileRegistry(realRoot: osRoot);
        final guest = await registry.createGuestProfile(name: 'Demo');
        await registry.setActiveProfile(guest.id);
        // The guest dir vanished externally (dangling marker): boot must
        // recreate the skeleton rather than fail.
        await registry.rootFor(guest).delete(recursive: true);
        final before = snapshotTree(
          osRoot,
          exclude: {'guest_profiles'},
        );

        registerProcessLogging();
        final info = await resolveActiveProfile();
        final lifecycleHolder = AppLifecycleHolder();
        addTearDown(lifecycleHolder.dispose);
        final context = await bootstrapProfileServices(
          info,
          lifecycleHolder: lifecycleHolder,
          // Default restoreWindow: exercises the cold-boot geometry restore
          // against the mocked window_manager channel.
        );

        // Capability wiring.
        expect(context.isGuest, isTrue);
        expect(context.capabilities.syncEnabled, isFalse);
        expect(getIt<ProfileContext>().profile.id, guest.id);
        expect(getIt<Directory>().path, registry.rootFor(guest).path);

        // The Matrix stack is structurally absent; the outbox is inert.
        expect(getIt.isRegistered<MatrixService>(), isFalse);
        expect(getIt<OutboxService>(), isA<InertOutboxService>());

        // The provider bridge omits matrixServiceProvider in guest mode:
        // 7 overrides instead of the real profile's 8.
        expect(buildProviderOverrides(context), hasLength(7));

        // A representative write lands in the guest world only.
        final task = TestTaskFactory.create(id: 'guest-task-1');
        await getIt<JournalDb>().updateJournalEntity(task);
        final persisted = await getIt<JournalDb>().journalEntityById(
          'guest-task-1',
        );
        expect(persisted, isNotNull);
        final guestSidecars = Directory(
          p.join(registry.rootFor(guest).path, 'tasks'),
        );
        expect(guestSidecars.existsSync(), isTrue);

        // Own sync identity: the host id exists in the guest settings db;
        // the real world has no settings.sqlite at all.
        final hostId = await getIt<VectorClockService>().getHost();
        expect(hostId, isNotNull);
        expect(
          File(p.join(osRoot.path, 'settings.sqlite')).existsSync(),
          isFalse,
        );

        // Zero keychain reads during the whole guest boot + write.
        expect(keychainReads, 0);

        // Let unawaited startup writes settle, then: the real world is
        // byte-identical.
        await pumpEventQueue(times: 200);
        expect(
          snapshotTree(osRoot, exclude: {'guest_profiles'}),
          before,
        );
      },
    );
  });

  group('real-profile bootstrap', () {
    test('registers the world-scoped primitives against the OS root', () async {
      registerProcessLogging();
      final info = await resolveActiveProfile();
      final lifecycleHolder = AppLifecycleHolder();
      addTearDown(lifecycleHolder.dispose);
      final context = await bootstrapProfileServices(
        info,
        lifecycleHolder: lifecycleHolder,
        restoreWindow: false,
        registerLateAndOptional: false,
      );

      expect(context.isGuest, isFalse);
      expect(getIt<Directory>().path, osRoot.path);

      // The full Matrix stack exists in a real profile...
      expect(getIt.isRegistered<MatrixService>(), isTrue);
      expect(getIt<OutboxService>(), isA<MatrixOutboxService>());
      // ...its session store lives under the real root...
      expect(
        File(p.join(osRoot.path, 'matrix', 'lotti_sync.db')).existsSync(),
        isTrue,
      );
      // ...and the bridge carries all 8 overrides including Matrix.
      expect(buildProviderOverrides(context), hasLength(8));

      // The startup node-profile broadcast reaches the outbox: real sync
      // wiring, end to end, without any network.
      await settlePendingDbWork();
      final syncDb = getIt<SyncDatabase>();
      final countAfterBoot = await syncDb.watchOutboxCount().first;
      expect(countAfterBoot, greaterThanOrEqualTo(1));

      // Releasing a reserved vector clock burns the counter: the burn
      // handler broadcasts an unresolvable backfill marker through the
      // outbox so peers can close the gap.
      final reservation = await getIt<VectorClockService>()
          .reserveNextVectorClock();
      await reservation.release();
      await settlePendingDbWork();
      final countAfterBurn = await syncDb.watchOutboxCount().first;
      expect(countAfterBurn, greaterThan(countAfterBoot));

      // The gap-detection hook is wired to the backfill nudge; invoking it
      // must not throw (nudge is a no-op without missing entries).
      final sequenceLog = getIt<SyncSequenceLogService>();
      expect(sequenceLog.onMissingEntriesDetected, isNotNull);
      sequenceLog.onMissingEntriesDetected!.call();

      // The AI attribution identity resolver consumes the Matrix user-id
      // thunk wired by the sync registration (no session → null id, local
      // principal only).
      final actor = await getIt<AiAttributionIdentityResolver>()
          .humanInitiator();
      expect(actor, isNotNull);
    });

    test('window close after a guest bootstrap runs the pre-flush hook and '
        'releases the app-exit listener', () async {
      final registry = ProfileRegistry(realRoot: osRoot);
      final guest = await registry.createGuestProfile(name: 'Demo');
      await registry.setActiveProfile(guest.id);
      registerProcessLogging();
      final lifecycleHolder = AppLifecycleHolder();
      await bootstrapProfileServices(
        await resolveActiveProfile(),
        lifecycleHolder: lifecycleHolder,
        restoreWindow: false,
        registerLateAndOptional: false,
      );
      lifecycleHolder.listener = AppLifecycleListener();
      await settlePendingDbWork();

      await getIt<WindowService>().shutdown();

      // The shutdown pre-flush hook disposed the app-exit listener.
      expect(lifecycleHolder.listener, isNull);
    });

    test(
      'burn-pending counters from a crashed process are reconciled into '
      'unresolvable markers at boot',
      () async {
        // Simulate the previous process: a persisted host id and a vector
        // clock counter that was released (burned) but whose outbound
        // marker never reached the outbox before the crash.
        const crashHost = 'crash-host-1';
        Future<Directory> provider() async => osRoot;
        final priorSettings = SettingsDb(documentsDirectoryProvider: provider);
        await priorSettings.saveSettingsItem(hostKey, crashHost);
        await priorSettings.saveSettingsItem(nextAvailableCounterKey, '5');
        await priorSettings.close();
        final priorSync = SyncDatabase(documentsDirectoryProvider: provider);
        await priorSync.markReservedSequenceCounterBurnPending(
          hostId: crashHost,
          counter: 3,
        );
        // A plain reserved counter (crash between reserve and write): must
        // NOT be broadcast as unresolvable — only audited.
        await priorSync.recordReservedSequenceCounter(
          hostId: crashHost,
          counter: 4,
        );
        await priorSync.close();

        registerProcessLogging();
        final info = await resolveActiveProfile();
        final lifecycleHolder = AppLifecycleHolder();
        addTearDown(lifecycleHolder.dispose);
        await bootstrapProfileServices(
          info,
          lifecycleHolder: lifecycleHolder,
          restoreWindow: false,
          registerLateAndOptional: false,
        );

        // Reconciliation is fire-and-forget; settle it, then: the burn is
        // terminal and its unresolvable marker is queued for peers.
        await settlePendingDbWork();
        final syncDb = getIt<SyncDatabase>();
        expect(
          await syncDb.burnPendingSequenceCountersForHost(hostId: crashHost),
          isEmpty,
        );
        // The plain reservation was audited, not burned.
        expect(
          await syncDb.reservedSequenceCountersForHost(hostId: crashHost),
          [4],
        );
        // Startup broadcast + the reconciled marker.
        expect(await syncDb.watchOutboxCount().first, greaterThanOrEqualTo(2));
        // The reconciled world kept the crashed process's host identity.
        expect(await getIt<VectorClockService>().getHost(), crashHost);
      },
    );
  });
}
