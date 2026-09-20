import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_toggle_list.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Three rows from three different groups — the widget is indifferent to
/// which surface supplied them, which is the point of extracting it.
const _flags = [
  ConfigFlag(name: privateFlag, description: 'raw private', status: true),
  ConfigFlag(
    name: enableHabitsPageFlag,
    description: 'raw habits',
    status: false,
  ),
  ConfigFlag(
    name: enableLoggingFlag,
    description: 'raw logging',
    status: false,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(() {
    registerFallbackValue(fallbackConfigFlag);
  });

  setUp(() {
    mockPersistenceLogic = MockPersistenceLogic();
    when(
      () => mockPersistenceLogic.setConfigFlag(any()),
    ).thenAnswer((_) async {});

    GetIt.I
      ..pushNewScope()
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await GetIt.I.popScope();
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ConfigFlagToggleList(flags: _flags),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('ConfigFlagToggleList', () {
    testWidgets('labels every row from the catalog, never the raw DB text', (
      tester,
    ) async {
      await pumpList(tester);
      final context = tester.element(find.byType(ConfigFlagToggleList));

      expect(find.text(context.messages.configFlagPrivate), findsOneWidget);
      expect(
        find.text(context.messages.configFlagEnableHabitsPage),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.configFlagEnableLoggingDescription),
        findsOneWidget,
      );
      // The English developer strings `initConfigFlags` writes into the
      // database are never user-facing copy.
      for (final flag in _flags) {
        expect(find.text(flag.description), findsNothing);
      }
      expect(find.byType(SettingsIcon), findsNWidgets(_flags.length));
    });

    testWidgets('each toggle reflects the stored status', (tester) async {
      await pumpList(tester);
      final toggles = tester
          .widgetList<DesignSystemToggle>(find.byType(DesignSystemToggle))
          .toList();
      expect(
        toggles.map((toggle) => toggle.value).toList(),
        _flags.map((flag) => flag.status).toList(),
      );
    });

    testWidgets('tapping a row persists the inverted status', (tester) async {
      await pumpList(tester);
      final context = tester.element(find.byType(ConfigFlagToggleList));

      await tester.tap(
        find.widgetWithText(
          DesignSystemListItem,
          context.messages.configFlagEnableHabitsPage,
        ),
      );
      await tester.pump();

      verify(
        () => mockPersistenceLogic.setConfigFlag(
          const ConfigFlag(
            name: enableHabitsPageFlag,
            description: 'raw habits',
            status: true,
          ),
        ),
      ).called(1);
    });

    testWidgets('dragging the toggle persists the value it reports', (
      tester,
    ) async {
      await pumpList(tester);
      final context = tester.element(find.byType(ConfigFlagToggleList));

      // The already-on private row: the toggle must write `false`, not
      // blindly re-write what was stored.
      final toggle = tester.widget<DesignSystemToggle>(
        find.descendant(
          of: find.widgetWithText(
            DesignSystemListItem,
            context.messages.configFlagPrivate,
          ),
          matching: find.byType(DesignSystemToggle),
        ),
      );
      toggle.onChanged(false);
      await tester.pump();

      verify(
        () => mockPersistenceLogic.setConfigFlag(
          const ConfigFlag(
            name: privateFlag,
            description: 'raw private',
            status: false,
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'hovering a row fades the hairlines that bracket it, and showDivider '
      'stays stable so the layout never shifts by 1 px',
      (tester) async {
        await pumpList(tester);

        List<DesignSystemListItem> rows() => tester
            .widgetList<DesignSystemListItem>(
              find.byType(DesignSystemListItem),
            )
            .toList();
        bool isFaded(DesignSystemListItem item) =>
            item.dividerColor == Colors.transparent;

        // Idle: the last row of a card draws no hairline, nothing is faded.
        for (final (index, row) in rows().indexed) {
          expect(
            row.showDivider,
            index < _flags.length - 1,
            reason: 'showDivider must be stable across hover state',
          );
          expect(isFaded(row), isFalse, reason: 'no row faded when idle');
        }

        // Hover events need pointer kind `mouse` — `tester.tap` will not
        // fire `MouseRegion.onEnter`.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await gesture.moveTo(
          tester.getCenter(find.byType(DesignSystemListItem).at(1)),
        );
        await tester.pump();

        for (final (index, row) in rows().indexed) {
          expect(row.showDivider, index < _flags.length - 1);
          expect(
            isFaded(row),
            index == 0 || index == 1,
            reason: 'only the hairlines bracketing row 1 should fade',
          );
        }

        await gesture.moveTo(Offset.zero);
        await tester.pump();
        for (final row in rows()) {
          expect(isFaded(row), isFalse);
        }
      },
    );

    testWidgets('subtitles are uncapped so long descriptions wrap', (
      tester,
    ) async {
      await pumpList(tester);
      for (final row in tester.widgetList<DesignSystemListItem>(
        find.byType(DesignSystemListItem),
      )) {
        expect(row.subtitleMaxLines, isNull);
      }
    });
  });
}
