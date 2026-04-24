import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings_v2/ui/detail/disable_v2_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class _MockPersistenceLogic extends Mock implements PersistenceLogic {}

Future<_MockPersistenceLogic> _pumpButton(WidgetTester tester) async {
  final mocks = await setUpTestGetIt();
  final persistence = _MockPersistenceLogic();
  when(() => persistence.setConfigFlag(any())).thenAnswer((_) async => 1);
  when(() => mocks.journalDb.getConfigFlagByName(any())).thenAnswer(
    (_) async => const ConfigFlag(
      name: enableSettingsTreeFlag,
      description: 'canonical',
      status: true,
    ),
  );
  getIt.registerSingleton<PersistenceLogic>(persistence);
  addTearDown(tearDownTestGetIt);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Scaffold(
        body: SizedBox(width: 400, child: DisableV2Button()),
      ),
    ),
  );
  return persistence;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ConfigFlag(name: 'x', description: 'x', status: false),
    );
  });

  group('DisableV2Button — rendering', () {
    testWidgets('shows the localized "Disable Settings V2" action', (
      tester,
    ) async {
      await _pumpButton(tester);
      expect(find.text('Disable Settings V2'), findsOneWidget);
    });

    testWidgets('uses the undo icon glyph', (tester) async {
      await _pumpButton(tester);
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
    });
  });

  group('DisableV2Button — action', () {
    testWidgets(
      'tap copies the existing flag row with status=false and writes it',
      (tester) async {
        final persistence = await _pumpButton(tester);
        await tester.tap(find.byType(DisableV2Button));
        await tester.pump();

        final captured = verify(
          () => persistence.setConfigFlag(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final flag = captured.single as ConfigFlag;
        expect(flag.name, enableSettingsTreeFlag);
        expect(flag.status, isFalse);
        // Description round-trips from the canonical row we returned
        // above, so the on-disk row stays authoritative.
        expect(flag.description, 'canonical');
      },
    );

    testWidgets(
      'tap falls back to a literal ConfigFlag when the DB has no row yet',
      (tester) async {
        final mocks = await setUpTestGetIt();
        final persistence = _MockPersistenceLogic();
        when(() => persistence.setConfigFlag(any())).thenAnswer((_) async => 1);
        when(
          () => mocks.journalDb.getConfigFlagByName(any()),
        ).thenAnswer((_) async => null);
        getIt.registerSingleton<PersistenceLogic>(persistence);
        addTearDown(tearDownTestGetIt);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const Scaffold(
              body: SizedBox(width: 400, child: DisableV2Button()),
            ),
          ),
        );
        await tester.tap(find.byType(DisableV2Button));
        await tester.pump();

        final captured = verify(
          () => persistence.setConfigFlag(captureAny()),
        ).captured;
        final flag = captured.single as ConfigFlag;
        expect(flag.name, enableSettingsTreeFlag);
        expect(flag.status, isFalse);
        // The fallback branch must write the canonical description so
        // the on-disk row matches what `initConfigFlags` would have
        // created — otherwise re-enabling the flag later would round-
        // trip an empty description back into the registration.
        expect(flag.description, enableSettingsTreeFlagDescription);
      },
    );

    testWidgets(
      'persistence failure surfaces a SnackBar without crashing',
      (tester) async {
        final mocks = await setUpTestGetIt();
        final persistence = _MockPersistenceLogic();
        when(
          () => persistence.setConfigFlag(any()),
        ).thenThrow(StateError('boom'));
        when(
          () => mocks.journalDb.getConfigFlagByName(any()),
        ).thenAnswer((_) async => null);
        getIt.registerSingleton<PersistenceLogic>(persistence);
        addTearDown(tearDownTestGetIt);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const Scaffold(
              body: SizedBox(width: 400, child: DisableV2Button()),
            ),
          ),
        );
        await tester.tap(find.byType(DisableV2Button));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Could not disable Settings V2. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });
}
