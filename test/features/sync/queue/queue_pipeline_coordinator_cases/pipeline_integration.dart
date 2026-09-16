part of '../queue_pipeline_coordinator_test.dart';

extension _PipelineIntegrationCases on _QueueCoordinatorTestSetup {
  void registerPipelineIntegration() {
    // ──────────────────────────────────────────────────────────────────────
    // Pipeline integration coverage (merged from the dissolved
    // queue_pipeline_integration_test.dart per the one-test-file-per-source
    // rule): real InboundQueue + worker + marker writes against the
    // in-memory SyncDatabase; only the session/room/processor edges are
    // mocked.
    group('pipeline integration (real queue/worker)', () {
      late MockStubbableSyncEventProcessor liveProcessor;
      late SyncSequenceLogService liveSequenceLog;
      late MockRoom room;

      setUp(() {
        liveProcessor = MockStubbableSyncEventProcessor();
        liveSequenceLog = SyncSequenceLogService(
          syncDatabase: syncDb,
          vectorClockService: MockVectorClockService(),
          loggingService: MockDomainLogger(),
        );
        room = MockRoom();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => room.id).thenReturn(roomId);
        // Non-partial so the coordinator's _maybePostLoadCurrentRoom
        // short-circuits instead of trying to call room.postLoad() on a
        // bare mock.
        when(() => room.partial).thenReturn(false);
        when(
          () => settingsDb.itemByKey(lastReadMatrixEventId),
        ).thenAnswer((_) async => null);
        when(
          () => settingsDb.itemByKey(lastReadMatrixEventTs),
        ).thenAnswer((_) async => null);
      });

      QueuePipelineCoordinator buildIntegration({
        AttachmentIndex? attachmentIndex,
        AttachmentIngestor? attachmentIngestor,
      }) => QueuePipelineCoordinator(
        syncDb: syncDb,
        settingsDb: settingsDb,
        journalDb: journalDb,
        sessionManager: sessionManager,
        roomManager: roomManager,
        eventProcessor: liveProcessor,
        sequenceLogService: liveSequenceLog,
        activityGate: null,
        logging: logging,
        bridgeOverride: bridge,
        attachmentIndex: attachmentIndex,
        attachmentIngestor: attachmentIngestor,
      );

      test(
        'flag-on path: live event flows through queue -> worker -> apply',
        () async {
          final prepared = MockPreparedSyncEvent();
          when(
            () => liveProcessor.prepare(event: any(named: 'event')),
          ).thenAnswer((_) async => prepared);
          final applied = Completer<void>();
          when(
            () => liveProcessor.apply(
              prepared: any(named: 'prepared'),
              journalDb: journalDb,
              afterCommit: any(named: 'afterCommit'),
            ),
          ).thenAnswer((_) async {
            if (!applied.isCompleted) {
              applied.complete();
            }
            return null;
          });

          final coordinator = buildIntegration();
          await coordinator.start();
          addTearDown(() => coordinator.stop(drainFirst: true));

          // Emit a live event. The coordinator's subscription routes it
          // through enqueueLive -> queue row.
          // The running worker loop wakes on the depth signal and applies.
          final event = _buildLiveSyncEvent(
            eventId: r'$live1',
            roomId: roomId,
            originTsMs: 1000,
          );
          timelineCtl.add(event);

          await applied.future;
          await coordinator.queue.waitForDrainAtMostTo(0);

          verify(
            () => liveProcessor.prepare(event: any(named: 'event')),
          ).called(1);
          verify(
            () => liveProcessor.apply(
              prepared: prepared,
              journalDb: journalDb,
              afterCommit: any(named: 'afterCommit'),
            ),
          ).called(1);

          // Queue is empty post-apply.
          final stats = await coordinator.queue.stats();
          expect(stats.total, 0);

          // Marker advanced under the monotonic guard (F2).
          final marker = await (syncDb.select(
            syncDb.queueMarkers,
          )..where((t) => t.roomId.equals(roomId))).getSingle();
          expect(marker.lastAppliedTs, 1000);
        },
      );

      test(
        'pendingAttachment -> abandoned -> AttachmentIndex.record -> '
        'resurrection -> apply: proves the end-to-end self-healing flow '
        'through real SyncDatabase + real coordinator + real AttachmentIndex',
        () async {
          final prepared = MockPreparedSyncEvent();
          var attachmentAvailable = false;
          when(
            () => liveProcessor.prepare(event: any(named: 'event')),
          ).thenAnswer((_) async {
            if (!attachmentAvailable) {
              throw const FileSystemException(
                'attachment descriptor not yet available',
              );
            }
            return prepared;
          });
          final appliedDone = Completer<void>();
          when(
            () => liveProcessor.apply(
              prepared: any(named: 'prepared'),
              journalDb: journalDb,
              afterCommit: any(named: 'afterCommit'),
            ),
          ).thenAnswer((_) async {
            if (!appliedDone.isCompleted) {
              appliedDone.complete();
            }
            return null;
          });

          final attachmentIndex = AttachmentIndex(logging: MockDomainLogger());
          addTearDown(attachmentIndex.dispose);

          final coordinator = buildIntegration(
            attachmentIndex: attachmentIndex,
          );
          await coordinator.start();
          addTearDown(() => coordinator.stop(drainFirst: true));

          // Emit a sync event referencing an attachment JSON path. The
          // coordinator's enqueue path reads `jsonPath` from the event
          // content and persists it on the queue row so the later
          // resurrection-by-path lookup has something to match.
          const path = '/audio/2026-04-21/pending.m4a.json';
          final event = MockEvent();
          final content = <String, dynamic>{
            'msgtype': syncMessageType,
            'jsonPath': path,
          };
          when(() => event.eventId).thenReturn(r'$pendingAttach');
          when(() => event.roomId).thenReturn(roomId);
          when(() => event.type).thenReturn(EventTypes.Message);
          when(() => event.status).thenReturn(EventStatus.synced);
          when(() => event.content).thenReturn(content);
          when(() => event.text).thenReturn('stub');
          when(
            () => event.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(3000));
          when(event.toJson).thenReturn(<String, dynamic>{
            'event_id': r'$pendingAttach',
            'room_id': roomId,
            'origin_server_ts': 3000,
            'type': EventTypes.Message,
            'sender': '@tester:example.org',
            'content': content,
          });

          timelineCtl.add(event);

          // Phase 1 - wait for the row to start retrying, then transition
          // it straight to abandoned so we can exercise resurrection
          // without sleeping through the full 30s -> 10min ladder.
          {
            await _waitForQueueStats(
              coordinator.queue,
              (stats) => stats.retrying > 0 || stats.abandoned > 0,
            );
            final entries = await (syncDb.select(
              syncDb.inboundEventQueue,
            )..where((t) => t.eventId.equals(r'$pendingAttach'))).get();
            expect(entries, hasLength(1));
            await (syncDb.update(
              syncDb.inboundEventQueue,
            )..where((t) => t.queueId.equals(entries.first.queueId))).write(
              InboundEventQueueCompanion(
                status: const Value('abandoned'),
                abandonedAt: Value(
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
                ),
                lastErrorReason: const Value('maxAttempts(pendingAttachment)'),
              ),
            );
          }

          // Sanity check: the row is abandoned, the path column carries
          // our attachment key, no prepare/apply happened since the
          // pending race started.
          {
            final abandoned = await (syncDb.select(
              syncDb.inboundEventQueue,
            )..where((t) => t.eventId.equals(r'$pendingAttach'))).getSingle();
            expect(abandoned.status, 'abandoned');
            expect(abandoned.jsonPath, path);
          }

          // Phase 2 - simulate the attachment landing. We flip the
          // processor's retriable flag so the next prepare succeeds,
          // then record an attachment event for the matching path. The
          // coordinator's `pathRecorded` subscription fires, calls
          // `queue.resurrectByPaths`, and the worker wakes.
          attachmentAvailable = true;

          final attachmentEvent = MockEvent();
          when(() => attachmentEvent.content).thenReturn(<String, dynamic>{
            'relativePath': path,
          });
          when(() => attachmentEvent.eventId).thenReturn(r'$attachmentLanded');
          when(
            () => attachmentEvent.attachmentMimetype,
          ).thenReturn('application/json');
          attachmentIndex.record(attachmentEvent);

          // Phase 3 - wait for resurrection + apply + marker advance.
          await appliedDone.future;
          await _waitForQueueStats(
            coordinator.queue,
            (stats) => stats.applied > 0,
          );

          verify(
            () => liveProcessor.apply(
              prepared: prepared,
              journalDb: journalDb,
              afterCommit: any(named: 'afterCommit'),
            ),
          ).called(1);

          final applied = await (syncDb.select(
            syncDb.inboundEventQueue,
          )..where((t) => t.eventId.equals(r'$pendingAttach'))).getSingle();
          expect(applied.status, 'applied');
          expect(applied.resurrectionCount, 1);

          final marker = await (syncDb.select(
            syncDb.queueMarkers,
          )..where((t) => t.roomId.equals(roomId))).getSingle();
          expect(marker.lastAppliedTs, 3000);
        },
      );

      test(
        'live attachment descriptor event: coordinator runs it through '
        'AttachmentIngestor, which records it in AttachmentIndex, which '
        'fires pathRecorded, which resurrects the abandoned sync-payload '
        'row - full production chain with no manual index poking',
        () async {
          final prepared = MockPreparedSyncEvent();
          var attachmentAvailable = false;
          when(
            () => liveProcessor.prepare(event: any(named: 'event')),
          ).thenAnswer((_) async {
            if (!attachmentAvailable) {
              throw const FileSystemException(
                'attachment descriptor not yet available',
              );
            }
            return prepared;
          });
          final appliedDone = Completer<void>();
          when(
            () => liveProcessor.apply(
              prepared: any(named: 'prepared'),
              journalDb: journalDb,
              afterCommit: any(named: 'afterCommit'),
            ),
          ).thenAnswer((_) async {
            if (!appliedDone.isCompleted) {
              appliedDone.complete();
            }
            return null;
          });

          final attachmentIndex = AttachmentIndex(logging: MockDomainLogger());
          addTearDown(attachmentIndex.dispose);
          // documentsDirectory=null skips the download step - we only
          // need the ingestor's record() side effect, which runs before
          // any download work and fires `pathRecorded`. A real device
          // would pass its documents dir and actually save the JSON.
          final ingestor = AttachmentIngestor();
          addTearDown(ingestor.dispose);

          final coordinator = buildIntegration(
            attachmentIndex: attachmentIndex,
            attachmentIngestor: ingestor,
          );
          await coordinator.start();
          addTearDown(() => coordinator.stop(drainFirst: true));

          // Phase 1 - a sync-payload event references an attachment
          // that has not landed yet. The worker retries once, we flip
          // it straight to abandoned to skip the real 30 s ladder.
          const path = '/audio/2026-04-21/descriptor-live.m4a.json';
          final syncEvent = MockEvent();
          final syncContent = <String, dynamic>{
            'msgtype': syncMessageType,
            'jsonPath': path,
          };
          when(() => syncEvent.eventId).thenReturn(r'$liveSyncAwaiting');
          when(() => syncEvent.roomId).thenReturn(roomId);
          when(() => syncEvent.type).thenReturn(EventTypes.Message);
          when(() => syncEvent.status).thenReturn(EventStatus.synced);
          when(() => syncEvent.content).thenReturn(syncContent);
          when(() => syncEvent.text).thenReturn('stub');
          when(
            () => syncEvent.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(4000));
          when(syncEvent.toJson).thenReturn(<String, dynamic>{
            'event_id': r'$liveSyncAwaiting',
            'room_id': roomId,
            'origin_server_ts': 4000,
            'type': EventTypes.Message,
            'sender': '@tester:example.org',
            'content': syncContent,
          });

          timelineCtl.add(syncEvent);

          // Wait for the row to become retrying; then flip to abandoned
          // (shortcut past the production ladder).
          {
            await _waitForQueueStats(
              coordinator.queue,
              (stats) => stats.retrying > 0 || stats.abandoned > 0,
            );
            final entries = await (syncDb.select(
              syncDb.inboundEventQueue,
            )..where((t) => t.eventId.equals(r'$liveSyncAwaiting'))).get();
            expect(entries, hasLength(1));
            await (syncDb.update(
              syncDb.inboundEventQueue,
            )..where((t) => t.queueId.equals(entries.first.queueId))).write(
              InboundEventQueueCompanion(
                status: const Value('abandoned'),
                abandonedAt: Value(
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
                ),
                lastErrorReason: const Value('maxAttempts(pendingAttachment)'),
              ),
            );
          }

          // Phase 2 - the attachment descriptor event lands on the
          // coordinator's live stream. The coordinator runs it through
          // `AttachmentIngestor.process` which calls
          // `attachmentIndex.record(event)` synchronously. That fires
          // `pathRecorded` -> the coordinator's own subscription calls
          // `queue.resurrectByPaths([path])` -> the row flips back to
          // `enqueued` and the next prepare succeeds (we flip the flag
          // right before emitting the event).
          attachmentAvailable = true;

          final attachmentEvent = MockEvent();
          final attachmentContent = <String, dynamic>{
            'relativePath': path,
          };
          when(() => attachmentEvent.eventId).thenReturn(r'$descriptorLanded');
          when(() => attachmentEvent.roomId).thenReturn(roomId);
          when(() => attachmentEvent.type).thenReturn(EventTypes.Message);
          when(() => attachmentEvent.status).thenReturn(EventStatus.synced);
          when(() => attachmentEvent.content).thenReturn(attachmentContent);
          when(() => attachmentEvent.text).thenReturn('attachment');
          when(
            () => attachmentEvent.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(4500));
          when(
            () => attachmentEvent.attachmentMimetype,
          ).thenReturn('application/json');
          when(attachmentEvent.toJson).thenReturn(<String, dynamic>{
            'event_id': r'$descriptorLanded',
            'room_id': roomId,
            'origin_server_ts': 4500,
            'type': EventTypes.Message,
            'sender': '@tester:example.org',
            'content': attachmentContent,
          });

          timelineCtl.add(attachmentEvent);

          // Phase 3 - wait for resurrection + apply.
          await appliedDone.future;
          await _waitForQueueStats(
            coordinator.queue,
            (stats) => stats.applied > 0,
          );

          verify(
            () => liveProcessor.apply(
              prepared: prepared,
              journalDb: journalDb,
              afterCommit: any(named: 'afterCommit'),
            ),
          ).called(1);

          final applied = await (syncDb.select(
            syncDb.inboundEventQueue,
          )..where((t) => t.eventId.equals(r'$liveSyncAwaiting'))).getSingle();
          expect(applied.status, 'applied');
          expect(applied.resurrectionCount, 1);
        },
      );
    });
  }
}
