import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
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

Conflict _conflict({required JournalEntity remote, String id = _conflictId}) {
  return Conflict(
    id: id,
    createdAt: _baseTime,
    updatedAt: _baseTime,
    serialized: jsonEncode(remote.toJson()),
    schemaVersion: 1,
    status: ConflictStatus.unresolved.index,
  );
}

class _Bench {
  _Bench._({
    required this.db,
    required this.persistence,
    required this.controller,
  });

  final MockJournalDb db;
  final MockPersistenceLogic persistence;
  final StreamController<List<Conflict>> controller;

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

    return _Bench._(db: db, persistence: persistence, controller: controller);
  }

  Future<void> dispose() async {
    await controller.close();
    await tearDownTestGetIt();
  }
}

const _size = Size(1200, 900);

Future<void> _pump(WidgetTester tester, String conflictId) async {
  await tester.binding.setSurfaceSize(_size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      ConflictDetailRoute(conflictId: conflictId),
      mediaQueryData: const MediaQueryData(size: _size),
    ),
  );
}

/// Pumps the route, emits the conflict, and settles the entrance animation.
Future<void> _showConflict(
  WidgetTester tester,
  _Bench bench,
  Conflict c,
) async {
  await _pump(tester, c.id);
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
        () => bench.db.journalEntityById(conflict.id),
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
        () => bench.db.journalEntityById(conflict.id),
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
        () => bench.persistence.updateJournalEntity(captureAny(), any()),
      ).captured;
      expect(_firstLineOf(captured.single as JournalEntity), 'Local title');
    });

    testWidgets('Use from sync writes the remote side', (tester) async {
      final local = _entry(title: 'Local title', clock: const {'a': 9});
      final remote = _entry(title: 'Remote title', clock: const {'a': 13});
      final conflict = _conflict(remote: remote);
      final bench = await _Bench.create(localEntry: local, conflict: conflict);
      addTearDown(bench.dispose);
      await _showConflict(tester, bench, conflict);

      await _tap(tester, l10n.conflictPickerUseFromSync);

      final captured = verify(
        () => bench.persistence.updateJournalEntity(captureAny(), any()),
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
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
      );
      await tester.pump();
      await _tap(tester, l10n.conflictCombineApply);

      // Default combine starts from local, so the merged body is the local one.
      final captured = verify(
        () => bench.persistence.updateJournalEntity(captureAny(), any()),
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
        () => bench.persistence.updateJournalEntity(any(), any()),
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
        () => bench.persistence.updateJournalEntity(any(), any()),
      ).thenAnswer((_) async => false);
      await _showConflict(tester, bench, conflict);

      await _tap(tester, l10n.conflictPickerUseThisDevice);

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.error);
      expect(toast.title, l10n.conflictApplyFailedTitle);
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

      verify(() => bench.db.journalEntityById(conflict.id)).called(1);
      bench.controller.add([conflict]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(() => bench.db.journalEntityById(conflict.id));
    });
  });
}
