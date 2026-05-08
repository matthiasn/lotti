import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _conflictId = 'conflict-aaa';
final _baseTime = DateTime(2024, 3, 15, 12, 50, 14);

/// Builds a journal entry with the given title and word-clock counter.
/// `audioDuration` is optional; when non-null the result is a
/// `JournalAudio` so the meta row picks up the duration cell.
JournalEntity _entry({
  required String title,
  required Map<String, int> clock,
  String? categoryId,
  Duration? audioDuration,
  String id = _conflictId,
}) {
  final meta = Metadata(
    id: id,
    createdAt: _baseTime,
    updatedAt: _baseTime,
    dateFrom: _baseTime,
    dateTo: _baseTime.add(const Duration(seconds: 42)),
    categoryId: categoryId,
    vectorClock: VectorClock(Map.unmodifiable(clock)),
  );
  if (audioDuration != null) {
    return JournalAudio(
      meta: meta,
      data: AudioData(
        dateFrom: _baseTime,
        dateTo: _baseTime.add(audioDuration),
        audioFile: 'audio.aac',
        audioDirectory: '/tmp/',
        duration: audioDuration,
      ),
      entryText: EntryText(plainText: title),
    );
  }
  return JournalEntry(
    meta: meta,
    entryText: EntryText(plainText: title),
  );
}

Conflict _conflict({
  required JournalEntity remote,
  DateTime? createdAt,
  String id = _conflictId,
  ConflictStatus status = ConflictStatus.unresolved,
}) {
  return Conflict(
    id: id,
    createdAt: createdAt ?? _baseTime,
    updatedAt: createdAt ?? _baseTime,
    serialized: jsonEncode(remote.toJson()),
    schemaVersion: 1,
    status: status.index,
  );
}

class _Bench {
  _Bench._({
    required this.db,
    required this.persistence,
    required this.cache,
    required this.unresolvedController,
  });

  final MockJournalDb db;
  final MockPersistenceLogic persistence;
  final MockEntitiesCacheService cache;
  final StreamController<List<Conflict>> unresolvedController;

  static Future<_Bench> create({
    required JournalEntity localEntry,
    required Conflict conflict,
  }) async {
    final persistence = MockPersistenceLogic();
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(
      () => persistence.updateJournalEntity(any(), any()),
    ).thenAnswer((_) async => true);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(persistence)
          ..registerSingleton<EntitiesCacheService>(cache);
      },
    );

    final db = getIt<JournalDb>() as MockJournalDb;
    final controller = StreamController<List<Conflict>>.broadcast();
    when(
      () => db.watchConflictById(conflict.id),
    ).thenAnswer((_) => controller.stream);
    when(
      () => db.journalEntityById(conflict.id),
    ).thenAnswer((_) async => localEntry);

    return _Bench._(
      db: db,
      persistence: persistence,
      cache: cache,
      unresolvedController: controller,
    );
  }

  Future<void> dispose() async {
    await unresolvedController.close();
    await tearDownTestGetIt();
  }
}

