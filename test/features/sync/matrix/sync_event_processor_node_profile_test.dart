// Verifies the SyncEventProcessor's `_handleSyncNodeProfile` arm:
// receiving a SyncSyncNodeProfile message upserts the directory and produces
// no journal-side effects (no DB write, no UpdateNotifications.notify).

import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_event_processor_test_helpers.dart';

String _encode(SyncMessage message) =>
    base64.encode(utf8.encode(json.encode(message.toJson())));

void main() {
  setUpAll(registerSyncProcessorFallbacks);

  late SettingsDb settingsDbReal;
  late SyncNodeProfileRepository repo;
  late SyncEventProcessor processorWithRepo;
  late MockEvent event2;
  final updatedAt = DateTime.utc(2026, 3, 15, 12);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    setUpProcessorMocks();
    settingsDbReal = SettingsDb(inMemoryDatabase: true);
    repo = SyncNodeProfileRepository(settingsDb: settingsDbReal);
    processorWithRepo = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
      syncNodeProfileRepository: repo,
    );
    event2 = MockEvent();
    when(() => event2.eventId).thenReturn('event-node-profile');
    when(() => event2.originServerTs).thenReturn(DateTime(2024));
  });

  tearDown(() async {
    await repo.dispose();
    await settingsDbReal.close();
  });

  test('upserts the incoming profile into the directory', () async {
    final profile = SyncNodeProfile(
      hostId: 'peer-1',
      displayName: 'Studio Mac',
      platform: 'macos',
      capabilities: const [NodeCapability.mlxAudio, NodeCapability.ollamaLlm],
      updatedAt: updatedAt,
    );
    when(
      () => event2.text,
    ).thenReturn(_encode(SyncMessage.syncNodeProfile(profile: profile)));

    await processorWithRepo.process(event: event2, journalDb: journalDb);

    final stored = await repo.getNode('peer-1');
    expect(stored, profile);
  });

  test('does not write to JournalDb or emit UpdateNotifications', () async {
    final profile = SyncNodeProfile(
      hostId: 'peer-2',
      displayName: 'Other',
      platform: 'linux',
      capabilities: const [NodeCapability.ollamaLlm],
      updatedAt: updatedAt,
    );
    when(
      () => event2.text,
    ).thenReturn(_encode(SyncMessage.syncNodeProfile(profile: profile)));

    await processorWithRepo.process(event: event2, journalDb: journalDb);

    verifyNever(() => journalDb.updateJournalEntity(any()));
    verifyNever(
      () => updateNotifications.notify(
        any(),
        fromSync: any(named: 'fromSync'),
      ),
    );
  });

  test(
    'repeats apply with older timestamp do not overwrite newer entry',
    () async {
      final newer = SyncNodeProfile(
        hostId: 'peer-3',
        displayName: 'Newer',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final stale = SyncNodeProfile(
        hostId: 'peer-3',
        displayName: 'Older',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt.subtract(const Duration(hours: 1)),
      );

      when(
        () => event2.text,
      ).thenReturn(_encode(SyncMessage.syncNodeProfile(profile: newer)));
      await processorWithRepo.process(event: event2, journalDb: journalDb);

      when(
        () => event2.text,
      ).thenReturn(_encode(SyncMessage.syncNodeProfile(profile: stale)));
      await processorWithRepo.process(event: event2, journalDb: journalDb);

      final stored = await repo.getNode('peer-3');
      expect(stored?.displayName, 'Newer');
    },
  );

  test('without a repository injected, apply is a silent no-op', () async {
    final processorNoRepo = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
    );

    final profile = SyncNodeProfile(
      hostId: 'peer-4',
      displayName: 'Lonely',
      platform: 'macos',
      capabilities: const [],
      updatedAt: updatedAt,
    );
    when(
      () => event2.text,
    ).thenReturn(_encode(SyncMessage.syncNodeProfile(profile: profile)));

    await expectLater(
      processorNoRepo.process(event: event2, journalDb: journalDb),
      completes,
    );
  });
}
