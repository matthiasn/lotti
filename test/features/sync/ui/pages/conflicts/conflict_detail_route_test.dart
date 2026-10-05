import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

const _conflictId = 'conflict-aaa';
final _baseTime = DateTime(2024, 3, 15, 12, 50, 14);

JournalEntity _entry({
  required String title,
  required Map<String, int> clock,
  String? categoryId,
  String id = _conflictId,
}) {
  return JournalEntry(
    meta: Metadata(
      id: id,
      createdAt: _baseTime,
      updatedAt: _baseTime,
      dateFrom: _baseTime,
      dateTo: _baseTime.add(const Duration(seconds: 42)),
      categoryId: categoryId,
      vectorClock: VectorClock(Map.unmodifiable(clock)),
    ),
    entryText: EntryText(plainText: title),
  );
}

Conflict _conflict({
  required JournalEntity remote,
  String id = _conflictId,
  String versionKey = '',
  DateTime? createdAt,
  ConflictStatus status = ConflictStatus.unresolved,
}) {
  return Conflict(
    id: id,
    versionKey: versionKey,
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
    required this.controller,
    required this.settingsDelegate,
  });

  final MockJournalDb db;
  final MockPersistenceLogic persistence;

  /// The settings tab's navigator, which a resolved conflict beams back.
  final MockBeamerDelegate settingsDelegate;
  final StreamController<List<Conflict>> controller;

  static Future<_Bench> create({
    required JournalEntity localEntry,
    required Conflict conflict,
  }) async {
    final persistence = MockPersistenceLogic();
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    final settingsDelegate = MockBeamerDelegate();
    when(settingsDelegate.beamBack).thenReturn(true);
    final navService = MockNavService();
    when(() => navService.settingsDelegate).thenReturn(settingsDelegate);
    when(
      () => persistence.updateJournalEntity(
        any(),
        any(),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((_) async => true);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(persistence)
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<NavService>(navService);
      },
    );

    final db = getIt<JournalDb>() as MockJournalDb;
    final controller = StreamController<List<Conflict>>.broadcast();
    when(
      () => db.watchConflictById(conflict.id),
    ).thenAnswer((_) => controller.stream);
    when(
      () => db.journalEntityByIdIncludingDeleted(conflict.id),
    ).thenAnswer((_) async => localEntry);

    return _Bench._(
      db: db,
      persistence: persistence,
      controller: controller,
      settingsDelegate: settingsDelegate,
    );
  }

  Future<void> dispose() async {
    await controller.close();
    await tearDownTestGetIt();
  }
}

const _size = Size(1200, 900);

Future<void> _pump(
  WidgetTester tester,
  String conflictId, {
  String? versionKey,
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(_size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      ConflictDetailRoute(conflictId: conflictId, versionKey: versionKey),
      mediaQueryData: const MediaQueryData(size: _size),
      overrides: overrides,
    ),
  );
}

