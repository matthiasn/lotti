import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

Future<void> _pumpCreatePage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(makeTestableWidgetNoScroll(CreateDashboardPage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The action-bar pill carrying [label].
Finder _pill(String label) => find.widgetWithText(DsGlassPill, label);

void main() {
  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('CreateDashboardPage Widget Tests - ', () {
    setUpAll(registerAllFallbackValues);

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      when(mockJournalDb.getAllCategories).thenAnswer(
        (_) async => [categoryMindfulness],
      );
      when(mockJournalDb.getAllHabitDefinitions).thenAnswer(
        (_) async => [habitFlossing],
      );

      mockPersistenceLogic = MockPersistenceLogic();

      final mockUpdateNotifications = MockUpdateNotifications();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(MockEntitiesCacheService())
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      ensureThemingServicesRegistered();

      beamToNamedOverride = (_) {};
    });
    tearDown(() async {
      beamToNamedOverride = null;
      await getIt.reset();
    });

    testWidgets(
      'renders create chrome: create title, disabled Create pill, and no '
      'destructive delete action',
      (tester) async {
        await _pumpCreatePage(tester);

        // Create-mode header title.
        expect(find.text('Create dashboard'), findsOneWidget);

        // The primary action is labeled Create and disabled while pristine.
        final createPill = tester.widget<DsGlassPill>(_pill('Create'));
        expect(createPill.enabled, isFalse);

        // No destructive delete affordance in create mode.
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

        // Both form fields are present and empty.
        expect(find.byKey(const Key('dashboard_name_field')), findsOneWidget);
        expect(
          find.byKey(const Key('dashboard_description_field')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'entering a name enables Create; tapping it persists the new '
      'dashboard and beams back to the list',
      (tester) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        DashboardDefinition? saved;
        when(
          () => mockPersistenceLogic.upsertDashboardDefinition(any()),
        ).thenAnswer((invocation) async {
          saved = invocation.positionalArguments.first as DashboardDefinition;
          return 1;
        });

        await _pumpCreatePage(tester);

        await tester.enterText(
          find.byKey(const Key('dashboard_name_field')),
          'My new dashboard',
        );
        await tester.pump();

        // The Create pill is enabled now that the form is dirty.
        expect(tester.widget<DsGlassPill>(_pill('Create')).enabled, isTrue);

        await tester.tap(_pill('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The freshly created dashboard is persisted with the entered name
        // and the constructor defaults (active, not private, no items).
        expect(saved, isNotNull);
        expect(saved!.name, 'My new dashboard');
        expect(saved!.active, isTrue);
        expect(saved!.private, isFalse);
        expect(saved!.items, isEmpty);
        expect(beamedTo, '/settings/dashboards');
      },
    );

    testWidgets(
      'cancel pill beams back to the list without persisting anything',
      (tester) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await _pumpCreatePage(tester);

        await tester.tap(_pill('Cancel'));
        await tester.pump();

        verifyNever(
          () => mockPersistenceLogic.upsertDashboardDefinition(any()),
        );
        expect(beamedTo, '/settings/dashboards');
      },
    );
  });
}
