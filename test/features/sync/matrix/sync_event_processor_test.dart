// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  test(
    'processes journal entities via loader and updates notifications',
    () async {
      const message = SyncMessage.journalEntity(
        id: 'entity-id',
        jsonPath: '/entity.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      when(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
        ),
      ).called(1);
      verify(
        () => journalDb.updateJournalEntity(fallbackJournalEntity),
      ).called(1);
      verify(
        () => updateNotifications.notify(
          {...fallbackJournalEntity.affectedIds, labelUsageNotification},
          fromSync: true,
        ),
      ).called(1);
    },
  );

  test(
    'decodes oversized sync payloads via the compute offload path',
    () async {
      // SyncEventProcessor.process() uses compute() to move large sync
      // message decoding (base64 + utf8 + json) off the UI isolate. The
      // threshold is 4 KB of base64 body. Pad the message id so the
      // encoded body comfortably exceeds the threshold and forces the
      // offload branch. A small message goes inline; this one must not.
      final paddedId = 'entity-${'x' * 6000}';
      final message = SyncMessage.journalEntity(
        id: paddedId,
        jsonPath: '/entity.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      final encoded = encodeMessage(message);
      expect(
        encoded.length,
        greaterThan(4 * 1024),
        reason:
            'test prerequisite: padded body must cross the offload '
            'threshold so the compute() branch runs',
      );
      when(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encoded);

      await processor.process(event: event, journalDb: journalDb);

      // Behaviour must be identical to the inline path: loader still
      // runs, DB update still fires, notifications still dispatch.
      verify(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
        ),
      ).called(1);
      verify(
        () => journalDb.updateJournalEntity(fallbackJournalEntity),
      ).called(1);
    },
  );

  test('skips duplicate journal entity with same vector clock', () async {
    final entryId = fallbackJournalEntity.meta.id;
    final vc = fallbackJournalEntity.meta.vectorClock!;
    final message = SyncMessage.journalEntity(
      id: entryId,
      jsonPath: '/entity.json',
      vectorClock: vc,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => event.eventId).thenReturn('event-id');
    when(() => event.originServerTs).thenReturn(DateTime(2024, 3, 15));
    when(
      () => journalEntityLoader.load(
        jsonPath: '/entity.json',
        incomingVectorClock: vc,
      ),
    ).thenAnswer((_) async => fallbackJournalEntity);
    when(
      () => journalDb.updateJournalEntity(fallbackJournalEntity),
    ).thenAnswer((_) async => JournalUpdateResult.applied());

    final diags = <SyncApplyDiagnostics>[];
    processor.applyObserver = diags.add;

    await processor.process(event: event, journalDb: journalDb);
    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => journalEntityLoader.load(
        jsonPath: '/entity.json',
        incomingVectorClock: vc,
      ),
    ).called(1);
    verify(
      () => journalDb.updateJournalEntity(fallbackJournalEntity),
    ).called(1);
    verify(
      () => updateNotifications.notify(
        {...fallbackJournalEntity.affectedIds, labelUsageNotification},
        fromSync: true,
      ),
    ).called(1);
    expect(diags.length, 2);
    expect(diags.last.skipReason, JournalUpdateSkipReason.olderOrEqual);
  });

  test(
    'duplicate entity records in sequence log when sequenceLogService is set',
    () async {
      final mockSeqService = MockSyncSequenceLogService();
      when(
        () => mockSeqService.recordReceivedEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
          coveredVectorClocks: any(named: 'coveredVectorClocks'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async => <({int counter, String hostId})>[]);

      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSeqService,
      );
      final diags = <SyncApplyDiagnostics>[];
      processorWithSeq.applyObserver = diags.add;

      final entryId = fallbackJournalEntity.meta.id;
      final vc = fallbackJournalEntity.meta.vectorClock!;
      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: '/entity.json',
        vectorClock: vc,
        status: SyncEntryStatus.initial,
        originatingHostId: 'originator-host',
      );
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => event.eventId).thenReturn('event-id');
      when(() => event.originServerTs).thenReturn(DateTime(2024));
      when(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
          incomingVectorClock: vc,
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(
        () => journalDb.updateJournalEntity(fallbackJournalEntity),
      ).thenAnswer((_) async => JournalUpdateResult.applied());

      // First call applies, second is duplicate
      await processorWithSeq.process(event: event, journalDb: journalDb);
      await processorWithSeq.process(event: event, journalDb: journalDb);

      // Entity is only written once — duplicate is skipped
      verify(
        () => journalDb.updateJournalEntity(fallbackJournalEntity),
      ).called(1);
      expect(diags.last.skipReason, JournalUpdateSkipReason.olderOrEqual);

      // recordReceivedEntry called once for the applied entry, once for the
      // duplicate (so hints can be resolved even for duplicates)
      verify(
        () => mockSeqService.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vc,
          originatingHostId: 'originator-host',
          coveredVectorClocks: any(named: 'coveredVectorClocks'),
          payloadType: any(named: 'payloadType'),
          jsonPath: any(named: 'jsonPath'),
        ),
      ).called(2);
    },
  );

  test(
    'invokes applyObserver with diagnostics and logs vclock prediction failure',
    () async {
      // Arrange a journal entity message
      const message = SyncMessage.journalEntity(
        id: 'entity-id',
        jsonPath: '/entity.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      // Loader returns the canonical fallback entity
      when(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);

      // DB lookup for prediction throws to exercise logging + default status
      when(
        () => journalDb.journalEntityById(fallbackJournalEntity.meta.id),
      ).thenThrow(Exception('db unavailable'));

      SyncApplyDiagnostics? capturedDiag;
      processor.applyObserver = (diag) => capturedDiag = diag;

      await processor.process(event: event, journalDb: journalDb);

      // Observer called with a complete diagnostics payload
      expect(capturedDiag, isNotNull);
      expect(capturedDiag!.eventId, 'event-id');
      expect(capturedDiag!.payloadType, 'journalEntity');
      expect(capturedDiag!.conflictStatus, contains('VclockStatus'));
      expect(capturedDiag!.applied, isTrue);
      expect(capturedDiag!.skipReason, isNull);

      // Prediction failure is logged with specific subDomain
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'apply.predictVectorClock',
        ),
      ).called(1);
    },
  );

  test('processes entry link messages', () async {
    final link = EntryLink.basic(
      id: 'link',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    final capturedLink =
        verify(
              () => journalDb.upsertEntryLink(captureAny<EntryLink>()),
            ).captured.single
            as EntryLink;
    expect(capturedLink.id, link.id);
    expect(capturedLink.fromId, link.fromId);
    expect(capturedLink.toId, link.toId);
    verify(
      () => updateNotifications.notify(const {'from', 'to'}, fromSync: true),
    ).called(1);
  });

  test('EntryLink diag reports applied when rows > 0', () async {
    final link = EntryLink.basic(
      id: 'diag-link',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    SyncApplyDiagnostics? diag;
    processor.applyObserver = (value) => diag = value;

    await processor.process(event: event, journalDb: journalDb);

    expect(diag, isNotNull);
    expect(diag!.payloadType, 'entryLink');
    expect(diag!.applied, isTrue);
  });

  test('EntryLink observer exceptions are swallowed', () async {
    final link = EntryLink.basic(
      id: 'diag-link-throw',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    processor.applyObserver = (_) {
      throw StateError('observer failure');
    };

    await processor.process(event: event, journalDb: journalDb);
  });

  test('EntryLink syncs collapsed state from remote', () async {
    final incomingLink = EntryLink.basic(
      id: 'link-with-collapse',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2025, 6, 1),
      updatedAt: DateTime(2025, 6, 2),
      vectorClock: null,
      collapsed: true,
    );
    final message = SyncMessage.entryLink(
      entryLink: incomingLink,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(
      () => journalDb.upsertEntryLink(any<EntryLink>()),
    ).thenAnswer((_) async => 1);

    await processor.process(event: event, journalDb: journalDb);

    final capturedLink =
        verify(
              () => journalDb.upsertEntryLink(captureAny<EntryLink>()),
            ).captured.single
            as EntryLink;
    expect(capturedLink.id, 'link-with-collapse');
    expect(capturedLink.collapsed, isTrue);
  });

  test('processes entity definitions', () async {
    final message = SyncMessage.entityDefinition(
      entityDefinition: measurableWater,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertEntityDefinition(measurableWater)).called(1);
  });

  test('processes ai config messages', () async {
    final message = SyncMessage.aiConfig(
      aiConfig: fallbackAiConfig,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => aiConfigRepository.saveConfig(
        fallbackAiConfig,
        fromSync: true,
      ),
    ).called(1);
  });

  test('SyncAiConfig payload does not emit diagnostics', () async {
    final message = SyncMessage.aiConfig(
      aiConfig: fallbackAiConfig,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    var observerCalled = false;
    processor.applyObserver = (_) => observerCalled = true;

    await processor.process(event: event, journalDb: journalDb);

    expect(observerCalled, isFalse);
    verify(
      () => aiConfigRepository.saveConfig(
        fallbackAiConfig,
        fromSync: true,
      ),
    ).called(1);
  });

  test('processes ai config delete messages', () async {
    const id = 'config-id';
    const message = SyncMessage.aiConfigDelete(id: id);
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => aiConfigRepository.deleteConfig(id, fromSync: true)).called(1);
  });

  test('processes config flag messages', () async {
    const flag = ConfigFlag(
      name: 'enableDailyOs',
      description: 'Enable DailyOS Page?',
      status: true,
    );
    final message = SyncMessage.configFlag(
      name: flag.name,
      description: flag.description,
      status: flag.status,
    );
    when(() => event.text).thenReturn(encodeMessage(message));

    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertConfigFlag(flag)).called(1);
  });

  test(
    'processes synced private flag with private toggle notification',
    () async {
      const flag = ConfigFlag(
        name: 'private',
        description: 'Show private entries?',
        status: false,
      );
      final message = SyncMessage.configFlag(
        name: flag.name,
        description: flag.description,
        status: flag.status,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => journalDb.upsertConfigFlag(flag)).called(1);
      verify(
        () => updateNotifications.notify(
          {privateToggleNotification},
          fromSync: true,
        ),
      ).called(1);
    },
  );

  group('SyncEventProcessor listener -', () {
    test('cachePurgeListener with non-smart loader does not crash', () {
      final processorWithFileLoader = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: const FileSyncJournalEntityLoader(),
      );

      expect(() {
        processorWithFileLoader.cachePurgeListener = () {};
      }, returnsNormally);
    });

    test('descriptorPendingListener with non-smart loader does not crash', () {
      final processorWithFileLoader = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: const FileSyncJournalEntityLoader(),
      );

      expect(() {
        processorWithFileLoader.descriptorPendingListener = (_) {};
      }, returnsNormally);
    });

    test(
      'descriptorPendingListener forwards missing descriptor notifications from smart loader',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'descriptor_listener_test',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        await getIt.reset();
        getIt.allowReassignment = true;
        getIt.registerSingleton<Directory>(tempDir);

        final fixedDate = DateTime(2024, 3, 15);
        final image = JournalImage(
          meta: Metadata(
            id: 'img-listener',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          data: ImageData(
            imageId: 'img-listener',
            imageDirectory: '/images/2024-03-15/',
            imageFile: 'pending.jpg',
            capturedAt: fixedDate,
          ),
        );
        final relJson = '${getRelativeImagePath(image)}.json';
        File(path.join(tempDir.path, stripLeadingSlashes(relJson)))
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(image.toJson()));

        final loader = SmartJournalEntityLoader(
          attachmentIndex: AttachmentIndex(logging: loggingService),
          loggingService: loggingService,
        );
        final processorWithSmartLoader = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: loader,
        );

        String? pendingPath;
        processorWithSmartLoader.descriptorPendingListener = (path) {
          pendingPath = path;
        };

        await loader.load(jsonPath: relJson);

        expect(pendingPath, getRelativeImagePath(image));
      },
    );
  });

  test('EntryLink apply logs from/to IDs and rows affected', () async {
    final link = EntryLink.basic(
      id: 'link-log',
      fromId: 'from-id',
      toId: 'to-id',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);

    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('apply entryLink from=from-id to=to-id rows=1'),
        ),
        subDomain: 'processor.apply.entryLink',
      ),
    ).called(1);
  });

  test(
    'EntryLink no-op (rows=0) suppresses apply log and emits diag',
    () async {
      final link = EntryLink.basic(
        id: 'link-noop',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      final message = SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      );
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 0);

      SyncApplyDiagnostics? seen;
      processor.applyObserver = (d) => seen = d;

      await processor.process(event: event, journalDb: journalDb);

      // No apply.entryLink log on rows=0
      verifyNever(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(),
          subDomain: 'apply.entryLink',
        ),
      );

      // Diagnostics captured for pipeline
      expect(seen, isNotNull);
      expect(seen!.payloadType, 'entryLink');
      expect(seen!.conflictStatus, 'entryLink.noop');
      expect(seen!.applied, isFalse);
      expect(seen!.skipReason, JournalUpdateSkipReason.olderOrEqual);

      // Restore default behavior for subsequent tests
      when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
    },
  );

  test('EntryLink apply continues when logging throws', () async {
    final link = EntryLink.basic(
      id: 'link-fail',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    );
    final message = SyncMessage.entryLink(
      entryLink: link,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(() => journalDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
    when(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(),
        subDomain: 'apply.entryLink',
      ),
    ).thenThrow(Exception('logging failed'));

    // Should not throw - logging is best-effort
    await processor.process(event: event, journalDb: journalDb);

    verify(() => journalDb.upsertEntryLink(any())).called(1);
    verify(() => updateNotifications.notify(any(), fromSync: true)).called(1);
  });

  test(
    'journal entity loader exception logs missingAttachment subdomain',
    () async {
      const message = SyncMessage.journalEntity(
        id: 'entity-id',
        jsonPath: '/entity.json',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      when(() => event.text).thenReturn(encodeMessage(message));
      when(
        () => journalEntityLoader.load(jsonPath: '/entity.json'),
      ).thenThrow(const FileSystemException('missing'));

      await expectLater(
        processor.process(event: event, journalDb: journalDb),
        throwsA(isA<FileSystemException>()),
      );
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'SyncEventProcessor.missingAttachment',
        ),
      ).called(1);
      verifyNever(() => journalDb.updateJournalEntity(any()));
    },
  );

  test('stale descriptor is skipped when local entry is newer', () async {
    final entryId = fallbackJournalEntity.meta.id;
    final message = SyncMessage.journalEntity(
      id: entryId,
      jsonPath: '/entity.json',
      vectorClock: const VectorClock({'a': 10}),
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(
      () => journalEntityLoader.load(
        jsonPath: '/entity.json',
        incomingVectorClock: any(named: 'incomingVectorClock'),
      ),
    ).thenThrow(
      const FileSystemException('stale attachment json after refresh'),
    );
    when(
      () => journalDb.journalEntityById(entryId),
    ).thenAnswer((_) async => fallbackJournalEntity);

    SyncApplyDiagnostics? captured;
    processor.applyObserver = (diag) => captured = diag;

    await processor.process(event: event, journalDb: journalDb);

    expect(captured, isNotNull);
    expect(captured!.skipReason, JournalUpdateSkipReason.olderOrEqual);
    expect(captured!.conflictStatus, contains('a_gt_b'));
    verifyNever(() => journalDb.updateJournalEntity(any()));
  });

  test(
    'stale descriptor skip records sequence log when local entry is equal',
    () async {
      final mockSequenceService = MockSyncSequenceLogService();
      const vc = VectorClock({'a': 11});
      final entryId = fallbackJournalEntity.meta.id;
      final message = SyncMessage.journalEntity(
        id: entryId,
        jsonPath: '/entity.json',
        vectorClock: vc,
        status: SyncEntryStatus.initial,
        originatingHostId: 'host-A',
      );
      final processorWithSeq = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        sequenceLogService: mockSequenceService,
      );

      when(() => event.text).thenReturn(encodeMessage(message));
      when(
        () => journalEntityLoader.load(
          jsonPath: '/entity.json',
          incomingVectorClock: any(named: 'incomingVectorClock'),
        ),
      ).thenThrow(
        const FileSystemException('stale attachment json after refresh'),
      );
      when(
        () => journalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(
        () => mockSequenceService.recordReceivedEntry(
          entryId: any(named: 'entryId'),
          vectorClock: any(named: 'vectorClock'),
          originatingHostId: any(named: 'originatingHostId'),
          coveredVectorClocks: any(named: 'coveredVectorClocks'),
          payloadType: any(named: 'payloadType'),
          jsonPath: any(named: 'jsonPath'),
        ),
      ).thenAnswer((_) async => [(hostId: 'host-A', counter: 10)]);

      SyncApplyDiagnostics? captured;
      processorWithSeq.applyObserver = (diag) => captured = diag;

      await processorWithSeq.process(event: event, journalDb: journalDb);

      expect(captured, isNotNull);
      expect(captured!.skipReason, JournalUpdateSkipReason.olderOrEqual);
      expect(captured!.conflictStatus, contains('equal'));
      verify(
        () => mockSequenceService.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vc,
          originatingHostId: 'host-A',
          coveredVectorClocks: null,
          payloadType: any(named: 'payloadType'),
          jsonPath: any(named: 'jsonPath'),
        ),
      ).called(1);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('apply.gapsDetected count=1')),
          subDomain: 'processor.gapDetection',
        ),
      ).called(1);
      verifyNever(() => journalDb.updateJournalEntity(any()));
    },
  );

  test('stale descriptor rethrows when incoming is newer than local', () async {
    final entryId = fallbackJournalEntity.meta.id;
    const incomingVc = VectorClock({'a': 20});
    final message = SyncMessage.journalEntity(
      id: entryId,
      jsonPath: '/entity.json',
      vectorClock: incomingVc,
      status: SyncEntryStatus.initial,
    );
    final existing = fallbackJournalEntity as JournalEntry;
    final olderEntry = JournalEntry(
      meta: existing.meta.copyWith(vectorClock: const VectorClock({'a': 1})),
      entryText: existing.entryText,
      geolocation: existing.geolocation,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(
      () => journalEntityLoader.load(
        jsonPath: '/entity.json',
        incomingVectorClock: any(named: 'incomingVectorClock'),
      ),
    ).thenThrow(
      const FileSystemException('stale attachment json after refresh'),
    );
    when(
      () => journalDb.journalEntityById(entryId),
    ).thenAnswer((_) async => olderEntry);

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsA(isA<FileSystemException>()),
    );
    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'SyncEventProcessor.missingAttachment',
      ),
    ).called(1);
  });

  group('SyncEventProcessor - SyncThemingSelection', () {
    String encodeThemingMessage(SyncMessage message) =>
        base64.encode(utf8.encode(json.encode(message.toJson())));

    // Helper to create event with theming message
    Event createThemingEvent(SyncMessage message) {
      final themingEvent = MockEvent();
      final encoded = encodeThemingMessage(message);
      when(() => themingEvent.eventId).thenReturn('event-id');
      when(() => themingEvent.originServerTs).thenReturn(DateTime(2024));
      when(() => themingEvent.content).thenReturn({
        'msgtype': 'com.lotti.sync.message',
        'body': 'sync',
        'data': encoded,
      });
      when(() => themingEvent.text).thenReturn(encoded);
      return themingEvent;
    }

    test('applies incoming theme selection', () async {
      final testTimestamp = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: testTimestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify all settings saved
      verify(
        () => settingsDb.saveSettingsItem('LIGHT_SCHEME', 'Indigo'),
      ).called(1);
      verify(
        () => settingsDb.saveSettingsItem('DARK_SCHEMA', 'Shark'),
      ).called(1);
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'dark')).called(1);
      verify(
        () => settingsDb.saveSettingsItem(
          'THEME_PREFS_UPDATED_AT',
          '$testTimestamp',
        ),
      ).called(1);
    });

    test('rejects stale message based on timestamp', () async {
      // Mock local timestamp to future
      when(
        () => settingsDb.itemByKey('THEME_PREFS_UPDATED_AT'),
      ).thenAnswer((_) async => '9999999999999');

      const message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: 1000000000000,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify settings not saved for theme keys
      verifyNever(() => settingsDb.saveSettingsItem('LIGHT_SCHEME', any()));
      verifyNever(() => settingsDb.saveSettingsItem('DARK_SCHEMA', any()));
      verifyNever(() => settingsDb.saveSettingsItem('THEME_MODE', any()));

      // Verify log contains stale message
      verify(
        () => loggingService.log(
          LogDomain.theming,
          any<String>(that: contains('themingSync.ignored.stale')),
          subDomain: 'apply',
        ),
      ).called(1);
    });

    test('accepts message when no local timestamp exists', () async {
      // Mock no local timestamp
      when(
        () => settingsDb.itemByKey('THEME_PREFS_UPDATED_AT'),
      ).thenAnswer((_) async => null);

      final testTimestamp = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: testTimestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify all settings saved
      verify(
        () => settingsDb.saveSettingsItem('LIGHT_SCHEME', 'Indigo'),
      ).called(1);
      verify(
        () => settingsDb.saveSettingsItem('DARK_SCHEMA', 'Shark'),
      ).called(1);
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'dark')).called(1);
      verify(
        () => settingsDb.saveSettingsItem(
          'THEME_PREFS_UPDATED_AT',
          '$testTimestamp',
        ),
      ).called(1);
    });

    test('accepts newer message', () async {
      // Mock old local timestamp
      when(
        () => settingsDb.itemByKey('THEME_PREFS_UPDATED_AT'),
      ).thenAnswer((_) async => '1000000000000');

      final testTimestamp = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: testTimestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify all settings saved
      verify(
        () => settingsDb.saveSettingsItem('LIGHT_SCHEME', 'Indigo'),
      ).called(1);
      verify(
        () => settingsDb.saveSettingsItem('DARK_SCHEMA', 'Shark'),
      ).called(1);
      verify(() => settingsDb.saveSettingsItem('THEME_MODE', 'dark')).called(1);
      verify(
        () => settingsDb.saveSettingsItem(
          'THEME_PREFS_UPDATED_AT',
          '$testTimestamp',
        ),
      ).called(1);
    });

    test('normalizes invalid ThemeMode to system', () async {
      final testTimestamp = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'invalid_mode',
        updatedAt: testTimestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify themeMode normalized to 'system'
      verify(
        () => settingsDb.saveSettingsItem('THEME_MODE', 'system'),
      ).called(1);
    });

    test('handles exception during apply', () async {
      // Mock saveSettingsItem to throw
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenThrow(Exception('DB error'));

      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: DateTime(2024, 3, 15).millisecondsSinceEpoch,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      // Should not throw
      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify exception logged
      verify(
        () => loggingService.error(
          LogDomain.theming,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'apply',
        ),
      ).called(1);
    });

    test('logs success on apply', () async {
      final testTimestamp = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: testTimestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify success logged
      verify(
        () => loggingService.log(
          LogDomain.theming,
          any<String>(that: contains('apply themingSelection')),
          subDomain: 'apply',
        ),
      ).called(1);
    });

    test('saves updatedAt as string', () async {
      const timestamp = 1234567890;
      const message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: timestamp,
        status: SyncEntryStatus.update,
      );
      final themingEvent = createThemingEvent(message);

      await processor.process(event: themingEvent, journalDb: journalDb);

      // Verify updatedAt saved as string
      verify(
        () =>
            settingsDb.saveSettingsItem('THEME_PREFS_UPDATED_AT', '$timestamp'),
      ).called(1);
    });
  });

  group('SyncEventProcessor - Backfill Messages', () {
    test('SyncBackfillRequest throws when no handler configured', () async {
      const message = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: 'host-1', counter: 5),
        ],
        requesterId: 'requester-1',
      );

      when(() => event.text).thenReturn(encodeMessage(message));

      // Late-final field: reads before DI assignment must surface as
      // LateInitializationError so misconfigured boot fails loudly rather
      // than silently dropping inbound backfill traffic.
      await expectLater(
        processor.process(event: event, journalDb: journalDb),
        throwsA(
          isA<Error>().having(
            (e) => e.toString(),
            'toString',
            contains(
              "Field 'backfillResponseHandler' has not been initialized",
            ),
          ),
        ),
      );
    });

    test(
      'SyncBackfillResponse throws when no handler configured',
      () async {
        const message = SyncBackfillResponse(
          hostId: 'host-1',
          counter: 5,
          deleted: false,
          entryId: 'entry-1',
        );

        when(() => event.text).thenReturn(encodeMessage(message));

        await expectLater(
          processor.process(event: event, journalDb: journalDb),
          throwsA(
            isA<Error>().having(
              (e) => e.toString(),
              'toString',
              contains(
                "Field 'backfillResponseHandler' has not been initialized",
              ),
            ),
          ),
        );
      },
    );

    test(
      'SyncBackfillRequest is delegated to handler when configured',
      () async {
        const message = SyncBackfillRequest(
          entries: [
            BackfillRequestEntry(hostId: 'host-1', counter: 5),
          ],
          requesterId: 'requester-1',
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillRequest(any()),
        ).thenAnswer((_) async {});

        processor.backfillResponseHandler = mockHandler;

        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockHandler.handleBackfillRequest(message)).called(1);
      },
    );

    test(
      'SyncBackfillResponse is delegated to handler when configured',
      () async {
        const message = SyncBackfillResponse(
          hostId: 'host-1',
          counter: 5,
          deleted: true,
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillResponse(any()),
        ).thenAnswer((_) async {});

        processor.backfillResponseHandler = mockHandler;

        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockHandler.handleBackfillResponse(message)).called(1);
      },
    );

    test(
      'processes old SyncBackfillRequest even when startupTimestamp is set',
      () async {
        const message = SyncBackfillRequest(
          entries: [BackfillRequestEntry(hostId: 'host-1', counter: 5)],
          requesterId: 'requester-1',
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillRequest(any()),
        ).thenAnswer((_) async {});

        // Create processor with startupTimestamp set
        final processorWithStartup = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
        );
        processorWithStartup.backfillResponseHandler = mockHandler;
        // Set startup timestamp to a point in the future relative to the event
        processorWithStartup.startupTimestamp = 2000000000000; // Far future

        // Event timestamp is in the past (before startup)
        when(() => event.originServerTs).thenReturn(DateTime(2024));
        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => event.eventId).thenReturn('old-backfill-event');

        await processorWithStartup.process(event: event, journalDb: journalDb);

        // Handler SHOULD be called — old backfill requests are still valid
        // and the response handler's cooldown + rate limiter prevent
        // amplification. Skipping them caused a bidirectional deadlock.
        verify(() => mockHandler.handleBackfillRequest(message)).called(1);
      },
    );

    test(
      'processes old SyncBackfillResponse even without sequence log service',
      () async {
        const message = SyncBackfillResponse(
          hostId: 'host-1',
          counter: 5,
          deleted: false,
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillResponse(any()),
        ).thenAnswer((_) async {});

        final processorWithStartup = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
        );
        processorWithStartup.backfillResponseHandler = mockHandler;
        processorWithStartup.startupTimestamp = 2000000000000;

        when(() => event.originServerTs).thenReturn(DateTime(2024));
        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => event.eventId).thenReturn('old-response-event');

        await processorWithStartup.process(event: event, journalDb: journalDb);

        // Old backfill responses are never skipped — handleBackfillResponse
        // is idempotent, and skipping caused a deadlock when gap detection
        // skips own hostId.
        verify(() => mockHandler.handleBackfillResponse(message)).called(1);
      },
    );

    test('processes old SyncBackfillResponse when entry is missing', () async {
      const message = SyncBackfillResponse(
        hostId: 'host-1',
        counter: 5,
        deleted: false,
      );

      final mockHandler = MockBackfillResponseHandler();
      when(
        () => mockHandler.handleBackfillResponse(any()),
      ).thenAnswer((_) async {});

      final processorWithStartup = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
      );
      processorWithStartup.backfillResponseHandler = mockHandler;
      processorWithStartup.startupTimestamp = 2000000000000;

      when(() => event.originServerTs).thenReturn(DateTime(2024));
      when(() => event.text).thenReturn(encodeMessage(message));
      when(() => event.eventId).thenReturn('old-response-event');

      await processorWithStartup.process(event: event, journalDb: journalDb);

      verify(() => mockHandler.handleBackfillResponse(message)).called(1);
    });

    test(
      'processes old SyncBackfillResponse even when entry already resolved',
      () async {
        const message = SyncBackfillResponse(
          hostId: 'host-1',
          counter: 5,
          deleted: false,
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillResponse(any()),
        ).thenAnswer((_) async {});

        final processorWithStartup = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
        );
        processorWithStartup.backfillResponseHandler = mockHandler;
        processorWithStartup.startupTimestamp = 2000000000000;

        when(() => event.originServerTs).thenReturn(DateTime(2024));
        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => event.eventId).thenReturn('old-response-event');

        await processorWithStartup.process(event: event, journalDb: journalDb);

        // handleBackfillResponse is idempotent — safe to call even for
        // already-resolved entries.
        verify(() => mockHandler.handleBackfillResponse(message)).called(1);
      },
    );

    test(
      'processes old SyncBackfillResponse even when entry is unknown',
      () async {
        const message = SyncBackfillResponse(
          hostId: 'host-1',
          counter: 5,
          deleted: false,
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillResponse(any()),
        ).thenAnswer((_) async {});

        final processorWithStartup = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
        );
        processorWithStartup.backfillResponseHandler = mockHandler;
        processorWithStartup.startupTimestamp = 2000000000000;

        when(() => event.originServerTs).thenReturn(DateTime(2024));
        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => event.eventId).thenReturn('old-response-event');

        await processorWithStartup.process(event: event, journalDb: journalDb);

        // Old backfill responses are never skipped, regardless of whether
        // the counter exists in the sequence log.
        verify(() => mockHandler.handleBackfillResponse(message)).called(1);
      },
    );

    test(
      'processes SyncBackfillRequest when newer than startupTimestamp',
      () async {
        const message = SyncBackfillRequest(
          entries: [BackfillRequestEntry(hostId: 'host-1', counter: 5)],
          requesterId: 'requester-1',
        );

        final mockHandler = MockBackfillResponseHandler();
        when(
          () => mockHandler.handleBackfillRequest(any()),
        ).thenAnswer((_) async {});

        final processorWithStartup = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
        );
        processorWithStartup.backfillResponseHandler = mockHandler;
        // Startup was in the past
        processorWithStartup.startupTimestamp = 1000000000000;

        // Event is newer than startup
        when(
          () => event.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1500000000000));
        when(() => event.text).thenReturn(encodeMessage(message));
        when(() => event.eventId).thenReturn('new-backfill-event');

        await processorWithStartup.process(event: event, journalDb: journalDb);

        // Handler SHOULD be called - event is newer than startup
        verify(() => mockHandler.handleBackfillRequest(message)).called(1);
      },
    );
  });

  group('runWithDeferredMissingEntryNudges', () {
    test('falls back to plain action for mock processor instances', () async {
      final mockProcessor = MockSyncEventProcessor();

      final result = await runWithDeferredMissingEntryNudges<String>(
        mockProcessor,
        () async => 'plain-action',
      );

      expect(result, 'plain-action');
    });

    test(
      'falls back to plain action when sequence log service is absent',
      () async {
        final result = await runWithDeferredMissingEntryNudges<String>(
          processor,
          () async => 'no-sequence-log',
        );

        expect(result, 'no-sequence-log');
      },
    );

    test(
      'delegates through the concrete sequence log service when present',
      () async {
        final sequenceLogService = SyncSequenceLogService(
          syncDatabase: MockSyncDatabase(),
          vectorClockService: MockVectorClockService(),
          loggingService: loggingService,
        );
        final processorWithSequenceLog = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: sequenceLogService,
        );

        final executionOrder = <String>[];
        sequenceLogService.onMissingEntriesDetected = () {
          executionOrder.add('flush');
        };

        final result = await runWithDeferredMissingEntryNudges<String>(
          processorWithSequenceLog,
          () async {
            executionOrder.add('action');
            return 'with-sequence-log';
          },
        );

        expect(result, 'with-sequence-log');
        expect(executionOrder, ['action']);
      },
    );
  });

  // Note: Sequence log integration tests for the sync processor are covered
  // by sync_sequence_log_service_test.dart which tests recordReceivedEntry
  // behavior including gap detection and status transitions.

  group('_trace routing', () {
    test(
      'routes through DomainLogger when one is injected and skips the '
      'direct captureEvent fallback',
      () async {
        final domainLogger = MockDomainLogger();
        when(
          () => domainLogger.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String>(named: 'subDomain'),
            level: any<InsightLevel>(named: 'level'),
          ),
        ).thenReturn(null);

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          domainLogger: domainLogger,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
        );

        // Trigger a _trace emission via the undeserializable-skip path.
        when(() => event.text).thenReturn(
          base64.encode(utf8.encode(json.encode(<String, dynamic>{}))),
        );
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => domainLogger.log(
            LogDomain.sync,
            any<String>(
              that: contains('skipping undeserializable sync message'),
            ),
            subDomain: 'processor.skipUnrecoverable',
          ),
        ).called(1);
        verifyNever(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains('skipping undeserializable sync message'),
            ),
            subDomain: 'processor.skipUnrecoverable',
          ),
        );
      },
    );
  });

  group('SyncEventProcessor - self-echo skip', () {
    test(
      'short-circuits prepare for any SyncMessage whose originatingHostId '
      'matches the local host — proves a self-echoed bundle never '
      'touches `_resolveOutboxBundleManifest` (no descriptor download, '
      'no manifest gunzip, no per-child saveJson). Independent of the '
      'SentEventRegistry TTL and arrival path so it covers the catch-up '
      'case where the registry has already expired.',
      () async {
        final localVcService = MockVectorClockService();
        when(localVcService.getHost).thenAnswer((_) async => 'host-self');

        final processorWithVc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          vectorClockService: localVcService,
        );

        const selfBundle = SyncOutboxBundle(
          children: [SyncMessage.aiConfigDelete(id: 'cfg-self')],
          jsonPath: '/outbox_bundles/self.json',
          originatingHostId: 'host-self',
        );
        when(() => event.text).thenReturn(encodeMessage(selfBundle));

        await processorWithVc.process(event: event, journalDb: journalDb);

        // The bundle's child (an aiConfigDelete) would normally drive a
        // deleteConfig call inside the unpacker apply phase. With the
        // self-echo short-circuit, prepare returns a PreparedSyncEvent
        // with no resolved bundle and apply no-ops.
        verifyNever(
          () => aiConfigRepository.deleteConfig(
            any<String>(),
            fromSync: any<bool>(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'still processes a peer-originated SyncOutboxBundle whose '
      'originatingHostId does not match the local host — the self-echo '
      'short-circuit must not eat legitimate inbound work',
      () async {
        final localVcService = MockVectorClockService();
        when(localVcService.getHost).thenAnswer((_) async => 'host-self');

        final processorWithVc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          vectorClockService: localVcService,
        );

        const peerBundle = SyncOutboxBundle(
          children: [SyncMessage.aiConfigDelete(id: 'cfg-peer')],
          originatingHostId: 'host-peer',
        );
        when(() => event.text).thenReturn(encodeMessage(peerBundle));

        await processorWithVc.process(event: event, journalDb: journalDb);

        verify(
          () => aiConfigRepository.deleteConfig(
            'cfg-peer',
            fromSync: true,
          ),
        ).called(1);
      },
    );

    test(
      'caches the local host id across calls — only one getHost() lookup '
      'per processor instance even after many incoming events that '
      'carry an originatingHostId. The lookup result is stable for the '
      'lifetime of an install, and a per-event call would put the slow '
      'vector-clock service on the apply hot path.',
      () async {
        final localVcService = MockVectorClockService();
        when(localVcService.getHost).thenAnswer((_) async => 'host-self');

        final processorWithVc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          vectorClockService: localVcService,
        );

        // A SyncEntryLink-style message with originatingHostId set is
        // what triggers the self-echo check (inline-only types like
        // aiConfigDelete have no host id and bypass the lookup
        // entirely). Use a peer host so the check decides "not a
        // self-echo" and the message proceeds through the normal
        // pipeline — the only thing we care about here is that
        // resolveLocalHostId fires exactly once across the three
        // process() calls.
        final peer = SyncMessage.entryLink(
          entryLink: EntryLink.basic(
            id: 'link-cache',
            fromId: 'from',
            toId: 'to',
            createdAt: DateTime.utc(2026, 4, 25),
            updatedAt: DateTime.utc(2026, 4, 25),
            vectorClock: const VectorClock({'host-peer': 1}),
          ),
          status: SyncEntryStatus.initial,
          originatingHostId: 'host-peer',
        );
        when(() => event.text).thenReturn(encodeMessage(peer));

        await processorWithVc.process(event: event, journalDb: journalDb);
        await processorWithVc.process(event: event, journalDb: journalDb);
        await processorWithVc.process(event: event, journalDb: journalDb);

        verify(localVcService.getHost).called(1);
      },
    );

    test(
      'SyncJournalEntity self-echo applies as a no-op — regression for the '
      'crash where prepare flagged self-echo but apply still dereferenced '
      'the unpopulated journalEntity slot and threw `Null check operator '
      'used on a null value`. The crash classified retriable in the queue '
      'adapter and pinned the inbound read marker until maxAttempts gave '
      'up, surfacing as the 29 skipped entries on the Backfill screen. '
      'Apply must short-circuit before _applyJournalEntity bangs on '
      '`preloaded!`.',
      () async {
        final localVcService = MockVectorClockService();
        when(localVcService.getHost).thenAnswer((_) async => 'host-self');

        final processorWithVc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          vectorClockService: localVcService,
        );

        const message = SyncMessage.journalEntity(
          id: 'entity-self',
          jsonPath: '/entity-self.json',
          vectorClock: VectorClock({'host-self': 1}),
          status: SyncEntryStatus.update,
          originatingHostId: 'host-self',
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        final diags = <SyncApplyDiagnostics>[];
        processorWithVc.applyObserver = diags.add;

        // The prior bug raised `Null check operator used on a null value`
        // here. expectLater would mask future regressions; assert no throw
        // by simply awaiting and then asserting on the side effects.
        await processorWithVc.process(event: event, journalDb: journalDb);

        // Self-echo must skip the loader entirely (we already wrote the
        // entity locally before sending) and must not touch the DB.
        verifyNever(
          () => journalEntityLoader.load(
            jsonPath: any<String>(named: 'jsonPath'),
            incomingVectorClock: any<VectorClock>(named: 'incomingVectorClock'),
          ),
        );
        verifyNever(
          () => journalDb.updateJournalEntity(any<JournalEntity>()),
        );
        // No diagnostics emitted: self-echo is neither applied nor a
        // duplicate skip — the queue commits cleanly so the marker
        // advances.
        expect(diags, isEmpty);
      },
    );

    test(
      'apply() returns null for an isSelfEcho-flagged SyncJournalEntity '
      'even when the journalEntity slot is null — locks the apply-side '
      'invariant so a future refactor cannot reintroduce the null-bang '
      'on `preloaded!`. Driven directly through apply() to keep the '
      'test independent of prepare wiring.',
      () async {
        const message = SyncMessage.journalEntity(
          id: 'entity-self',
          jsonPath: '/entity-self.json',
          vectorClock: VectorClock({'host-self': 1}),
          status: SyncEntryStatus.update,
          originatingHostId: 'host-self',
        );
        final prepared = PreparedSyncEvent.forTesting(
          event: event,
          syncMessage: message,
          isSelfEcho: true,
          // journalEntity intentionally left null — that was the crash
          // shape in production.
        );

        final result = await processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        );

        expect(result, isNull);
        verifyNever(
          () => journalDb.updateJournalEntity(any<JournalEntity>()),
        );
      },
    );

    test(
      'apply() returns null for an isSelfEcho-flagged SyncOutboxBundle '
      'whose resolvedOutboxBundle is null — guards against a future '
      'refactor that could otherwise null-bang in the bundle apply '
      'branch. Self-echo bundles must short-circuit before the per-child '
      'recursion because none of their children were resolved.',
      () async {
        const message = SyncOutboxBundle(
          children: [SyncMessage.aiConfigDelete(id: 'cfg-self')],
          jsonPath: '/outbox_bundles/self.json',
          originatingHostId: 'host-self',
        );
        final prepared = PreparedSyncEvent.forTesting(
          event: event,
          syncMessage: message,
          isSelfEcho: true,
          // resolvedOutboxBundle intentionally left null.
        );

        final result = await processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        );

        expect(result, isNull);
        verifyNever(
          () => aiConfigRepository.deleteConfig(
            any<String>(),
            fromSync: any<bool>(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'apply() returns null for a legacy SyncAgentBundle envelope — the '
      'wire variant is retained for compat but the apply branch is a '
      'no-op so the inbound queue marker advances cleanly.',
      () async {
        const message = SyncMessage.agentBundle(
          agentId: 'agent-self',
          wakeRunKey: 'wake-self',
          jsonPath: '/agent_bundles/self.json',
          originatingHostId: 'host-self',
        );
        final prepared = PreparedSyncEvent.forTesting(
          event: event,
          syncMessage: message,
        );

        final result = await processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        );

        expect(result, isNull);
      },
    );

    test(
      'peer-originated SyncJournalEntity still flows through the normal '
      'apply path — the apply-side self-echo guard must not eat '
      'legitimate inbound work. Without this regression-guard test, a '
      'mis-set isSelfEcho default could silently drop every peer event.',
      () async {
        final localVcService = MockVectorClockService();
        when(localVcService.getHost).thenAnswer((_) async => 'host-self');

        final processorWithVc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          vectorClockService: localVcService,
        );

        const message = SyncMessage.journalEntity(
          id: 'entity-peer',
          jsonPath: '/entity-peer.json',
          vectorClock: VectorClock({'host-peer': 1}),
          status: SyncEntryStatus.update,
          originatingHostId: 'host-peer',
        );
        when(
          () => journalEntityLoader.load(
            jsonPath: '/entity-peer.json',
            incomingVectorClock: const VectorClock({'host-peer': 1}),
          ),
        ).thenAnswer((_) async => fallbackJournalEntity);
        when(() => event.text).thenReturn(encodeMessage(message));

        await processorWithVc.process(event: event, journalDb: journalDb);

        verify(
          () => journalEntityLoader.load(
            jsonPath: '/entity-peer.json',
            incomingVectorClock: const VectorClock({'host-peer': 1}),
          ),
        ).called(1);
        verify(
          () => journalDb.updateJournalEntity(fallbackJournalEntity),
        ).called(1);
      },
    );
  });

  test(
    'cachePurgeListener forwards to a SmartJournalEntityLoader so a real '
    'stale-descriptor purge invokes the processor-supplied callback',
    () async {
      const relJson = '/text_entries/2024-01-01/purge.text.json';
      final index = AttachmentIndex(logging: loggingService);
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('evt-purge');
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content).thenReturn({'relativePath': relJson});
      final room = MockRoom();
      final client = MockMatrixClient();
      final database = MockMatrixDatabase();
      when(() => ev.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      final descriptorUri = Uri.parse('mxc://server/purge');
      when(ev.attachmentOrThumbnailMxcUrl).thenReturn(descriptorUri);
      when(
        () => database.deleteFile(descriptorUri),
      ).thenAnswer((_) async => true);
      when(
        () => loggingService.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

      JournalEntry buildEntry(int clock, String text) => JournalEntry(
        meta: Metadata(
          id: 'purge',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          vectorClock: VectorClock({'n': clock}),
        ),
        entryText: EntryText(plainText: text),
      );

      var downloads = 0;
      when(ev.downloadAndDecryptAttachment).thenAnswer((_) async {
        downloads++;
        final entry = downloads == 1
            ? buildEntry(1, 'stale')
            : buildEntry(
                2,
                'fresh',
              );
        return MatrixFile(
          bytes: Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits),
          name: 'entry.json',
        );
      });
      index.record(ev);

      final loader = SmartJournalEntityLoader(
        attachmentIndex: index,
        loggingService: loggingService,
      );
      final processorWithSmartLoader = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: loader,
      );

      var purges = 0;
      processorWithSmartLoader.cachePurgeListener = () => purges++;

      final loaded = await loader.load(
        jsonPath: relJson,
        incomingVectorClock: const VectorClock({'n': 2}),
      );

      // The callback the processor forwarded fired exactly once for the
      // single stale descriptor that was purged before the fresh re-fetch.
      expect(purges, 1);
      expect(loaded.entryText?.plainText, 'fresh');
      verify(() => database.deleteFile(descriptorUri)).called(1);
    },
  );

  test(
    'self-echo lookup swallows a throwing VectorClockService.getHost — the '
    'event is treated as non-self-echo and flows through the normal apply '
    'path while the failure is logged and the null host id is cached',
    () async {
      final localVcService = MockVectorClockService();
      when(localVcService.getHost).thenThrow(Exception('vc unavailable'));

      final processorWithVc = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        vectorClockService: localVcService,
      );

      const message = SyncMessage.journalEntity(
        id: 'entity-vc-throws',
        jsonPath: '/entity-vc-throws.json',
        vectorClock: VectorClock({'host-peer': 1}),
        status: SyncEntryStatus.update,
        originatingHostId: 'host-peer',
      );
      when(
        () => journalEntityLoader.load(
          jsonPath: '/entity-vc-throws.json',
          incomingVectorClock: const VectorClock({'host-peer': 1}),
        ),
      ).thenAnswer((_) async => fallbackJournalEntity);
      when(() => event.text).thenReturn(encodeMessage(message));

      // Two events so we can assert the failed lookup is cached: getHost is
      // attempted once, the null result memoized, and the message still
      // applies (not skipped as a self-echo).
      await processorWithVc.process(event: event, journalDb: journalDb);
      await processorWithVc.process(event: event, journalDb: journalDb);

      verify(localVcService.getHost).called(1);
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'processor.selfEcho.hostLookup',
        ),
      ).called(1);
      verify(
        () => journalDb.updateJournalEntity(fallbackJournalEntity),
      ).called(2);
    },
  );

  test(
    'SyncEntityDefinition carrying a LabelDefinition upserts it and notifies '
    'the labels channel alongside the entity id',
    () async {
      final message = SyncMessage.entityDefinition(
        entityDefinition: testLabelDefinition1,
        status: SyncEntryStatus.initial,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(
        () => journalDb.upsertEntityDefinition(testLabelDefinition1),
      ).called(1);
      verify(
        () => updateNotifications.notify(
          {testLabelDefinition1.id, labelsNotification},
          fromSync: true,
        ),
      ).called(1);
    },
  );

  test(
    'SyncSyncNodeProfile rethrows and logs when the directory upsert fails so '
    'the inbound event stays eligible for retry',
    () async {
      final repo = MockSyncNodeProfileRepository();
      final profile = SyncNodeProfile(
        hostId: 'peer-fail',
        displayName: 'Flaky',
        platform: 'linux',
        capabilities: const [NodeCapability.ollamaLlm],
        updatedAt: DateTime.utc(2026, 3, 15, 12),
      );
      when(
        () => repo.upsertNode(profile),
      ).thenThrow(Exception('write refused'));

      final processorWithRepo = SyncEventProcessor(
        loggingService: loggingService,
        updateNotifications: updateNotifications,
        aiConfigRepository: aiConfigRepository,
        settingsDb: settingsDb,
        journalEntityLoader: journalEntityLoader,
        syncNodeProfileRepository: repo,
      );

      when(() => event.text).thenReturn(
        encodeMessage(SyncMessage.syncNodeProfile(profile: profile)),
      );

      await expectLater(
        processorWithRepo.process(event: event, journalDb: journalDb),
        throwsA(isA<Exception>()),
      );
      verify(() => repo.upsertNode(profile)).called(1);
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'apply.upsert',
        ),
      ).called(1);
    },
  );
}