/// Pumps the route, emits the conflict, and settles the entrance animation.
Future<void> _showConflict(
  WidgetTester tester,
  _Bench bench,
  Conflict c, {
  List<Override> overrides = const [],
}) async {
  await _pump(tester, c.id, overrides: overrides);
  bench.controller.add([c]);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(DesignSystemButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String _firstLineOf(JournalEntity e) {
  final t = e.entryText?.plainText.trim() ?? '';
  return t.isEmpty ? '' : t.split('\n').first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);
  final l10n = AppLocalizationsEn();

  group('loading + error scaffolds', () {
    testWidgets('loading scaffold renders before the first stream tick', (
      tester,
    ) async {
      final local = _entry(title: 'note', clock: const {'a': 9});
      final conflict = _conflict(remote: local);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _pump(tester, conflict.id);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('not-found scaffold appears once the stream emits []', (
      tester,
    ) async {
      final local = _entry(title: 'note', clock: const {'a': 1});
      final conflict = _conflict(remote: local);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _pump(tester, conflict.id);
      bench.controller.add(const <Conflict>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.conflictDetailNotFoundTitle), findsOneWidget);
    });

    testWidgets('error scaffold surfaces the stream error', (tester) async {
      final local = _entry(title: 'note', clock: const {'a': 1});
      final conflict = _conflict(remote: local);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _pump(tester, conflict.id);
      bench.controller.addError(StateError('boom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.conflictDetailLoadErrorTitle), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('entry-not-found scaffold when local lookup yields null', (
      tester,
    ) async {
      final local = _entry(title: 'remote', clock: const {'a': 1});
      final conflict = _conflict(remote: local);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      when(
        () => bench.db.journalEntityByIdIncludingDeleted(conflict.id),
      ).thenAnswer((_) async => null);
      await _pump(tester, conflict.id);
      bench.controller.add([conflict]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictDetailEntryNotFoundTitle), findsOneWidget);
    });

    testWidgets('error scaffold when the local future throws', (tester) async {
      final remote = _entry(title: 'remote', clock: const {'a': 1});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: remote, conflict: conflict);
      addTearDown(bench.dispose);
      when(
        () => bench.db.journalEntityByIdIncludingDeleted(conflict.id),
      ).thenAnswer((_) => Future.error(StateError('db gone')));
      await _pump(tester, conflict.id);
      bench.controller.add([conflict]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.conflictDetailLoadErrorTitle), findsOneWidget);
      expect(find.textContaining('db gone'), findsOneWidget);
    });
  });

  group('resolution', () {
    testWidgets('renders the page title and the resolution actions', (
      tester,
    ) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      expect(find.text(l10n.conflictPageTitle), findsOneWidget);
      expect(find.text(l10n.conflictPickerUseThisDevice), findsOneWidget);
      expect(find.text(l10n.conflictPickerUseFromSync), findsOneWidget);
      // The body field diverged, so the diff view shows the Body row.
      expect(find.text(l10n.conflictFieldBody), findsOneWidget);
    });

    testWidgets('Use this device writes the local side', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      await _tap(tester, l10n.conflictPickerUseThisDevice);

      final captured = verify(
        () => bench.persistence.updateJournalEntity(
          captureAny(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).captured;
      expect(_firstLineOf(captured.single as JournalEntity), 'Local title');
      // Resolved, so the settings tab goes back to the conflict list.
      verify(bench.settingsDelegate.beamBack).called(1);
    });

    testWidgets(
      'a checklist conflict is resolved through the checklist repository',
      (tester) async {
        Checklist checklistOf(String title, Map<String, int> clock) =>
            Checklist(
              meta: Metadata(
                id: _conflictId,
                createdAt: _baseTime,
                updatedAt: _baseTime,
                dateFrom: _baseTime,
                dateTo: _baseTime,
                vectorClock: VectorClock(clock),
              ),
              data: ChecklistData(
                title: title,
                linkedChecklistItems: const [],
                linkedTasks: const ['task-1'],
              ),
            );
        final local = checklistOf('Local list', const {'a': 9});
        final conflict = _conflict(
          remote: checklistOf('Remote list', const {'a': 13}),
        );
        final bench = await _Bench.create(
          localEntry: local,
          conflict: conflict,
        );
        addTearDown(bench.dispose);
        final checklists = MockChecklistRepository();
        when(
          () => checklists.resolveConflict(any(), any()),
        ).thenAnswer((_) async => true);

        await _showConflict(
          tester,
          bench,
          conflict,
          overrides: [
            checklistRepositoryProvider.overrideWithValue(checklists),
          ],
        );
        await _tap(tester, l10n.conflictPickerUseThisDevice);

        final resolved =
            verify(
                  () => checklists.resolveConflict(captureAny(), any()),
                ).captured.single
                as Checklist;
        expect(resolved.data.title, 'Local list');
      },
    );

    testWidgets('Use from sync writes the remote side', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      await _tap(tester, l10n.conflictPickerUseFromSync);

      final captured = verify(
        () => bench.persistence.updateJournalEntity(
          captureAny(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).captured;
      expect(_firstLineOf(captured.single as JournalEntity), 'Remote title');
    });

    testWidgets('Combine applies a merged entity', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      await tester.tap(
        find.widgetWithIcon(DesignSystemButton, LottiIcons.merge),
      );
      await tester.pump();
      await _tap(tester, l10n.conflictCombineApply);

      // Default combine starts from local, so the merged body is the local one.
      final captured = verify(
        () => bench.persistence.updateJournalEntity(
          captureAny(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).captured;
      expect(_firstLineOf(captured.single as JournalEntity), 'Local title');
    });

    testWidgets('apply failure surfaces an error toast', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      when(
        () => bench.persistence.updateJournalEntity(
          any(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) => Future.error(Exception('network failure')));
      await _showConflict(tester, bench, conflict);

      await _tap(tester, l10n.conflictPickerUseThisDevice);

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.error);
      expect(toast.title, l10n.conflictApplyFailedTitle);
      expect(toast.description, contains('network failure'));
    });

    testWidgets('a non-applied write surfaces an error toast', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      when(
        () => bench.persistence.updateJournalEntity(
          any(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => false);
      await _showConflict(tester, bench, conflict);

      await _tap(tester, l10n.conflictPickerUseThisDevice);

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.error);
      expect(toast.title, l10n.conflictApplyFailedTitle);
    });

    // The resolution applies only over the local side shown
    // (`specs/tla/TaskFieldWrites.tla`, ResolveOnStored): refused because
    // this device stored another version since the page read it, the page
    // reads it again and shows the difference as it now is.
    testWidgets('a resolution refused because this device stored another '
        'version meanwhile shows the difference again', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final since = _entry(title: 'Edited since', clock: const {'a': 10});
      final remote = _entry(title: 'Remote title', clock: const {'b': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      when(
        () => bench.persistence.updateJournalEntity(
          any(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async {
        when(
          () => bench.db.journalEntityByIdIncludingDeleted(conflict.id),
        ).thenAnswer((_) async => since);
        return false;
      });
      await _showConflict(tester, bench, conflict);
      expect(find.textContaining('Edited since'), findsNothing);

      final button = find.widgetWithText(
        DesignSystemButton,
        l10n.conflictPickerUseThisDevice,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      // Frame by frame: the established diff stays on screen while the side
      // is read again — never the full-page loading scaffold.
      var sawLoading = false;
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
          sawLoading = true;
        }
      }
      expect(sawLoading, isFalse, reason: 'a background re-read flashed');
      await tester.pumpAndSettle();

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.warning);
      expect(toast.title, l10n.conflictEntryChangedTitle);
      expect(find.textContaining('Edited since'), findsWidgets);
      expect(find.textContaining('Local title'), findsNothing);
    });

    // ADR 0083: an edit that arrives after this device deleted the entry is
    // a conflict, and the page must open on the deleted local side.
    testWidgets('opens a deletion made here against an edit from sync', (
      tester,
    ) async {
      final live = _entry(title: 'Local title', clock: const {'a': 9});
      final deletedHere = live.copyWith(
        meta: live.meta.copyWith(deletedAt: _baseTime),
      );
      final remote = _entry(title: 'Edited there', clock: const {'b': 1});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(
        localEntry: deletedHere,
        conflict: conflict,
      );
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      expect(find.text(l10n.conflictDeleteVsEditTitle), findsOneWidget);
      await _tap(tester, l10n.conflictKeepEdited);

      final captured = verify(
        () => bench.persistence.updateJournalEntity(
          captureAny(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).captured;
      final written = captured.single as JournalEntity;
      expect(_firstLineOf(written), 'Edited there');
      expect(written.meta.deletedAt, isNull);
    });

    testWidgets('the local entry is read once and reused across ticks', (
      tester,
    ) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      verify(
        () => bench.db.journalEntityByIdIncludingDeleted(conflict.id),
      ).called(1);
      bench.controller.add([conflict]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(
        () => bench.db.journalEntityByIdIncludingDeleted(conflict.id),
      );
    });
  });

  // An entry can hold several concurrent versions, one row each (ADR 0092).
  group('several concurrent versions', () {
    final local = _entry(title: 'Local title', clock: const {'a': 2});
    final older = _conflict(
      remote: _entry(title: 'From B', clock: const {'a': 1, 'b': 1}),
      versionKey: 'a:1,b:1',
    );
    final newer = _conflict(
      remote: _entry(title: 'From C', clock: const {'a': 1, 'c': 1}),
      versionKey: 'a:1,c:1',
      createdAt: _baseTime.add(const Duration(minutes: 1)),
    );

    Future<String> keptFromSync(WidgetTester tester, String? versionKey) async {
      final bench = await _Bench.create(localEntry: local, conflict: older);
      addTearDown(bench.dispose);
      await _pump(tester, older.id, versionKey: versionKey);
      bench.controller.add([newer, older]);
      await tester.pumpAndSettle();
      await _tap(tester, l10n.conflictPickerUseFromSync);
      final captured = verify(
        () => bench.persistence.updateJournalEntity(
          captureAny(),
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).captured;
      return _firstLineOf(captured.single as JournalEntity);
    }

    testWidgets('the version the list row named is the one decided', (
      tester,
    ) async {
      expect(await keptFromSync(tester, 'a:1,c:1'), 'From C');
    });

    testWidgets('without a version, the oldest open one comes first', (
      tester,
    ) async {
      expect(await keptFromSync(tester, null), 'From B');
    });

    testWidgets(
      'when the version shown is resolved elsewhere, the next one is decided '
      'against the row that resolution wrote, not the row before',
      (tester) async {
        final bench = await _Bench.create(localEntry: local, conflict: older);
        addTearDown(bench.dispose);
        await _pump(tester, older.id);
        bench.controller.add([newer, older]);
        await tester.pumpAndSettle();

        // Sync settles B's version: the local row is now the merge of the
        // row and B, and C's version is the one still open.
        final merged = _entry(
          title: 'Local + B',
          clock: const {'a': 3, 'b': 1},
        );
        when(
          () => bench.db.journalEntityByIdIncludingDeleted(older.id),
        ).thenAnswer((_) async => merged);
        bench.controller.add([
          newer,
          older.copyWith(status: ConflictStatus.resolved.index),
        ]);
        await tester.pumpAndSettle();

        await _tap(tester, l10n.conflictPickerUseThisDevice);
        final written =
            verify(
                  () => bench.persistence.updateJournalEntity(
                    captureAny(),
                    any(),
                    precondition: any(named: 'precondition'),
                  ),
                ).captured.single
                as JournalEntity;
        expect(_firstLineOf(written), 'Local + B');
        // The merge covers the new row and C, so it settles C as well.
        expect(
          written.meta.vectorClock,
          const VectorClock({'a': 3, 'b': 1, 'c': 1}),
        );
      },
    );

    test('pickConflictVersion falls back to the oldest unresolved row once '
        'the named one is resolved, and to the newest when none is open', () {
      final resolvedNewer = _conflict(
        remote: _entry(title: 'From C', clock: const {'a': 1, 'c': 1}),
        versionKey: 'a:1,c:1',
        createdAt: _baseTime.add(const Duration(minutes: 1)),
        status: ConflictStatus.resolved,
      );
      final resolvedOlder = _conflict(
        remote: _entry(title: 'From B', clock: const {'a': 1, 'b': 1}),
        versionKey: 'a:1,b:1',
        status: ConflictStatus.resolved,
      );

      expect(pickConflictVersion([resolvedNewer, older], 'a:1,c:1'), older);
      expect(
        pickConflictVersion([resolvedNewer, resolvedOlder], 'a:1,b:1'),
        resolvedNewer,
      );
    });
  });
}
