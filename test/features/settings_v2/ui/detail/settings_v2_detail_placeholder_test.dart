import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/settings_v2_detail_placeholder.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

typedef _Bench = ({
  MockPersistenceLogic persistence,
  MockJournalDb journalDb,
});

/// Single-shot test bench: registers a fresh persistence mock + stubs
/// `getConfigFlagByName` on the journal-db mock that
/// `setUpTestGetIt()` already hands us. Callers must tear down via
/// `tearDownTestGetIt()` — the helper schedules that via
/// [addTearDown] so tests don't have to.
Future<_Bench> _pumpPlaceholder(
  WidgetTester tester, {
  List<String> initialPath = const [],
  ConfigFlag? existingFlag,
}) async {
  final mocks = await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  final persistence = MockPersistenceLogic();
  when(() => persistence.setConfigFlag(any())).thenAnswer((_) async {});
  when(() => mocks.journalDb.getConfigFlagByName(any())).thenAnswer(
    (_) async => existingFlag,
  );
  getIt.registerSingleton<PersistenceLogic>(persistence);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Material(
        child: SizedBox(
          width: 500,
          height: 500,
          child: SettingsV2DetailPlaceholder(),
        ),
      ),
      overrides: [
        settingsTreePathProvider.overrideWith(
          () => _SeededTreePath(initialPath),
        ),
      ],
    ),
  );
  await tester.pump();
  return (persistence: persistence, journalDb: mocks.journalDb);
}

class _SeededTreePath extends SettingsTreePath {
  _SeededTreePath(this._seed);

  final List<String> _seed;

  @override
  List<String> build() => _seed;
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('SettingsV2DetailPlaceholder — empty state', () {
    testWidgets('shows the "pick a section" copy when the path is empty', (
      tester,
    ) async {
      await _pumpPlaceholder(tester);
      expect(find.text('Pick a section on the left to begin.'), findsOneWidget);
      expect(find.text('Panel not yet implemented'), findsNothing);
    });

    testWidgets('renders the "Settings" heading in the empty state', (
      tester,
    ) async {
      await _pumpPlaceholder(tester);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('SettingsV2DetailPlaceholder — selected state', () {
    testWidgets(
      'when a path is set, shows the "Panel not yet implemented" '
      'headline and the leaf id as a hint',
      (tester) async {
        await _pumpPlaceholder(
          tester,
          initialPath: ['sync', 'sync/backfill'],
        );
        expect(find.text('Panel not yet implemented'), findsOneWidget);
        expect(find.text('sync/backfill'), findsOneWidget);
        expect(find.text('Pick a section on the left to begin.'), findsNothing);
      },
    );
  });

  group('SettingsV2DetailPlaceholder — disable-V2 escape hatch', () {
    testWidgets('button is visible in the empty state', (tester) async {
      await _pumpPlaceholder(tester);
      expect(find.text('Disable Settings V2'), findsOneWidget);
    });

    testWidgets('button is visible in the selected state', (tester) async {
      await _pumpPlaceholder(tester, initialPath: ['flags']);
      expect(find.text('Disable Settings V2'), findsOneWidget);
    });

    testWidgets(
      'tap fetches the current flag, copies with status=false, and '
      'writes through PersistenceLogic.setConfigFlag',
      (tester) async {
        final bench = await _pumpPlaceholder(
          tester,
          existingFlag: const ConfigFlag(
            name: enableSettingsTreeFlag,
            description: 'Enable Settings V2 (canonical description)',
            status: true,
          ),
        );
        await tester.tap(find.text('Disable Settings V2'));
        await tester.pumpAndSettle();

        verify(
          () => bench.journalDb.getConfigFlagByName(
            enableSettingsTreeFlag,
          ),
        ).called(1);

        final captured = verify(
          () => bench.persistence.setConfigFlag(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final flag = captured.single as ConfigFlag;
        expect(flag.name, enableSettingsTreeFlag);
        expect(flag.status, isFalse);
        // Description must be carried over from the existing row —
        // the button mustn't invent its own copy.
        expect(flag.description, 'Enable Settings V2 (canonical description)');
      },
    );

    testWidgets(
      'tap with no existing flag row still writes a status=false row',
      (tester) async {
        // Edge case: db never had the flag installed (fresh install
        // that predates the feature). Button must still disable.
        final bench = await _pumpPlaceholder(tester);
        await tester.tap(find.text('Disable Settings V2'));
        await tester.pumpAndSettle();

        final captured = verify(
          () => bench.persistence.setConfigFlag(captureAny()),
        ).captured;
        final flag = captured.single as ConfigFlag;
        expect(flag.name, enableSettingsTreeFlag);
        expect(flag.status, isFalse);
      },
    );
  });
}
