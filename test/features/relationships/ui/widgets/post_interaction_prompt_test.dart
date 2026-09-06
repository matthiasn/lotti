import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
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

  /// When set, [clear] waits on it — so a test can let the clock move while
  /// the marker is being cleared.
  Completer<void>? clearGate;

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
    if (clearGate case final gate?) await gate.future;
    clearCount++;
    _pending = null;
  }
}

void main() {
  final startedAt = DateTime(2026, 8, 17, 11, 30);
  // The user comes back eleven minutes after leaving for the call.
  final now = DateTime(2026, 8, 17, 11, 41);

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
    DateTime? startedAt,
  }) => (
    relationshipId: relationshipId,
    interactionType: type,
    startedAt: startedAt ?? DateTime(2026, 8, 17, 11, 30),
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

    await withClock(Clock.fixed(now), () async {
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
    });
    return store;
  }

  final offer = find.byKey(const ValueKey('person-post-call-offer'));

  group('when the prompt appears', () {
    testWidgets('names the person, the channel and how long ago', (
      tester,
    ) async {
      await pump(tester, pending: marker(), resolves: person());

      expect(
        find.text(
          'You called Anna Schmidt 11 minutes ago — log it while it is fresh?',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIcons.call), findsOneWidget);
    });

    testWidgets('states when it started and about how long it has been, in '
        'the mono meta style', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      final meta = tester.widget<Text>(
        find.byKey(const ValueKey('person-post-call-meta')),
      );
      expect(meta.data, 'started 11:30 · about 11 min');
      expect(meta.style?.fontFamily, 'Inconsolata');
    });

    testWidgets('a single minute reads in the singular', (tester) async {
      await pump(
        tester,
        pending: marker(startedAt: DateTime(2026, 8, 17, 11, 40)),
        resolves: person(),
      );

      expect(
        find.text(
          'You called Anna Schmidt 1 minute ago — log it while it is fresh?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('under a minute reads as such, never as "0 minutes"', (
      tester,
    ) async {
      await pump(
        tester,
        pending: marker(startedAt: DateTime(2026, 8, 17, 11, 40, 30)),
        resolves: person(),
      );

      expect(
        find.text(
          'You called Anna Schmidt less than a minute ago — log it while it '
          'is fresh?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a message reads as writing, not calling', (tester) async {
      await pump(
        tester,
        pending: marker(type: CheckInInteractionType.message),
        resolves: person(),
      );

      expect(
        find.text(
          'You wrote to Anna Schmidt 11 minutes ago — log it while it is '
          'fresh?',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIcons.chat), findsOneWidget);
    });

    testWidgets('wears the interactive wash, not a plain card', (
      tester,
    ) async {
      await pump(tester, pending: marker(), resolves: person());

      final tokens = tester.element(offer).designTokens;
      final decoration =
          tester.widget<Container>(offer).decoration! as BoxDecoration;
      expect(decoration.color, PostInteractionPrompt.washColor(tokens));
      expect(find.byType(Card), findsNothing);
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

      expect(offer, findsNothing);
    });

    testWidgets('renders nothing when the person has since been deleted', (
      tester,
    ) async {
      await pump(tester, pending: marker());

      expect(
        offer,
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

      expect(offer, findsNothing);
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

      expect(offer, findsNothing);
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
      await pump(tester, pending: marker(), resolves: person());

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

    testWidgets('hands the elapsed minutes to the sheet as the duration, so '
        'the saved check-in shows what the offer promised', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      await withClock(Clock.fixed(now), () async {
        await tester.tap(find.text('Log check-in'));
        await tester.pumpAndSettle();
      });

      final form = tester.widget<CheckInCaptureForm>(
        find.byType(CheckInCaptureForm),
      );
      expect(form.prefilledTime, DateTime(2026, 8, 17, 11, 30));
      expect(form.prefilledDuration, const Duration(minutes: 11));
    });

    testWidgets('the minutes handed to the sheet are the ones the offer '
        'quoted, even when clearing the marker crosses a minute boundary', (
      tester,
    ) async {
      var current = now;
      final store = _FakePendingInteractionStore(marker());
      when(
        () => repository.getRelationshipById(any()),
      ).thenAnswer((_) async => person());
      await withClock(Clock(() => current), () async {
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
        expect(find.textContaining('11 minutes ago'), findsOneWidget);

        // Accepting clears the marker first; the clock moves on while that
        // is in flight.
        final gate = store.clearGate = Completer<void>();
        await tester.tap(find.text('Log check-in'));
        await tester.pump();
        current = now.add(const Duration(minutes: 5));
        gate.complete();
        await tester.pumpAndSettle();
      });

      final form = tester.widget<CheckInCaptureForm>(
        find.byType(CheckInCaptureForm),
      );
      expect(form.prefilledDuration, const Duration(minutes: 11));
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
      expect(offer, findsNothing);

      await store.remember(
        relationshipId: 'rel-1',
        interactionType: CheckInInteractionType.call,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(offer, findsOneWidget);
      expect(find.textContaining('You called Anna Schmidt'), findsOneWidget);
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
        offer,
        findsNothing,
        reason:
            'going to the background is when the call starts, not when '
            'the user comes back from it',
      );
    });
  });
}
