import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  testWidgets(
    'FloatingAddActionButton renders the design-system FAB '
    '(rounded-24, no Material default circle)',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FloatingAddActionButton(),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(LottiIcons.add), findsOneWidget);

      final size = tester.getSize(
        find.byType(DesignSystemFloatingActionButton),
      );
      expect(size, const Size(56, 56));
    },
  );

  testWidgets(
    'tapping the FAB opens CreateEntryModal with the wired ids',
    (tester) async {
      final mockDb = MockJournalDb();
      when(mockDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );
      getIt
        ..registerSingleton<NavService>(MockNavService())
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<JournalDb>(mockDb);
      addTearDown(getIt.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
          child: makeTestableWidget2(
            const Scaffold(
              body: FloatingAddActionButton(
                linkedFromId: 'fab-linked-id',
                categoryId: 'fab-category',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DesignSystemFloatingActionButton));
      // Bottom-sheet route transition — settle until mounted.
      await tester.pumpAndSettle();

      // The modal body renders its menu items; the Timer item proves the
      // linkedFromId made it through (it only shows with a linked id).
      expect(find.byType(DsActionRow), findsWidgets);
      // Descendant, not a bare icon anywhere on screen: the timer glyph also
      // rides the action bar, so a loose finder would pass even if the row
      // never rendered.
      expect(
        find.descendant(
          of: find.byType(DsActionRow),
          matching: find.byIcon(LottiIcons.timer),
        ),
        findsOneWidget,
      );
    },
  );
}