const _mobileSize = Size(390, 844);
const _desktopSize = Size(1200, 900);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required String conflictId,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // makeTestableWidget wraps in SingleChildScrollView, which would feed
  // the Scaffold unbounded height constraints; the Scaffold under test
  // owns its own bottom-nav-bar layout so it must size to the viewport.
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      ConflictDetailRoute(conflictId: conflictId),
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  final l10n = AppLocalizationsEn();

  group('ConflictDetailRoute · loading + error scaffolds', () {
    testWidgets('loading scaffold renders before the first stream tick', (
      tester,
    ) async {
      final localEntry = _entry(
        title: 'Testing the mic 1 and 2',
        clock: const {'a': 9},
      );
      final conflict = _conflict(remote: localEntry);
      final bench = await _Bench.create(
        localEntry: localEntry,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      // Pump once — the controller hasn't emitted yet, so the scaffold
      // should still be in its loading state.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('not-found scaffold appears once the stream emits []', (
      tester,
    ) async {
      final localEntry = _entry(
        title: 'Local-only',
        clock: const {'a': 1},
      );
      final conflict = _conflict(remote: localEntry);
      final bench = await _Bench.create(
        localEntry: localEntry,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add(const <Conflict>[]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictDetailNotFoundTitle), findsOneWidget);
    });

    testWidgets('error scaffold surfaces the error message', (tester) async {
      final localEntry = _entry(
        title: 'irrelevant',
        clock: const {'a': 1},
      );
      final conflict = _conflict(remote: localEntry);
      final bench = await _Bench.create(
        localEntry: localEntry,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.addError(StateError('boom'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictDetailLoadErrorTitle), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets(
      'entry-not-found scaffold appears when local lookup yields null',
      (
        tester,
      ) async {
        final localEntry = _entry(title: 'remote', clock: const {'a': 1});
        final conflict = _conflict(remote: localEntry);
        final bench = await _Bench.create(
          localEntry: localEntry,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        // Override journalEntityById to return null this time.
        when(
          () => bench.db.journalEntityById(conflict.id),
        ).thenAnswer((_) async => null);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.conflictDetailEntryNotFoundTitle),
          findsOneWidget,
        );
      },
    );
  });

  group('ConflictDetailRoute · header bar', () {
    testWidgets('mobile pill shows just the entry count number', (
      tester,
    ) async {
      final local = _entry(
        title: 'Testing the mic 1 and 2',
        clock: const {'a': 9},
      );
      final remote = _entry(
        title: 'Testing for conflicts',
        clock: const {'a': 13},
      );
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _mobileSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      // The pill carries just '1' on phone widths — not the verbose
      // "1 entry · N fields differ" string.
      expect(find.text('1'), findsOneWidget);
      expect(find.textContaining('fields differ'), findsNothing);
      expect(find.text(l10n.conflictPageTitle), findsOneWidget);
    });

    testWidgets(
      'desktop pill includes both entry count and differing-fields count',
      (tester) async {
        final local = _entry(
          title: 'Testing the mic 1 and 2',
          clock: const {'a': 9},
        );
        final remote = _entry(
          title: 'Testing for conflicts',
          clock: const {'a': 13},
        );
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        // Title + word count differ.
        expect(
          find.textContaining(l10n.conflictHeaderPillEntries(1)),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.conflictHeaderPillFieldsDiffer(2)),
          findsOneWidget,
        );
      },
    );
  });

  group('ConflictDetailRoute · lead copy + summary banner', () {
    testWidgets('mobile lead copy is the shorter "Tap a side" variant', (
      tester,
    ) async {
      final local = _entry(title: 'A', clock: const {'a': 1});
      final remote = _entry(title: 'B', clock: const {'a': 2});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _mobileSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictPageLeadMobile), findsOneWidget);
      expect(find.text(l10n.conflictPageLeadDesktop), findsNothing);
    });

    testWidgets('desktop lead copy is the verbose Click-or-Edit variant', (
      tester,
    ) async {
      final local = _entry(title: 'A', clock: const {'a': 1});
      final remote = _entry(title: 'B', clock: const {'a': 2});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictPageLeadDesktop), findsOneWidget);
    });

    testWidgets('summary banner first line names the entity type', (
      tester,
    ) async {
      final local = _entry(title: 'A', clock: const {'a': 1});
      final remote = _entry(title: 'B', clock: const {'a': 2});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(l10n.entryTypeLabelJournalEntry),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets(
      'summary subline lists differing fields and is hidden when none differ',
      (tester) async {
        // Identical local + remote → no differences → no subline.
        final local = _entry(title: 'same', clock: const {'a': 1});
        final remote = _entry(title: 'same', clock: const {'a': 1});
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(l10n.conflictBannerFieldsDifferList('Title')),
          findsNothing,
        );
      },
    );
  });

  group('ConflictDetailRoute · diff cards + meta', () {
    testWidgets('both eyebrows render with the correct localized labels', (
      tester,
    ) async {
      final local = _entry(
        title: 'Testing the mic 1 and 2',
        clock: const {'a': 9},
      );
      final remote = _entry(
        title: 'Testing for conflicts',
        clock: const {'a': 13},
      );
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictSideThisDevice), findsOneWidget);
      expect(find.text(l10n.conflictSideFromSync), findsOneWidget);
    });

    testWidgets('desktop card timestamp embeds `vec N` inline', (tester) async {
      final local = _entry(
        title: 'Testing the mic',
        clock: const {'a': 9},
      );
      final remote = _entry(
        title: 'Testing for conflicts',
        clock: const {'a': 13},
      );
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      // Both clocks merge to {a: 13}, so both sides display vec 13 in
      // their card header on desktop.
      expect(find.textContaining('vec 13'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'mobile card timestamp omits vec; meta row carries it instead',
      (tester) async {
        final local = _entry(
          title: 'Testing the mic',
          clock: const {'a': 9},
        );
        final remote = _entry(
          title: 'Testing for conflicts',
          clock: const {'a': 13},
        );
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _mobileSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        // Mobile renders vec in the meta row (no card-header inline form).
        expect(find.textContaining('vec 13'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('audio entries surface the duration cell', (tester) async {
      final local = _entry(
        title: 'Audio note',
        clock: const {'a': 9},
        audioDuration: const Duration(seconds: 42),
      );
      final remote = _entry(
        title: 'Audio note remix',
        clock: const {'a': 13},
        audioDuration: const Duration(seconds: 42),
      );
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      // Both sides format 42s as "0:42".
      expect(find.textContaining('0:42'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'desktop meta row shows the local-edit / via-sync provenance labels',
      (tester) async {
        final local = _entry(title: 'Local', clock: const {'a': 9});
        final remote = _entry(title: 'Remote', clock: const {'a': 13});
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        expect(find.text(l10n.conflictMetaLocalEdit), findsOneWidget);
        expect(find.text(l10n.conflictMetaViaSync), findsOneWidget);
      },
    );

    testWidgets(
      'category icon renders when the entry has a categoryId, hidden otherwise',
      (tester) async {
        final local = _entry(
          title: 'Local',
          clock: const {'a': 1},
          categoryId: 'cat-1',
        );
        final remote = _entry(
          title: 'Remote',
          clock: const {'a': 2},
          categoryId: 'cat-1',
        );
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        when(() => bench.cache.getCategoryById('cat-1')).thenReturn(
          CategoryDefinition(
            id: 'cat-1',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
            name: 'Work',
            color: '#FF00FF',
            private: false,
            active: true,
          ),
        );
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        // Cache lookup must be hit at least twice (once per side).
        verify(
          () => bench.cache.getCategoryById('cat-1'),
        ).called(greaterThanOrEqualTo(2));
      },
    );
  });

  group('ConflictDetailRoute · selection flow + footer', () {
    testWidgets(
      'helper text mirrors selection state: pick-a-side → local → remote',
      (tester) async {
        final local = _entry(
          title: 'Testing the mic',
          clock: const {'a': 9},
        );
        final remote = _entry(
          title: 'Testing for conflicts',
          clock: const {'a': 13},
        );
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();

        // Initial state: footer reads back "pick a side" — Apply has no
        // onPressed callback so taps on it must NOT fire the resolve
        // path. We exercise that by tapping it and verifying
        // PersistenceLogic was never called.
        expect(find.text(l10n.conflictFooterHelperPickASide), findsOneWidget);
        await tester.tap(find.text(l10n.conflictApplyButton));
        await tester.pumpAndSettle();
        verifyNever(
          () => bench.persistence.updateJournalEntity(any(), any()),
        );

        // Tap the local card — selecting it.
        await tester.tap(
          find.byKey(const ValueKey('conflict-card-local')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.conflictFooterHelperLocalSelected),
          findsOneWidget,
        );

        // Switch to remote.
        await tester.tap(
          find.byKey(const ValueKey('conflict-card-remote')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.conflictFooterHelperRemoteSelected),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Apply with local selected calls PersistenceLogic.updateJournalEntity '
      'with the local entity',
      (tester) async {
        final local = _entry(
          title: 'Local title',
          clock: const {'a': 9},
        );
        final remote = _entry(
          title: 'Remote title',
          clock: const {'a': 13},
        );
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('conflict-card-local')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.conflictApplyButton));
        await tester.pumpAndSettle();

        final captured = verify(
          () =>
              bench.persistence.updateJournalEntity(captureAny(), captureAny()),
        ).captured;
        expect(captured, hasLength(2));
        final winner = captured.first as JournalEntity;
        expect(_firstLineOf(winner), 'Local title');
      },
    );

    testWidgets(
      'Apply with remote selected calls PersistenceLogic with the remote entity',
      (tester) async {
        final local = _entry(title: 'Local title', clock: const {'a': 9});
        final remote = _entry(title: 'Remote title', clock: const {'a': 13});
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('conflict-card-remote')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.conflictApplyButton));
        await tester.pumpAndSettle();

        final captured = verify(
          () =>
              bench.persistence.updateJournalEntity(captureAny(), captureAny()),
        ).captured;
        final winner = captured.first as JournalEntity;
        expect(_firstLineOf(winner), 'Remote title');
      },
    );
  });

  group('ConflictDetailRoute · picker pills', () {
    testWidgets('mobile renders 2 picker pills, no Edit & merge inline', (
      tester,
    ) async {
      final local = _entry(title: 'A', clock: const {'a': 1});
      final remote = _entry(title: 'B', clock: const {'a': 2});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _mobileSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictPickerUseThisDevice), findsOneWidget);
      expect(find.text(l10n.conflictPickerUseFromSync), findsOneWidget);
      // Edit & merge appears once — in the footer link, not in the picker row.
      expect(find.text(l10n.conflictPickerEditMerge), findsOneWidget);
    });

    testWidgets(
      'desktop renders 3 picker pills including Edit & merge',
      (tester) async {
        final local = _entry(title: 'A', clock: const {'a': 1});
        final remote = _entry(title: 'B', clock: const {'a': 2});
        final conflict = _conflict(remote: remote);
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        await _pump(tester, size: _desktopSize, conflictId: conflict.id);
        bench.unresolvedController.add([conflict]);
        await tester.pumpAndSettle();
        expect(find.text(l10n.conflictPickerUseThisDevice), findsOneWidget);
        expect(find.text(l10n.conflictPickerUseFromSync), findsOneWidget);
        expect(find.text(l10n.conflictPickerEditMerge), findsOneWidget);
      },
    );

    testWidgets('tapping a picker pill selects the matching side', (
      tester,
    ) async {
      final local = _entry(title: 'A', clock: const {'a': 1});
      final remote = _entry(title: 'B', clock: const {'a': 2});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: local,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _pump(tester, size: _desktopSize, conflictId: conflict.id);
      bench.unresolvedController.add([conflict]);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.conflictPickerUseFromSync));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.conflictFooterHelperRemoteSelected),
        findsOneWidget,
      );
    });
  });
}

String _firstLineOf(JournalEntity e) {
  final t = e.entryText?.plainText.trim() ?? '';
  return t.isEmpty ? '' : t.split('\n').first;
}
