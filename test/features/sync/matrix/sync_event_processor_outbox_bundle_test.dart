// ignore_for_file: cascade_invocations

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - SyncOutboxBundle integration', () {
    test(
      'an inline outboxBundle is wired into the apply pipeline and each '
      'child flows through its existing per-type handler. Detailed '
      'unpacker behaviour (sidecar resolution, fault isolation, nested '
      'bundles, ordering) is covered in '
      'test/features/sync/matrix/outbox_bundle_unpacker_test.dart.',
      () async {
        const bundle = SyncOutboxBundle(
          children: [
            SyncMessage.aiConfigDelete(id: 'cfg-1'),
            SyncMessage.aiConfigDelete(id: 'cfg-2'),
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(bundle));

        await processor.process(event: event, journalDb: journalDb);

        final captured = verify(
          () => aiConfigRepository.deleteConfig(
            captureAny<String>(),
            fromSync: true,
          ),
        ).captured;
        expect(captured, ['cfg-1', 'cfg-2']);
      },
    );

    test(
      'resolveOutboxBundleManifestForTesting returns null for a null '
      'jsonPath — proves the manifest resolver early-skips before any disk '
      'IO when the bundle stub has no jsonPath to fetch',
      () async {
        final result = await processor.resolveOutboxBundleManifestForTesting(
          null,
        );
        expect(result, isNull);
      },
    );

    group('manifest resolver on disk', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('outbox_bundle_test');
        if (getIt.isRegistered<Directory>()) {
          getIt.unregister<Directory>();
        }
        getIt.registerSingleton<Directory>(tempDir);
      });

      tearDown(() async {
        await getIt.reset();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'falls back to a disk read when no descriptor is registered, '
        'parses the v1 manifest, materializes each SyncJournalEntity '
        "child's payload to its declared jsonPath, and returns a "
        'reconstructed bundle whose children round-trip through '
        'SyncMessage.fromJson',
        () async {
          final entity = JournalEntry(
            meta: Metadata(
              id: 'bundle-entry-1',
              createdAt: DateTime.utc(2026, 4, 25),
              updatedAt: DateTime.utc(2026, 4, 25),
              dateFrom: DateTime.utc(2026, 4, 25),
              dateTo: DateTime.utc(2026, 4, 25),
              vectorClock: const VectorClock({'host-A': 3}),
            ),
            entryText: const EntryText(plainText: 'inside the bundle'),
          );

          const entityRelativePath =
              '/journal/2026-04-25/bundle-entry-1.entry.json';
          const bundleRelativePath = '/outbox_bundles/test-bundle.json';

          final manifest = <String, dynamic>{
            'version': 1,
            'entries': [
              <String, dynamic>{
                'envelope': const SyncMessage.journalEntity(
                  id: 'bundle-entry-1',
                  jsonPath: entityRelativePath,
                  vectorClock: VectorClock({'host-A': 3}),
                  status: SyncEntryStatus.update,
                ).toJson(),
                'payload': entity.toJson(),
              },
              <String, dynamic>{
                'envelope': const SyncMessage.aiConfigDelete(
                  id: 'cfg-1',
                ).toJson(),
              },
            ],
          };

          // Drop the manifest at the disk-fallback location: the resolver
          // will read it via targetFile.readAsString() because no
          // descriptor event is registered.
          final manifestFile = File(
            path.join(
              tempDir.path,
              stripLeadingSlashes(bundleRelativePath),
            ),
          )..parent.createSync(recursive: true);
          manifestFile.writeAsStringSync(json.encode(manifest));

          final resolved = await processor
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNotNull);
          expect(resolved!.jsonPath, bundleRelativePath);
          expect(resolved.children, hasLength(2));
          expect(resolved.children.first, isA<SyncJournalEntity>());
          expect(resolved.children.last, isA<SyncAiConfigDelete>());

          // The journal entity payload was materialized to its declared
          // jsonPath under the documents directory, so the apply pipeline's
          // SmartJournalEntityLoader reads it locally as a cache hit.
          final materialized = File(
            path.join(tempDir.path, stripLeadingSlashes(entityRelativePath)),
          );
          expect(materialized.existsSync(), isTrue);
          final roundTripped = JournalEntity.fromJson(
            json.decode(materialized.readAsStringSync())
                as Map<String, dynamic>,
          );
          expect(roundTripped.meta.id, 'bundle-entry-1');
          expect(
            roundTripped.meta.vectorClock,
            const VectorClock({'host-A': 3}),
          );
        },
      );

      test(
        'returns null when the manifest version does not match — receivers '
        'reject unknown wire shapes and let the surrounding retry mechanics '
        're-deliver the bundle under a forward-compatible code path instead '
        'of feeding garbage into JournalEntity.fromJson',
        () async {
          const bundleRelativePath = '/outbox_bundles/v99.json';
          final manifestFile = File(
            path.join(
              tempDir.path,
              stripLeadingSlashes(bundleRelativePath),
            ),
          )..parent.createSync(recursive: true);
          manifestFile.writeAsStringSync(
            json.encode(<String, dynamic>{
              'version': 99,
              'entries': const <Map<String, dynamic>>[],
            }),
          );

          final resolved = await processor
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNull);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(
                that: isA<String>().having(
                  (msg) => msg,
                  'message',
                  contains('manifest version=99 unsupported'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'processor.resolve.outboxBundle.unknownVersion',
            ),
          ).called(1);
        },
      );

      test(
        'aborts the whole bundle (returns null) when a SyncJournalEntity '
        'envelope has no inline payload — silently skipping the child '
        'would let the bundle ack while the entity never reaches the '
        'local DB; peers recover the missing entry via the sequence-log '
        'backfill path',
        () async {
          const bundleRelativePath = '/outbox_bundles/missing-payload.json';
          final manifestFile = File(
            path.join(
              tempDir.path,
              stripLeadingSlashes(bundleRelativePath),
            ),
          )..parent.createSync(recursive: true);
          manifestFile.writeAsStringSync(
            json.encode(<String, dynamic>{
              'version': 1,
              'entries': [
                <String, dynamic>{
                  'envelope': const SyncMessage.journalEntity(
                    id: 'orphan',
                    jsonPath: '/journal/2026-04-25/orphan.entry.json',
                    vectorClock: VectorClock({'host-A': 1}),
                    status: SyncEntryStatus.update,
                  ).toJson(),
                  // No `payload` key — this is the malformed case.
                },
              ],
            }),
          );

          final resolved = await processor
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNull);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(
                that: isA<String>().having(
                  (msg) => msg,
                  'message',
                  contains('missing payload for SyncJournalEntity'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'processor.resolve.outboxBundle.missingPayload',
            ),
          ).called(1);
        },
      );

      test(
        'when local DB version dominates the incoming envelope, refreshes '
        'the on-disk cache from local.toJson() rather than overwriting it '
        'with a staler bundled payload — guarantees SmartJournalEntityLoader '
        'never serves a stale fixture even when the cache file was missing '
        'or out-of-date',
        () async {
          final localEntity = JournalEntry(
            meta: Metadata(
              id: 'dominant-id',
              createdAt: DateTime.utc(2026, 4, 25),
              updatedAt: DateTime.utc(2026, 4, 25),
              dateFrom: DateTime.utc(2026, 4, 25),
              dateTo: DateTime.utc(2026, 4, 25),
              vectorClock: const VectorClock({'host-A': 9}),
            ),
            entryText: const EntryText(plainText: 'canonical local'),
          );

          when(
            () => journalDb.journalEntityMapForIds(any<Iterable<String>>()),
          ).thenAnswer((_) async => {'dominant-id': localEntity});

          final processorWithDb = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            journalDb: journalDb,
          );

          const entityRelativePath =
              '/journal/2026-04-25/dominant-id.entry.json';
          const bundleRelativePath = '/outbox_bundles/dominates.json';

          // Pre-populate the cache file with an OLDER version to make the
          // refresh observable: if the resolver did the right thing, the
          // post-resolve disk content equals localEntity.toJson(); if it
          // did the wrong thing, it stays as the older fixture.
          final cacheFile = File(
            path.join(tempDir.path, stripLeadingSlashes(entityRelativePath)),
          )..parent.createSync(recursive: true);
          cacheFile.writeAsStringSync(
            json.encode(<String, dynamic>{'stale': true}),
          );

          final manifestFile = File(
            path.join(
              tempDir.path,
              stripLeadingSlashes(bundleRelativePath),
            ),
          )..parent.createSync(recursive: true);
          manifestFile.writeAsStringSync(
            json.encode(<String, dynamic>{
              'version': 1,
              'entries': [
                <String, dynamic>{
                  'envelope': const SyncMessage.journalEntity(
                    id: 'dominant-id',
                    jsonPath: entityRelativePath,
                    // Older than localEntity's VC -> local dominates.
                    vectorClock: VectorClock({'host-A': 1}),
                    status: SyncEntryStatus.update,
                  ).toJson(),
                  'payload': <String, dynamic>{'should': 'not-be-written'},
                },
              ],
            }),
          );

          final resolved = await processorWithDb
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNotNull);
          expect(resolved!.children.single, isA<SyncJournalEntity>());

          final refreshed = JournalEntity.fromJson(
            json.decode(cacheFile.readAsStringSync()) as Map<String, dynamic>,
          );
          // Cache now reflects the canonical DB version, not the bundled
          // one and not the stale pre-test fixture.
          expect(refreshed.meta.id, 'dominant-id');
          expect(
            refreshed.meta.vectorClock,
            const VectorClock({'host-A': 9}),
          );
        },
      );

      test(
        'aborts the whole bundle when an envelope.jsonPath escapes the '
        'documents sandbox — defence in depth against tampered manifests',
        () async {
          const bundleRelativePath = '/outbox_bundles/bad-path.json';
          final manifestFile = File(
            path.join(
              tempDir.path,
              stripLeadingSlashes(bundleRelativePath),
            ),
          )..parent.createSync(recursive: true);
          manifestFile.writeAsStringSync(
            json.encode(<String, dynamic>{
              'version': 1,
              'entries': [
                <String, dynamic>{
                  'envelope': const SyncMessage.journalEntity(
                    id: 'evil',
                    // Multi-level traversal escapes the documents dir;
                    // resolveJsonCandidateFile throws FileSystemException
                    // (a single `/..` collapses back to `/` under
                    // `path.normalize`, which would not escape).
                    jsonPath: '../../escape.entry.json',
                    vectorClock: VectorClock({'host-A': 1}),
                    status: SyncEntryStatus.update,
                  ).toJson(),
                  'payload': <String, dynamic>{'meta': <String, dynamic>{}},
                },
              ],
            }),
          );

          final resolved = await processor
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNull);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(that: isA<FileSystemException>()),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'processor.resolve.outboxBundle.invalidEntryPath',
            ),
          ).called(1);
        },
      );

      test(
        'returns null on a malformed manifest payload (missing or '
        'non-list `entries` field) — the malformed shape never reaches '
        'the per-child loop and surrounding diagnostics fire on a '
        'distinct subDomain so the failure is greppable',
        () async {
          const bundleRelativePath = '/outbox_bundles/no-entries.json';
          File(
              path.join(
                tempDir.path,
                stripLeadingSlashes(bundleRelativePath),
              ),
            )
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(
              json.encode(<String, dynamic>{'version': 1}),
            );

          final resolved = await processor
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNull);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(
                that: isA<String>().having(
                  (msg) => msg,
                  'message',
                  contains('manifest missing entries array'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'processor.resolve.outboxBundle.malformed',
            ),
          ).called(1);
        },
      );

      test(
        'silently skips malformed manifest entries (non-Map shapes, '
        'envelope JSON that does not deserialize, nested SyncOutboxBundle '
        'children) and resolves the rest — partial progress is preferable '
        'to dropping the whole bundle when the rotten entry is the only '
        'thing wrong',
        () async {
          const bundleRelativePath = '/outbox_bundles/mixed.json';
          File(
              path.join(
                tempDir.path,
                stripLeadingSlashes(bundleRelativePath),
              ),
            )
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(
              json.encode(<String, dynamic>{
                'version': 1,
                'entries': [
                  // Not a map → skipped silently.
                  'not-a-map',
                  // Map but envelope is not a Map → skipped silently.
                  <String, dynamic>{'envelope': 'not-a-map'},
                  // Envelope JSON that fails SyncMessage.fromJson →
                  // captured as envelopeParse but resolution continues.
                  <String, dynamic>{
                    'envelope': <String, dynamic>{
                      'runtimeType': 'no-such-variant',
                    },
                  },
                  // Nested SyncOutboxBundle child → defensively skipped
                  // by the resolver before the unpacker even sees it.
                  <String, dynamic>{
                    'envelope': const SyncOutboxBundle(
                      children: [],
                    ).toJson(),
                  },
                  // A valid inline-only child rounds out the manifest so
                  // the resolver still produces a usable bundle instead
                  // of returning null.
                  <String, dynamic>{
                    'envelope': const SyncMessage.aiConfigDelete(
                      id: 'cfg-good',
                    ).toJson(),
                  },
                ],
              }),
            );

          final resolved = await processor
              .resolveOutboxBundleManifestForTesting(bundleRelativePath);

          expect(resolved, isNotNull);
          expect(resolved!.children, hasLength(1));
          expect(resolved.children.single, isA<SyncAiConfigDelete>());
          // The envelope-parse error path captured an exception under
          // its own subDomain — at least once, exactly for the rotten
          // runtimeType entry above.
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'processor.resolve.outboxBundle.envelopeParse',
            ),
          ).called(1);
        },
      );
    });
  });
}
