import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/post_interaction_prompt.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// In-memory stand-in for the settings-backed marker store, so the prompt's
/// reads and clears are both scriptable and observable.
class _FakePendingInteractionStore implements PendingInteractionStore {
  _FakePendingInteractionStore([this._pending]);

  PendingInteraction? _pending;
  int clearCount = 0;

  @override
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) async {
    _pending = (
      relationshipId: relationshipId,
      interactionType: interactionType,
      startedAt: DateTime(2026, 8, 17, 12),
    );
  }

  @override
  Future<PendingInteraction?> read() async => _pending;

  @override
  Future<void> clear() async {
    clearCount++;
    _pending = null;
  }
}

void main() {
  final startedAt = DateTime(2026, 8, 17, 11, 30);

  late MockRelationshipRepository repository;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockRelationshipRepository();
  });

  RelationshipEntry person({String title = 'Anna Schmidt'}) =>
      RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: startedAt,
          updatedAt: startedAt,
          dateFrom: startedAt,
          dateTo: startedAt,
        ),
        data: RelationshipData(
          title: title,
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: startedAt,
            utcOffset: 0,
          ),
        ),
      );

  PendingInteraction marker({
    String relationshipId = 'rel-1',
    CheckInInteractionType type = CheckInInteractionType.call,
  }) => (
    relationshipId: relationshipId,
    interactionType: type,
    startedAt: startedAt,
  );

  Future<_FakePendingInteractionStore> pump(
    WidgetTester tester, {
    PendingInteraction? pending,
    RelationshipEntry? resolves,
  }) async {
    final store = _FakePendingInteractionStore(pending);
    when(
      () => repository.getRelationshipById(any()),
    ).thenAnswer((_) async => resolves);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const PostInteractionPrompt(),
        overrides: [
          pendingInteractionStoreProvider.overrideWithValue(store),
          relationshipRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  group('when the prompt appears', () {
    testWidgets('names the person the user just contacted', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      expect(find.text('How did it go with Anna Schmidt?'), findsOneWidget);
    });

    testWidgets('offers both logging and declining', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      expect(find.text('Log check-in'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });
  });

  group('when the prompt stays silent', () {
    testWidgets('renders nothing when no call was placed', (tester) async {
      await pump(tester, resolves: person());

      expect(find.text('Log check-in'), findsNothing);
    });

    testWidgets('renders nothing when the person has since been deleted', (
      tester,
    ) async {
      await pump(tester, pending: marker());

      expect(
        find.text('Log check-in'),
        findsNothing,
        reason:
            'the marker holds an id written before the user left; the '
            'person may be gone by the time they return',
      );
    });

    testWidgets('reads the marker on mount, covering a cold start after the '
        'app was killed in the dialer', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      verify(() => repository.getRelationshipById('rel-1')).called(1);
    });
  });

  group('declining', () {
    testWidgets('drops the prompt', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Log check-in'), findsNothing);
    });

    testWidgets('clears the marker, so declining leaves no trace', (
      tester,
    ) async {
      final store = await pump(
        tester,
        pending: marker(),
        resolves: person(),
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(store.clearCount, 1);
      expect(await store.read(), isNull);
    });

    testWidgets('does not reappear on the next resume', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Log check-in'), findsNothing);
    });
  });

  group('accepting', () {
    testWidgets('clears the marker before opening the form, so backing out '
        'is not asked twice', (tester) async {
      final store = await pump(
        tester,
        pending: marker(),
        resolves: person(),
      );

      await tester.tap(find.text('Log check-in'));
      await tester.pumpAndSettle();

      expect(store.clearCount, 1);
      expect(await store.read(), isNull);
    });

    testWidgets('opens the form already describing the call that happened', (
      tester,
    ) async {
      await pump(
        tester,
        pending: marker(),
        resolves: person(),
      );

      await tester.tap(find.text('Log check-in'));
      await tester.pumpAndSettle();

      final selected = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((chip) => chip.selected)
          .toList();

      expect(selected, hasLength(1));
      expect(
        ((selected.single.label) as Text).data,
        'Call',
        reason:
            'the sheet must open on what actually happened, not on the '
            'in-person default',
      );
    });

    testWidgets('carries a message interaction through instead of a call', (
      tester,
    ) async {
      await pump(
        tester,
        pending: marker(type: CheckInInteractionType.message),
        resolves: person(),
      );

      await tester.tap(find.text('Log check-in'));
      await tester.pumpAndSettle();

      final selected = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .firstWhere((chip) => chip.selected);

      expect(((selected.label) as Text).data, 'Message');
    });

    testWidgets('leaves sentiment unset — the user judges how it felt, '
        'never the app (ADR 0038)', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Log check-in'));
      await tester.pumpAndSettle();

      // Interaction and sentiment both render as ChoiceChips, so the
      // sentiment row is identified by its labels rather than its type.
      const sentimentLabels = {
        'Delightful',
        'Good',
        'Neutral',
        'Strained',
        'Difficult',
      };
      List<ChoiceChip> chips() =>
          tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();

      expect(
        chips().map((chip) => (chip.label as Text).data).toSet(),
        containsAll(sentimentLabels),
        reason:
            'guards the assertion below: the sentiment chips must '
            'actually be on screen for "none selected" to mean anything',
      );

      final selectedLabels = chips()
          .where((chip) => chip.selected)
          .map((chip) => (chip.label as Text).data)
          .toSet();

      expect(selectedLabels.intersection(sentimentLabels), isEmpty);
    });
  });

  group('resuming', () {
    testWidgets('picks up a marker written while the widget was mounted', (
      tester,
    ) async {
      final store = await pump(tester, resolves: person());
      expect(find.text('Log check-in'), findsNothing);

      await store.remember(
        relationshipId: 'rel-1',
        interactionType: CheckInInteractionType.call,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('How did it go with Anna Schmidt?'), findsOneWidget);
    });

    testWidgets('ignores lifecycle states other than resumed', (tester) async {
      final store = await pump(tester, resolves: person());

      await store.remember(
        relationshipId: 'rel-1',
        interactionType: CheckInInteractionType.call,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(
        find.text('Log check-in'),
        findsNothing,
        reason:
            'going to the background is when the call starts, not when '
            'the user comes back from it',
      );
    });
  });
}
