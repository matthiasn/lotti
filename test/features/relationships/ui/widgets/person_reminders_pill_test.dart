import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/person_reminders_pill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockRelationshipRepository repository;
  late MockRelationshipAgentService agentService;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockRelationshipRepository();
    agentService = MockRelationshipAgentService();
    when(
      () => repository.updateRelationship(any()),
    ).thenAnswer((_) async => true);
    when(
      () => agentService.ensureAgentForRelationship(any()),
    ).thenAnswer((_) async => throw StateError('not under test'));
  });

  RelationshipEntry person({int? cadenceDays = 7}) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      dateFrom: DateTime(2026, 7),
      dateTo: DateTime(2026, 7),
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      important: true,
      checkInCadenceDays: cadenceDays,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: DateTime(2026, 7),
        utcOffset: 0,
      ),
    ),
  );

  final pillFinder = find.byKey(const ValueKey('person-pill-reminders'));

  Future<void> pump(WidgetTester tester, RelationshipEntry relationship) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        PersonRemindersPill(relationship: relationship),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(repository),
          relationshipAgentServiceProvider.overrideWithValue(agentService),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(pillFinder);
    await tester.pumpAndSettle();
  }

  List<String?> selectedLabels(WidgetTester tester) => tester
      .widgetList<DsPill>(
        find.descendant(
          of: find.byKey(const ValueKey('person-reminders-cadence')),
          matching: find.byType(DsPill),
        ),
      )
      .where((pill) => pill.selected)
      .map((pill) => pill.label)
      .toList();

  RelationshipEntry saved() =>
      verify(() => repository.updateRelationship(captureAny())).captured.single
          as RelationshipEntry;

  testWidgets('names the interval, and says to a screen reader that it can '
      'be changed', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, person());

    expect(tester.widget<DsPill>(pillFinder).label, 'Weekly');
    expect(
      tester.getSemantics(pillFinder).label,
      'Reminders: Weekly. Tap to change.',
    );
    handle.dispose();
  });

  testWidgets('with no stored interval it names the default the reminders '
      'actually run on', (tester) async {
    await pump(tester, person(cadenceDays: null));

    expect(tester.widget<DsPill>(pillFinder).label, 'Monthly');
  });

  testWidgets('opens a sheet asking how often, on the current interval', (
    tester,
  ) async {
    await pump(tester, person());
    await openSheet(tester);

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('How often?'), findsOneWidget);
    expect(selectedLabels(tester), ['Weekly']);
    expect(find.text('Turn reminders off'), findsOneWidget);
  });

  testWidgets('a new interval saves at once, re-runs the evaluation so it '
      'takes effect now, and closes the sheet', (tester) async {
    await pump(tester, person());
    await openSheet(tester);

    await tester.tap(find.text('Every two weeks'));
    await tester.pumpAndSettle();

    final updated = saved();
    expect(updated.data.checkInCadenceDays, 14);
    expect(updated.data.important, isTrue);
    final ensured =
        verify(
              () => agentService.ensureAgentForRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(ensured.data.checkInCadenceDays, 14);
    expect(find.text('How often?'), findsNothing);
  });

  testWidgets('picking the interval already set just closes, writing '
      'nothing', (tester) async {
    await pump(tester, person());
    await openSheet(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('person-reminders-cadence')),
        matching: find.text('Weekly'),
      ),
    );
    await tester.pumpAndSettle();

    verifyNever(() => repository.updateRelationship(any()));
    expect(find.text('How often?'), findsNothing);
  });

  testWidgets('turning reminders off keeps the interval, so turning them '
      'back on later brings the same rhythm back', (tester) async {
    await pump(tester, person(cadenceDays: 90));
    await openSheet(tester);

    await tester.tap(find.text('Turn reminders off'));
    await tester.pumpAndSettle();

    final updated = saved();
    expect(updated.data.important, isFalse);
    expect(updated.data.checkInCadenceDays, 90);
    // Nothing to re-evaluate for someone whose reminders are off.
    verifyNever(() => agentService.ensureAgentForRelationship(any()));
    expect(find.text('How often?'), findsNothing);
  });

  testWidgets('a refused save says so and keeps the sheet open to try '
      'again', (tester) async {
    when(
      () => repository.updateRelationship(any()),
    ).thenAnswer((_) async => false);
    await pump(tester, person());
    await openSheet(tester);

    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();

    // `findsWidgets`, not one: a ScaffoldMessenger shows its toast in every
    // Scaffold it serves, and with the sheet up that is the page behind the
    // barrier too.
    expect(
      find.text('Could not save the changes. Please try again.'),
      findsWidgets,
    );
    expect(find.text('How often?'), findsOneWidget);
    verifyNever(() => agentService.ensureAgentForRelationship(any()));
  });

  testWidgets('a throwing save is contained the same way', (tester) async {
    when(
      () => repository.updateRelationship(any()),
    ).thenThrow(StateError('db closed'));
    await pump(tester, person());
    await openSheet(tester);

    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();

    // `findsWidgets`, not one: a ScaffoldMessenger shows its toast in every
    // Scaffold it serves, and with the sheet up that is the page behind the
    // barrier too.
    expect(
      find.text('Could not save the changes. Please try again.'),
      findsWidgets,
    );
    expect(find.text('How often?'), findsOneWidget);
  });
}
