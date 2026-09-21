import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
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
  Future<void> put(PendingInteraction p) async => _pending = p;

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

  // The composer's header reads the person through the detail controller,
  // which listens to the update bus.
  setUp(() async {
    await setUpTestGetIt();
    repository = MockRelationshipRepository();
    when(
      () => repository.getEntriesForCheckIns(any()),
    ).thenAnswer((_) async => const {});
    when(
      () => repository.getCheckInsForRelationship(any()),
    ).thenAnswer((_) async => const []);
    when(() => repository.getLinkedTasks(any())).thenAnswer((_) async => []);
  });

  tearDown(tearDownTestGetIt);

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
    double bottomGap = 0,
    String relationshipId = 'rel-1',
  }) async {
    final store = _FakePendingInteractionStore(pending);
    when(
      () => repository.getRelationshipById(any()),
    ).thenAnswer((_) async => resolves);

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          PostInteractionPrompt(
            relationshipId: relationshipId,
            bottomGap: bottomGap,
          ),
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
    testWidgets('asks rather than asserts: the marker proves the dialer '
        'opened, not that anyone answered', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      expect(find.text('Did you reach Anna Schmidt?'), findsOneWidget);
      expect(find.textContaining('You called'), findsNothing);
      expect(find.byIcon(LottiIcons.call), findsOneWidget);
    });

    testWidgets('states when it started and about how long it has been, in '
        'the mono meta style', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      final meta = tester.widget<Text>(
        find.byKey(const ValueKey('person-post-call-meta')),
      );
      expect(meta.data, 'started 11:30 AM · about 11 min');
      expect(meta.style?.fontFamily, 'Inconsolata');
    });

    testWidgets('under a minute reads as such, never as "0 minutes"', (
      tester,
    ) async {
      await pump(
        tester,
        pending: marker(startedAt: DateTime(2026, 8, 17, 11, 40, 30)),
        resolves: person(),
      );

      expect(find.text('started 11:40 AM · under a minute'), findsOneWidget);
    });

    testWidgets('a single minute reads in the singular on the meta line too', (
      tester,
    ) async {
      await pump(
        tester,
        pending: marker(startedAt: DateTime(2026, 8, 17, 11, 40)),
        resolves: person(),
      );

      expect(find.text('started 11:40 AM · about 1 min'), findsOneWidget);
    });

    testWidgets('a message reads as writing, not calling', (tester) async {
      await pump(
        tester,
        pending: marker(type: CheckInInteractionType.message),
        resolves: person(),
      );

      expect(find.text('Did you write to Anna Schmidt?'), findsOneWidget);
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

    testWidgets('offers both logging and declining, logging as a secondary '
        "button: the page's bar already carries the one filled Log "
        'check-in', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      final yes = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('person-post-call-yes')),
      );
      expect(yes.label, 'Yes, log it');
      expect(yes.variant, DesignSystemButtonVariant.secondary);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });

  group('when the prompt stays silent', () {
    testWidgets('its gap belongs to the offer: a page seating it between '
        'two sections gets no hole where there is nothing to offer', (
      tester,
    ) async {
      await pump(tester, bottomGap: 24);
      expect(tester.getSize(find.byType(PostInteractionPrompt)), Size.zero);
    });

    testWidgets('with an offer, the gap follows it', (tester) async {
      await pump(tester, pending: marker(), resolves: person(), bottomGap: 24);
      expect(
        tester.getSize(find.byType(PostInteractionPrompt)).height,
        tester.getSize(offer).height + 24,
      );
    });

    testWidgets('an older refresh finishing late cannot bring back an offer '
        'the page has since claimed', (tester) async {
      final store = _FakePendingInteractionStore(marker());
      // The mount's refresh reads the marker, then waits on the person.
      final lookup = Completer<RelationshipEntry?>();
      when(
        () => repository.getRelationshipById(any()),
      ).thenAnswer((_) => lookup.future);

      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const PostInteractionPrompt(relationshipId: 'rel-1'),
            overrides: [
              pendingInteractionStoreProvider.overrideWithValue(store),
              relationshipRepositoryProvider.overrideWithValue(repository),
            ],
          ),
        );
        await tester.pump();

        // Log check-in on the page claims the marker; the claim's own
        // refresh reads an empty store and settles on no offer.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PostInteractionPrompt)),
        );
        await container
            .read(pendingInteractionClaimsProvider.notifier)
            .claimFor('rel-1');
        await tester.pump();

        // Now the first refresh's lookup lands.
        lookup.complete(person());
        await tester.pumpAndSettle();
      });

      expect(offer, findsNothing);
    });

    testWidgets("a call to someone else is not offered on this person's "
        'page — accepting it would open their composer', (tester) async {
      final store = await pump(
        tester,
        pending: marker(relationshipId: 'rel-anna'),
        resolves: person(),
        relationshipId: 'rel-bo',
      );

      expect(offer, findsNothing);
      // Nor is it thrown away: it is still Anna's to log from her page.
      expect(store.clearCount, 0);
    });

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

      await tester.tap(find.text('Dismiss'));
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

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(store.clearCount, 1);
      expect(await store.read(), isNull);
    });

    testWidgets('does not reappear on the next resume', (tester) async {
      await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(offer, findsNothing);
    });
  });

  group('accepting', () {
    testWidgets('takes the marker while the form is open, so the offer does '
        'not ask about a call already being logged', (tester) async {
      final store = await pump(
        tester,
        pending: marker(),
        resolves: person(),
      );

      await tester.tap(find.text('Yes, log it'));
      await tester.pumpAndSettle();

      expect(store.clearCount, 1);
      expect(await store.read(), isNull);
    });

    testWidgets('closing the form without saving hands the call back: the '
        'offer returns with it, as it was, so a stray swipe loses nothing', (
      tester,
    ) async {
      final store = await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Yes, log it'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckInCaptureForm), findsOneWidget);
      expect(offer, findsNothing);

      // An untouched composer closes at once.
      await tester.tap(find.byKey(const ValueKey('check-in-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(CheckInCaptureForm), findsNothing);
      expect(await store.read(), marker());
      expect(offer, findsOneWidget);
    });

    testWidgets('opens the form already describing the call that happened', (
      tester,
    ) async {
      await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Yes, log it'));
      await tester.pumpAndSettle();

      // The type chip reads the interaction; no chip is "selected" — that
      // grammar belongs to the sentiment row.
      final typeChip = tester.widget<DesignSystemChip>(
        find.byKey(const ValueKey('check-in-type')),
      );
      expect(
        typeChip.label,
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
        await tester.tap(find.text('Yes, log it'));
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
            const PostInteractionPrompt(relationshipId: 'rel-1'),
            overrides: [
              pendingInteractionStoreProvider.overrideWithValue(store),
              relationshipRepositoryProvider.overrideWithValue(repository),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('about 11 min'), findsOneWidget);

        // Accepting clears the marker first; the clock moves on while that
        // is in flight.
        final gate = store.clearGate = Completer<void>();
        await tester.tap(find.text('Yes, log it'));
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

      await tester.tap(find.text('Yes, log it'));
      await tester.pumpAndSettle();

      final typeChip = tester.widget<DesignSystemChip>(
        find.byKey(const ValueKey('check-in-type')),
      );
      expect(typeChip.label, 'Message');
    });

    testWidgets('leaves sentiment unset — the user judges how it felt, '
        'never the app (ADR 0038)', (tester) async {
      setTestSurfaceSize(tester, const Size(1000, 1400));
      await pump(tester, pending: marker(), resolves: person());

      await tester.tap(find.text('Yes, log it'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('check-in-more')));
      await tester.tap(find.byKey(const ValueKey('check-in-more')));
      await tester.pumpAndSettle();

      // Interaction and sentiment both render as DesignSystemChips, so the
      // sentiment row is identified by its labels rather than its type.
      const sentimentLabels = {
        'Delightful',
        'Good',
        'Neutral',
        'Strained',
        'Difficult',
      };
      List<DesignSystemChip> chips() => tester
          .widgetList<DesignSystemChip>(find.byType(DesignSystemChip))
          .toList();

      expect(
        chips().map((chip) => chip.label).toSet(),
        containsAll(sentimentLabels),
        reason:
            'guards the assertion below: the sentiment chips must '
            'actually be on screen for "none selected" to mean anything',
      );

      final selectedLabels = chips()
          .where((chip) => chip.selected)
          .map((chip) => chip.label)
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
      expect(find.text('Did you reach Anna Schmidt?'), findsOneWidget);
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
