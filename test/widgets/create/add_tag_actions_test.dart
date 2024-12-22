import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/create/add_tag_actions.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(FakeEntryText());
  registerFallbackValue(FakeTaskData());
  registerFallbackValue(FakeJournalEntity());

  group('RadialAddTagButtons Widget Tests - ', () {
    final mockNavService = MockNavService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockTimeService = MockTimeService();

    setUp(() {
      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets(
      'tap add generic tag icon',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddTagButtons(),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final tagIconFinder = find.byIcon(MdiIcons.tagPlusOutline);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(tagIconFinder, findsOneWidget);

        await tester.tap(tagIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService.beamToNamed('/settings/tags/create/TAG'),
        ).called(1);
      },
    );

    testWidgets(
      'tap add person tag icon',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddTagButtons(),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final tagIconFinder = find.byIcon(MdiIcons.tagFaces);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(tagIconFinder, findsOneWidget);

        await tester.tap(tagIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService.beamToNamed('/settings/tags/create/PERSON'),
        ).called(1);
      },
    );

    testWidgets(
      'tap add story tag icon',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddTagButtons(),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final tagIconFinder = find.byIcon(MdiIcons.book);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(tagIconFinder, findsOneWidget);

        await tester.tap(tagIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService.beamToNamed('/settings/tags/create/STORY'),
        ).called(1);
      },
    );
  });
}
