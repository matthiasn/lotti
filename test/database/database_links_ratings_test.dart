// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

class _PrecheckThrowingJournalDb extends JournalDb {
  _PrecheckThrowingJournalDb() : super(inMemoryDatabase: true);

  bool _shouldThrow = true;

  @override
  drift.SimpleSelectStatement<T, R> select<T extends drift.HasResultSet, R>(
    drift.ResultSetImplementation<T, R> table, {
    bool distinct = false,
  }) {
    if (_shouldThrow &&
        table is drift.TableInfo<LinkedEntries, LinkedDbEntry>) {
      _shouldThrow = false;
      throw StateError('precheck failure');
    }
    return super.select(table, distinct: distinct);
  }
}

EntryLink buildEntryLink({
  required String id,
  required String fromId,
  required String toId,
  required DateTime timestamp,
}) {
  return EntryLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: timestamp,
    updatedAt: timestamp,
    vectorClock: const VectorClock({'db': 1}),
  );
}

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb links and ratings - ', () {
    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      await db?.close();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    group('Linked entities -', () {
      test(
        'getLinkedEntities returns linked children sorted by recency',
        () async {
          final base = DateTime(2024, 8);
          final parent = buildJournalEntry(
            id: 'parent-entry',
            timestamp: base,
            text: 'Parent',
          );
          final childOlder = buildJournalEntry(
            id: 'child-older',
            timestamp: base.subtract(const Duration(hours: 1)),
            text: 'Older child',
          );
          final childNewer = buildJournalEntry(
            id: 'child-newer',
            timestamp: base.add(const Duration(hours: 1)),
            text: 'Newer child',
          );

          await db!.upsertJournalDbEntity(toDbEntity(parent));
          await db!.upsertJournalDbEntity(toDbEntity(childOlder));
          await db!.upsertJournalDbEntity(toDbEntity(childNewer));

          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'link-older',
              fromId: parent.meta.id,
              toId: childOlder.meta.id,
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'link-newer',
              fromId: parent.meta.id,
              toId: childNewer.meta.id,
              timestamp: base.add(const Duration(minutes: 5)),
            ),
          );

          final results = await db!.getLinkedEntities(parent.meta.id);
          expect(results.map((e) => e.meta.id), ['child-newer', 'child-older']);
        },
      );

      test(
        'getLinkedEntities respects the private flag without a config subquery',
        () async {
          final base = DateTime(2024, 8, 3);
          final parent = buildJournalEntry(
            id: 'private-parent',
            timestamp: base,
            text: 'Parent',
          );
          final publicChild = buildJournalEntry(
            id: 'public-child',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Public child',
          );
          final privateChild = buildJournalEntry(
            id: 'private-child',
            timestamp: base.add(const Duration(minutes: 2)),
            text: 'Private child',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(parent));
          await db!.upsertJournalDbEntity(toDbEntity(publicChild));
          await db!.upsertJournalDbEntity(toDbEntity(privateChild));

          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'public-link',
              fromId: parent.meta.id,
              toId: publicChild.meta.id,
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'private-link',
              fromId: parent.meta.id,
              toId: privateChild.meta.id,
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );

          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          expect(privateConfig, isNotNull);

          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));
          expect(
            (await db!.getLinkedEntities(parent.meta.id)).map((e) => e.meta.id),
            ['public-child'],
          );

          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));
          expect(
            (await db!.getLinkedEntities(parent.meta.id)).map((e) => e.meta.id),
            ['private-child', 'public-child'],
          );
        },
      );

      test(
        'getLinkedToEntities respects the private flag without a config subquery',
        () async {
          final base = DateTime(2024, 8, 4);
          final publicParent = buildJournalEntry(
            id: 'public-parent',
            timestamp: base,
            text: 'Public parent',
          );
          final privateParent = buildJournalEntry(
            id: 'private-parent',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Private parent',
            privateFlag: true,
          );
          final child = buildJournalEntry(
            id: 'reverse-child',
            timestamp: base.add(const Duration(minutes: 2)),
            text: 'Child',
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicParent));
          await db!.upsertJournalDbEntity(toDbEntity(privateParent));
          await db!.upsertJournalDbEntity(toDbEntity(child));

          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'public-reverse-link',
              fromId: publicParent.meta.id,
              toId: child.meta.id,
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'private-reverse-link',
              fromId: privateParent.meta.id,
              toId: child.meta.id,
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );

          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          expect(privateConfig, isNotNull);

          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));
          final publicOnly = await db!.getLinkedToEntities(child.meta.id);
          expect(publicOnly.map((entry) => entry.id), ['public-parent']);

          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));
          final withPrivate = await db!.getLinkedToEntities(child.meta.id);
          expect(
            withPrivate.map((entry) => entry.id),
            ['private-parent', 'public-parent'],
          );
        },
      );

      test(
        'bulk journal id lookups respect private visibility on both fast paths',
        () async {
          final base = DateTime(2024, 8, 5);
          final publicEntry = buildJournalEntry(
            id: 'bulk-public-entry',
            timestamp: base,
            text: 'Public entry',
          );
          final privateEntry = buildJournalEntry(
            id: 'bulk-private-entry',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Private entry',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicEntry));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          expect(privateConfig, isNotNull);

          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));
          expect(
            (await db!.getJournalEntitiesForIdsUnordered({
              publicEntry.meta.id,
              privateEntry.meta.id,
            })).map((entry) => entry.meta.id),
            {'bulk-public-entry'},
          );

          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));

          final unordered = await db!.getJournalEntitiesForIdsUnordered({
            publicEntry.meta.id,
            privateEntry.meta.id,
          });
          expect(
            unordered.map((entry) => entry.meta.id).toSet(),
            {'bulk-public-entry', 'bulk-private-entry'},
          );

          final ordered = await db!.getJournalEntitiesForIds({
            publicEntry.meta.id,
            privateEntry.meta.id,
          });
          expect(
            ordered.map((entry) => entry.meta.id),
            ['bulk-private-entry', 'bulk-public-entry'],
          );

          expect(
            await db!.getJournalEntityIdsSortedByDateFromDesc({
              publicEntry.meta.id,
              privateEntry.meta.id,
            }),
            ['bulk-private-entry', 'bulk-public-entry'],
          );
        },
      );

      test(
        'journalEntityMapForIds bypasses the privacy filter and skips '
        'deleted rows — the outbox bundler always needs every entity '
        'regardless of UI privacy settings',
        () async {
          final base = DateTime(2024, 8, 6);
          final publicEntry = buildJournalEntry(
            id: 'map-public-entry',
            timestamp: base,
            text: 'Public entry',
          );
          final privateEntry = buildJournalEntry(
            id: 'map-private-entry',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Private entry',
            privateFlag: true,
          );
          final softDeletedEntry = buildJournalEntry(
            id: 'map-deleted-entry',
            timestamp: base.add(const Duration(minutes: 2)),
            text: 'Soft-deleted entry',
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicEntry));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));
          await db!.upsertJournalDbEntity(
            toDbEntity(softDeletedEntry).copyWith(deleted: true),
          );

          // Privacy filter is OFF — bulk-id-based read for sync still
          // returns the private entity (sync needs every row), and never
          // surfaces a soft-deleted row.
          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));

          final whenFilterOff = await db!.journalEntityMapForIds({
            publicEntry.meta.id,
            privateEntry.meta.id,
            softDeletedEntry.meta.id,
            'never-existed',
          });

          expect(whenFilterOff.keys.toSet(), {
            publicEntry.meta.id,
            privateEntry.meta.id,
          });
          expect(
            whenFilterOff[publicEntry.meta.id]!.meta.id,
            publicEntry.meta.id,
          );
          expect(
            whenFilterOff[privateEntry.meta.id]!.meta.id,
            privateEntry.meta.id,
          );

          // Privacy filter ON — same result; the bulk method ignores the
          // setting because it routes through the all-private query.
          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));
          final whenFilterOn = await db!.journalEntityMapForIds({
            publicEntry.meta.id,
            privateEntry.meta.id,
          });
          expect(whenFilterOn.keys.toSet(), {
            publicEntry.meta.id,
            privateEntry.meta.id,
          });

          // Empty input collapses to a constant map without hitting the DB.
          expect(await db!.journalEntityMapForIds(<String>{}), isEmpty);
        },
      );

      test('getBulkLinkedEntities groups results by parent id', () async {
        final base = DateTime(2024, 8, 2);
        final parentA = buildJournalEntry(
          id: 'bulk-parent-a',
          timestamp: base,
          text: 'Parent A',
        );
        final parentB = buildJournalEntry(
          id: 'bulk-parent-b',
          timestamp: base,
          text: 'Parent B',
        );
        final child1 = buildJournalEntry(
          id: 'bulk-child-1',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'Child 1',
        );
        final child2 = buildJournalEntry(
          id: 'bulk-child-2',
          timestamp: base.add(const Duration(minutes: 2)),
          text: 'Child 2',
        );
        final child3 = buildJournalEntry(
          id: 'bulk-child-3',
          timestamp: base.add(const Duration(minutes: 3)),
          text: 'Child 3',
        );

        for (final entry in [parentA, parentB, child1, child2, child3]) {
          await db!.upsertJournalDbEntity(toDbEntity(entry));
        }

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'bulk-link-a1',
            fromId: parentA.meta.id,
            toId: child1.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'bulk-link-a2',
            fromId: parentA.meta.id,
            toId: child2.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'bulk-link-b3',
            fromId: parentB.meta.id,
            toId: child3.meta.id,
            timestamp: base.add(const Duration(minutes: 2)),
          ),
        );

        final results = await db!.getBulkLinkedEntities({
          parentA.meta.id,
          parentB.meta.id,
        });

        expect(results[parentA.meta.id]!.map((e) => e.meta.id), [
          'bulk-child-2',
          'bulk-child-1',
        ]);
        expect(results[parentB.meta.id]!.map((e) => e.meta.id), [
          'bulk-child-3',
        ]);
      });

      test('getBulkLinkedEntities returns empty map for empty input', () async {
        final results = await db!.getBulkLinkedEntities({});
        expect(results, isEmpty);
      });
    });

    group('Entry links -', () {
      test('linksForEntryIds returns all links for target set', () async {
        final linkAb = buildEntryLink(
          id: 'link-ab',
          fromId: 'a',
          toId: 'b',
          timestamp: DateTime(2024, 8, 1),
        );
        final linkAc = buildEntryLink(
          id: 'link-ac',
          fromId: 'a',
          toId: 'c',
          timestamp: DateTime(2024, 8, 2),
        );
        final linkDe = buildEntryLink(
          id: 'link-de',
          fromId: 'd',
          toId: 'e',
          timestamp: DateTime(2024, 8, 3),
        );

        await db!.upsertEntryLink(linkAb);
        await db!.upsertEntryLink(linkAc);
        await db!.upsertEntryLink(linkDe);

        final results = await db!.linksForEntryIds({'b', 'c'});
        expect(results.map((link) => link.id).toSet(), {'link-ab', 'link-ac'});
      });

      test(
        'linksForEntryIdsBidirectional returns links for from/to matches',
        () async {
          final linkAb = buildEntryLink(
            id: 'link-ab',
            fromId: 'a',
            toId: 'b',
            timestamp: DateTime(2024, 8, 1),
          );
          final linkCa = buildEntryLink(
            id: 'link-ca',
            fromId: 'c',
            toId: 'a',
            timestamp: DateTime(2024, 8, 2),
          );

          await db!.upsertEntryLink(linkAb);
          await db!.upsertEntryLink(linkCa);

          final results = await db!.linksForEntryIdsBidirectional({'a'});
          expect(results.map((link) => link.id).toSet(), {
            'link-ab',
            'link-ca',
          });
        },
      );

      test(
        'basicLinksForEntryIds returns empty list for empty target set',
        () async {
          final results = await db!.basicLinksForEntryIds(<String>{});
          expect(results, isEmpty);
        },
      );

      test('basicLinksForEntryIds filters out RatingLink entries', () async {
        final basicLink = buildEntryLink(
          id: 'basic-link',
          fromId: 'task-1',
          toId: 'entry-1',
          timestamp: DateTime(2024, 8, 2),
        );
        final ratingLink = EntryLink.rating(
          id: 'rating-link',
          fromId: 'rating-1',
          toId: 'entry-1',
          createdAt: DateTime(2024, 8, 2),
          updatedAt: DateTime(2024, 8, 2),
          vectorClock: null,
        );

        await db!.upsertEntryLink(basicLink);
        await db!.upsertEntryLink(ratingLink);

        final results = await db!.basicLinksForEntryIds({'entry-1'});
        expect(results, hasLength(1));
        expect(results.single.id, 'basic-link');
        expect(results.single, isA<BasicLink>());
      });

      test('upsertEntryLink rejects self-links', () async {
        final link = buildEntryLink(
          id: 'self-link',
          fromId: 'self',
          toId: 'self',
          timestamp: DateTime(2024, 8, 4),
        );

        final written = await db!.upsertEntryLink(link);
        expect(written, 0);
        expect(await db!.linksForEntryIds({'self'}), isEmpty);
      });

      test('upsertEntryLink skips no-op updates', () async {
        final link = buildEntryLink(
          id: 'stable-link',
          fromId: 'origin',
          toId: 'target',
          timestamp: DateTime(2024, 8, 5),
        );

        final firstWrite = await db!.upsertEntryLink(link);
        final secondWrite = await db!.upsertEntryLink(link);

        expect(firstWrite, 1);
        expect(secondWrite, 0);
      });

      test('upsertEntryLink creates new link', () async {
        final link = buildEntryLink(
          id: 'new-link',
          fromId: 'origin',
          toId: 'fresh',
          timestamp: DateTime(2024, 8, 6),
        );

        final result = await db!.upsertEntryLink(link);
        expect(result, 1);
        final stored = await db!.linksForEntryIds({'fresh'});
        expect(stored.single.id, 'new-link');
      });

      test('upsertEntryLink updates existing link', () async {
        final link = buildEntryLink(
          id: 'update-link',
          fromId: 'source',
          toId: 'initial',
          timestamp: DateTime(2024, 8, 7),
        );
        await db!.upsertEntryLink(link);

        final updated = link.copyWith(
          toId: 'updated',
          updatedAt: DateTime(2024, 8, 8),
        );
        final result = await db!.upsertEntryLink(updated);
        expect(result, 1);

        final oldLookup = await db!.linksForEntryIds({'initial'});
        expect(oldLookup, isEmpty);
        final newLookup = await db!.linksForEntryIds({'updated'});
        expect(newLookup.single.toId, 'updated');
      });

      test('upsertEntryLink handles precheck errors gracefully', () async {
        final specialDb = _PrecheckThrowingJournalDb();
        addTearDown(() async {
          await specialDb.close();
        });
        await initConfigFlags(specialDb, inMemoryDatabase: true);

        final link = buildEntryLink(
          id: 'throwing-link',
          fromId: 'src',
          toId: 'dst',
          timestamp: DateTime(2024, 8, 9),
        );

        final result = await specialDb.upsertEntryLink(link);
        expect(result, 1);
        final stored = await specialDb.linksForEntryIds({'dst'});
        expect(stored, hasLength(1));
      });
    });

    group('Rating queries -', () {
      final base = DateTime(2024, 9, 1, 10);

      JournalEntity buildRatingEntry({
        required String id,
        required String targetId,
        DateTime? timestamp,
        DateTime? deletedAt,
      }) {
        final ts = timestamp ?? base;
        return JournalEntity.rating(
          meta: Metadata(
            id: id,
            createdAt: ts,
            updatedAt: ts,
            dateFrom: ts,
            dateTo: ts,
            deletedAt: deletedAt,
          ),
          data: RatingData(
            targetId: targetId,
            dimensions: const [
              RatingDimension(key: 'productivity', value: 0.8),
              RatingDimension(key: 'energy', value: 0.6),
            ],
          ),
        );
      }

      EntryLink buildRatingLink({
        required String id,
        required String fromId,
        required String toId,
        DateTime? timestamp,
        bool hidden = false,
      }) {
        final ts = timestamp ?? base;
        return EntryLink.rating(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: ts,
          updatedAt: ts,
          vectorClock: const VectorClock({'db': 1}),
          hidden: hidden,
        );
      }

      test('getRatingForTimeEntry returns rating entity', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-1',
          timestamp: base,
          text: 'Work session',
        );
        final ratingEntry = buildRatingEntry(
          id: 'rating-1',
          targetId: 'te-1',
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(ratingEntry));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-1',
            fromId: 'rating-1',
            toId: 'te-1',
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-1');
        expect(result, isNotNull);
        expect(result, isA<RatingEntry>());
        expect(result!.meta.id, 'rating-1');
        expect(result.data.targetId, 'te-1');
      });

      test(
        'getRatingForTimeEntry returns null when no rating exists',
        () async {
          final timeEntry = buildJournalEntry(
            id: 'te-no-rating',
            timestamp: base,
            text: 'No rating',
          );
          await db!.upsertJournalDbEntity(toDbEntity(timeEntry));

          final result = await db!.getRatingForTimeEntry('te-no-rating');
          expect(result, isNull);
        },
      );

      test('getRatingForTimeEntry excludes deleted ratings', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-deleted',
          timestamp: base,
          text: 'Session',
        );
        final deletedRating = buildRatingEntry(
          id: 'rating-deleted',
          targetId: 'te-deleted',
          deletedAt: base.add(const Duration(hours: 1)),
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(deletedRating));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-deleted',
            fromId: 'rating-deleted',
            toId: 'te-deleted',
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-deleted');
        expect(result, isNull);
      });

      test('getRatingForTimeEntry excludes hidden links', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-hidden',
          timestamp: base,
          text: 'Session',
        );
        final rating = buildRatingEntry(
          id: 'rating-hidden',
          targetId: 'te-hidden',
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(rating));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-hidden',
            fromId: 'rating-hidden',
            toId: 'te-hidden',
            hidden: true,
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-hidden');
        expect(result, isNull);
      });

      test('getRatingForTimeEntry returns most recently updated when '
          'multiple ratings exist', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-multi',
          timestamp: base,
          text: 'Session',
        );
        final olderRating = buildRatingEntry(
          id: 'rating-older',
          targetId: 'te-multi',
          timestamp: base,
        );
        final newerRating = buildRatingEntry(
          id: 'rating-newer',
          targetId: 'te-multi',
          timestamp: base.add(const Duration(hours: 2)),
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(olderRating));
        await db!.upsertJournalDbEntity(toDbEntity(newerRating));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-older',
            fromId: 'rating-older',
            toId: 'te-multi',
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-newer',
            fromId: 'rating-newer',
            toId: 'te-multi',
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-multi');
        expect(result, isNotNull);
        expect(result!.meta.id, 'rating-newer');
      });

      test(
        'getRatingIdsForTimeEntries returns mapping for multiple entries',
        () async {
          for (final i in [1, 2, 3]) {
            final teId = 'bulk-te-$i';
            final ratingId = 'bulk-rating-$i';
            await db!.upsertJournalDbEntity(
              toDbEntity(
                buildJournalEntry(
                  id: teId,
                  timestamp: base.add(Duration(hours: i)),
                  text: 'Session $i',
                ),
              ),
            );
            await db!.upsertJournalDbEntity(
              toDbEntity(
                buildRatingEntry(
                  id: ratingId,
                  targetId: teId,
                  timestamp: base.add(Duration(hours: i)),
                ),
              ),
            );
            await db!.upsertEntryLink(
              buildRatingLink(
                id: 'bulk-link-$i',
                fromId: ratingId,
                toId: teId,
                timestamp: base.add(Duration(hours: i)),
              ),
            );
          }

          final result = await db!.getRatingIdsForTimeEntries({
            'bulk-te-1',
            'bulk-te-2',
            'bulk-te-3',
          });
          expect(result.length, 3);
          expect(result['bulk-te-1'], 'bulk-rating-1');
          expect(result['bulk-te-2'], 'bulk-rating-2');
          expect(result['bulk-te-3'], 'bulk-rating-3');
        },
      );

      test('getRatingIdsForTimeEntries excludes deleted ratings', () async {
        // Active rating for te-a
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildJournalEntry(
              id: 'del-te-a',
              timestamp: base,
              text: 'Session A',
            ),
          ),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildRatingEntry(
              id: 'del-rating-a',
              targetId: 'del-te-a',
            ),
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'del-link-a',
            fromId: 'del-rating-a',
            toId: 'del-te-a',
          ),
        );

        // Deleted rating for te-b
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildJournalEntry(
              id: 'del-te-b',
              timestamp: base,
              text: 'Session B',
            ),
          ),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildRatingEntry(
              id: 'del-rating-b',
              targetId: 'del-te-b',
              deletedAt: base.add(const Duration(hours: 1)),
            ),
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'del-link-b',
            fromId: 'del-rating-b',
            toId: 'del-te-b',
          ),
        );

        final result = await db!.getRatingIdsForTimeEntries({
          'del-te-a',
          'del-te-b',
        });
        expect(result.length, 1);
        expect(result.containsKey('del-te-a'), isTrue);
        expect(result.containsKey('del-te-b'), isFalse);
      });

      test('getRatingIdsForTimeEntries excludes hidden links', () async {
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildJournalEntry(
              id: 'hid-te',
              timestamp: base,
              text: 'Session',
            ),
          ),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildRatingEntry(
              id: 'hid-rating',
              targetId: 'hid-te',
            ),
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'hid-link',
            fromId: 'hid-rating',
            toId: 'hid-te',
            hidden: true,
          ),
        );

        final result = await db!.getRatingIdsForTimeEntries({'hid-te'});
        expect(result.isEmpty, isTrue);
      });

      test(
        'getRatingIdsForTimeEntries returns empty map for empty input',
        () async {
          final result = await db!.getRatingIdsForTimeEntries({});
          expect(result.isEmpty, isTrue);
        },
      );
    });

    group('getAllRatingsForTarget -', () {
      test('returns all rating entries for a target across catalogs', () async {
        final base = DateTime(2024, 11, 8, 10);
        final timeEntry = buildJournalEntry(
          id: 'te-all-ratings',
          timestamp: base,
          text: 'Session for all ratings',
        );
        final rating1 = JournalEntity.rating(
          meta: Metadata(
            id: 'all-rating-1',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: const RatingData(
            targetId: 'te-all-ratings',
            dimensions: [RatingDimension(key: 'energy', value: 0.7)],
          ),
        );
        final rating2 = JournalEntity.rating(
          meta: Metadata(
            id: 'all-rating-2',
            createdAt: base.add(const Duration(minutes: 5)),
            updatedAt: base.add(const Duration(minutes: 5)),
            dateFrom: base.add(const Duration(minutes: 5)),
            dateTo: base.add(const Duration(minutes: 5)),
          ),
          data: const RatingData(
            targetId: 'te-all-ratings',
            dimensions: [RatingDimension(key: 'focus', value: 0.9)],
          ),
        );
        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(rating1));
        await db!.upsertJournalDbEntity(toDbEntity(rating2));

        await db!.upsertEntryLink(
          EntryLink.rating(
            id: 'link-all-rating-1',
            fromId: 'all-rating-1',
            toId: 'te-all-ratings',
            createdAt: base,
            updatedAt: base,
            vectorClock: const VectorClock({'db': 1}),
          ),
        );
        await db!.upsertEntryLink(
          EntryLink.rating(
            id: 'link-all-rating-2',
            fromId: 'all-rating-2',
            toId: 'te-all-ratings',
            createdAt: base.add(const Duration(minutes: 5)),
            updatedAt: base.add(const Duration(minutes: 5)),
            vectorClock: const VectorClock({'db': 1}),
          ),
        );

        final results = await db!.getAllRatingsForTarget('te-all-ratings');
        expect(results, hasLength(2));
        expect(
          results.map((r) => r.meta.id),
          containsAll(['all-rating-1', 'all-rating-2']),
        );
      });

      test('returns empty list when no ratings exist for target', () async {
        final results = await db!.getAllRatingsForTarget('no-such-target');
        expect(results, isEmpty);
      });
    });

    group('entryLinkById -', () {
      test('returns link when found', () async {
        final base = DateTime(2024, 11, 9, 10);
        final link = buildEntryLink(
          id: 'link-by-id-1',
          fromId: 'from-by-id-1',
          toId: 'to-by-id-1',
          timestamp: base,
        );
        await db!.upsertEntryLink(link);

        final result = await db!.entryLinkById('link-by-id-1');
        expect(result, isNotNull);
        expect(result!.id, 'link-by-id-1');
        expect(result.fromId, 'from-by-id-1');
        expect(result.toId, 'to-by-id-1');
      });

      test('returns null when link not found', () async {
        final result = await db!.entryLinkById('no-such-link');
        expect(result, isNull);
      });
    });

    group('upsertEntryLink tombstone handling -', () {
      test(
        'replaces a soft-deleted tombstone when reinserting with different id',
        () async {
          final base = DateTime(2024, 11, 10, 10);
          // Insert a hidden (tombstone) link for (from, to, type).
          final tombstone = EntryLink.basic(
            id: 'tombstone-link-id',
            fromId: 'tombstone-from',
            toId: 'tombstone-to',
            createdAt: base,
            updatedAt: base,
            vectorClock: const VectorClock({'db': 1}),
            hidden: true,
          );
          await db!.upsertEntryLink(tombstone);

          // Now insert a fresh link with a new id but same (from, to, type).
          final fresh = EntryLink.basic(
            id: 'fresh-link-id',
            fromId: 'tombstone-from',
            toId: 'tombstone-to',
            createdAt: base.add(const Duration(seconds: 1)),
            updatedAt: base.add(const Duration(seconds: 1)),
            vectorClock: const VectorClock({'db': 2}),
          );
          final res = await db!.upsertEntryLink(fresh);
          // Should insert (not blocked by tombstone).
          expect(res, isNot(0));

          // Tombstone should be gone; fresh link should exist.
          expect(await db!.entryLinkById('tombstone-link-id'), isNull);
          expect(await db!.entryLinkById('fresh-link-id'), isNotNull);
        },
      );
    });

    group('getBulkLinkedTimeSpans -', () {
      test('returns empty map for empty input', () async {
        final result = await db!.getBulkLinkedTimeSpans({});
        expect(result, isEmpty);
      });

      test('returns time spans for parent with linked journal entry', () async {
        final base = DateTime(2024, 8, 2);
        final parent = buildTaskEntry(
          id: 'ts-parent',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-1',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final child = buildJournalEntry(
          id: 'ts-child',
          timestamp: base.add(const Duration(hours: 1)),
          text: 'Time tracking entry',
        );

        await db!.upsertJournalDbEntity(toDbEntity(parent));
        await db!.upsertJournalDbEntity(toDbEntity(child));

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-1',
            fromId: parent.meta.id,
            toId: child.meta.id,
            timestamp: base,
          ),
        );

        final result = await db!.getBulkLinkedTimeSpans({'ts-parent'});
        expect(result, hasLength(1));
        expect(result['ts-parent'], hasLength(1));
        expect(result['ts-parent']!.first.id, 'ts-child');
        expect(
          result['ts-parent']!.first.dateFrom,
          base.add(const Duration(hours: 1)),
        );
        expect(
          result['ts-parent']!.first.dateTo,
          base.add(const Duration(hours: 1)),
        );
      });

      test('excludes tasks linked to parent', () async {
        final base = DateTime(2024, 8, 2);
        final parent = buildTaskEntry(
          id: 'ts-parent-excl',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-2',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final linkedTask = buildTaskEntry(
          id: 'ts-linked-task',
          timestamp: base.add(const Duration(hours: 1)),
          status: TaskStatus.open(
            id: 'ts-status-3',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final linkedEntry = buildJournalEntry(
          id: 'ts-linked-entry',
          timestamp: base.add(const Duration(hours: 2)),
          text: 'Regular entry',
        );

        await db!.upsertJournalDbEntity(toDbEntity(parent));
        await db!.upsertJournalDbEntity(toDbEntity(linkedTask));
        await db!.upsertJournalDbEntity(toDbEntity(linkedEntry));

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-task',
            fromId: parent.meta.id,
            toId: linkedTask.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-entry',
            fromId: parent.meta.id,
            toId: linkedEntry.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );

        final result = await db!.getBulkLinkedTimeSpans({'ts-parent-excl'});
        expect(result['ts-parent-excl'], hasLength(1));
        expect(result['ts-parent-excl']!.first.id, 'ts-linked-entry');
      });

      test('groups results by multiple parents', () async {
        final base = DateTime(2024, 8, 2);
        final parentA = buildTaskEntry(
          id: 'ts-multi-parent-a',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-4',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final parentB = buildTaskEntry(
          id: 'ts-multi-parent-b',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-5',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final childA = buildJournalEntry(
          id: 'ts-child-a',
          timestamp: base.add(const Duration(hours: 1)),
          text: 'Child of A',
        );
        final childB1 = buildJournalEntry(
          id: 'ts-child-b1',
          timestamp: base.add(const Duration(hours: 2)),
          text: 'First child of B',
        );
        final childB2 = buildJournalEntry(
          id: 'ts-child-b2',
          timestamp: base.add(const Duration(hours: 3)),
          text: 'Second child of B',
        );

        for (final entry in [parentA, parentB, childA, childB1, childB2]) {
          await db!.upsertJournalDbEntity(toDbEntity(entry));
        }

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-multi-a',
            fromId: parentA.meta.id,
            toId: childA.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-multi-b1',
            fromId: parentB.meta.id,
            toId: childB1.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-multi-b2',
            fromId: parentB.meta.id,
            toId: childB2.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );

        final result = await db!.getBulkLinkedTimeSpans({
          'ts-multi-parent-a',
          'ts-multi-parent-b',
        });
        expect(result['ts-multi-parent-a'], hasLength(1));
        expect(result['ts-multi-parent-a']!.first.id, 'ts-child-a');
        expect(result['ts-multi-parent-b'], hasLength(2));
        expect(
          result['ts-multi-parent-b']!.map((e) => e.id).toSet(),
          {'ts-child-b1', 'ts-child-b2'},
        );
      });

      test('respects private flag when private is disabled', () async {
        final base = DateTime(2024, 8, 2);
        final parent = buildTaskEntry(
          id: 'ts-priv-parent',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-6',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final publicChild = buildJournalEntry(
          id: 'ts-public-child',
          timestamp: base.add(const Duration(hours: 1)),
          text: 'Public child',
        );
        final privateChild = buildJournalEntry(
          id: 'ts-private-child',
          timestamp: base.add(const Duration(hours: 2)),
          text: 'Private child',
          privateFlag: true,
        );

        await db!.upsertJournalDbEntity(toDbEntity(parent));
        await db!.upsertJournalDbEntity(toDbEntity(publicChild));
        await db!.upsertJournalDbEntity(toDbEntity(privateChild));

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-pub',
            fromId: parent.meta.id,
            toId: publicChild.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-priv',
            fromId: parent.meta.id,
            toId: privateChild.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );

        // Disable private flag
        final privateCfg = await db!.getConfigFlagByName(privateFlag);
        await db!.upsertConfigFlag(privateCfg!.copyWith(status: false));

        final result = await db!.getBulkLinkedTimeSpans({'ts-priv-parent'});
        expect(result['ts-priv-parent'], hasLength(1));
        expect(result['ts-priv-parent']!.first.id, 'ts-public-child');

        // Re-enable private flag to see both
        await db!.upsertConfigFlag(privateCfg.copyWith(status: true));

        final resultWithPrivate = await db!.getBulkLinkedTimeSpans({
          'ts-priv-parent',
        });
        expect(resultWithPrivate['ts-priv-parent'], hasLength(2));
      });
    });
  });
}
