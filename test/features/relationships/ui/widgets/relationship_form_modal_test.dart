import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';

/// The address book this device does or does not have. `supported: false`
/// is the desktop case, where the form offers manual entry only.
class _FakeContactsService implements ContactsService {
  bool supported = false;
  ImportedContact? picked;
  int pickCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.granted;

  @override
  Future<List<ImportedContact>> readAll() async => const [];

  @override
  Future<ImportedContact?> pickSingle() async {
    pickCalls++;
    return picked;
  }

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockRelationshipAgentService mockAgentService;
  late MockJournalRepository mockJournalRepository;
  late MockEntitiesCacheService mockCacheService;
  late _FakeContactsService contactsService;

  RelationshipEntry createdEntry(RelationshipData data) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-created',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: data,
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockRepository = MockRelationshipRepository();
    mockAgentService = MockRelationshipAgentService();
    mockJournalRepository = MockJournalRepository();
    when(
      () => mockAgentService.ensureAgentForRelationship(any()),
    ).thenAnswer((invocation) async => throw StateError('unstubbed identity'));
    when(
      () => mockJournalRepository.updateCategoryId(
        any(),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => true);
    // The category row (rendered by the form) reads the category name through
    // `getIt<EntitiesCacheService>()`; default the lookup to "no category".
    mockCacheService = MockEntitiesCacheService();
    contactsService = _FakeContactsService();
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(mockCacheService),
    );
  });

  tearDown(tearDownTestGetIt);

  /// The form with the pinned bar its actions now live in — the pairing the
  /// modal builds, so a bare-form test still has a Save to press. Scrollable
  /// because three cards exceed the harness's 800px child.
  Widget buildForm({RelationshipEntry? initial}) {
    final handle = RelationshipFormHandle();
    return makeTestableWidgetWithScaffold(
      SingleChildScrollView(
        child: Column(
          children: [
            RelationshipForm(initial: initial, handle: handle),
            RelationshipFormStickyActions(handle: handle),
          ],
        ),
      ),
      overrides: [
        relationshipRepositoryProvider.overrideWithValue(mockRepository),
        relationshipAgentServiceProvider.overrideWithValue(mockAgentService),
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        contactsServiceProvider.overrideWithValue(contactsService),
      ],
    );
  }

  // Every other test here pumps `RelationshipForm` bare, which is why the
  // defect below survived: the form was fine, the modal it lives in was not.
  // Same shape as the check-in capture sheet — see its sibling group.
  group('inside the real modal', () {
    RelationshipEntry person() => RelationshipEntry(
      meta: Metadata(
        id: 'rel-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: RelationshipData(
        title: 'Anna',
        nickname: 'Sis',
        important: true,
        checkInCadenceDays: 14,
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    );

    Future<void> openEditSheet(WidgetTester tester) async {
      // iPhone-class viewport: tall content, little room to spare.
      tester.view
        ..physicalSize = const Size(1206, 2622)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRelationshipEditModal(
                context: context,
                relationship: person(),
              ),
              child: const Text('Open'),
            ),
          ),
          overrides: [
            relationshipRepositoryProvider.overrideWithValue(mockRepository),
            relationshipAgentServiceProvider.overrideWithValue(
              mockAgentService,
            ),
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    // The form capped itself at 90% of the SCREEN while the modal page added
    // a top bar, padding and the safe area on top, so the action row sat
    // below the viewport — and the form's own scroll view consumed every
    // drag, so the page never moved and Save could not be reached at all.
    // The actions now ride the modal's pinned bar, which is what keeps them
    // on screen no matter how tall the three cards grow.
    testWidgets('Save is pinned and reachable without scrolling', (
      tester,
    ) async {
      await openEditSheet(tester);

      final save = find.byKey(const ValueKey('person-form-save'));
      final viewportBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(save, findsOneWidget);
      expect(
        tester.getBottomLeft(save).dy,
        lessThanOrEqualTo(viewportBottom),
        reason: 'Save is on screen before the user scrolls anywhere',
      );
      // And it stays there while the form scrolls under it.
      final before = tester.getTopLeft(save).dy;
      await tester.drag(
        find.byType(RelationshipForm),
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(save).dy, before);
    });

    testWidgets('Cancel in the pinned bar closes without saving', (
      tester,
    ) async {
      await openEditSheet(tester);

      await tester.tap(find.byKey(const ValueKey('person-form-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(RelationshipForm), findsNothing);
      verifyNever(() => mockRepository.updateRelationship(any()));
    });

    // The modal page scrolls the form; a second vertical scroll view inside
    // it would eat the drag that should reach the page. (The chip rows scroll
    // horizontally, which does not compete.)
    testWidgets('the form adds no vertical scroll view of its own', (
      tester,
    ) async {
      await openEditSheet(tester);

      final inner = tester.widgetList<SingleChildScrollView>(
        find.descendant(
          of: find.byType(RelationshipForm),
          matching: find.byType(SingleChildScrollView),
        ),
      );

      expect(
        inner.map((view) => view.scrollDirection),
        everyElement(Axis.horizontal),
      );
    });
  });

  testWidgets('does not persist when the name is empty', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    );
  });

  testWidgets(
    'persists name, nickname, importance, and the picked cadence preset',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.enterText(find.byType(TextField).at(1), 'Sis');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Every two weeks'));
      await tester.tap(find.text('Every two weeks'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final data =
          verify(
                () => mockRepository.createRelationship(
                  data: captureAny(named: 'data'),
                  categoryId: any(named: 'categoryId'),
                ),
              ).captured.single
              as RelationshipData;
      expect(data.title, 'Anna Example');
      expect(data.nickname, 'Sis');
      expect(data.important, isTrue);
      expect(data.checkInCadenceDays, 14);
      expect(data.status, isA<RelationshipActive>());
    },
  );

  testWidgets('a refused create reports it and keeps what was typed', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save this person. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Anna'), findsOneWidget);
  });

  testWidgets('a create that throws reports the create-mode failure', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // The create-mode copy, not the edit-mode one.
    expect(
      find.text('Could not save this person. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.text('Could not save the changes. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('Cancel closes without persisting anything', (tester) async {
    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    );
  });

  testWidgets(
    'saving an IMPORTANT person lazily mints their agent — the consent '
    'switch is the trigger (ADR 0059 Decision 2)',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );

      when(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => throw StateError('identity unused'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final entry =
          verify(
                () => mockAgentService.ensureAgentForRelationship(
                  captureAny(),
                ),
              ).captured.single
              as RelationshipEntry;
      expect(entry.data.important, isTrue);
    },
  );

  testWidgets(
    'saving a person who is NOT important never touches the agent layer',
    (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      verifyNever(() => mockAgentService.ensureAgentForRelationship(any()));
    },
  );

  testWidgets(
    'an agent-wiring failure never fails the save the user watched '
    'succeed',
    (tester) async {
      // The default stub above throws; the save must still pop cleanly.
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (invocation) async => createdEntry(
          invocation.namedArguments[#data] as RelationshipData,
        ),
      );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byType(RelationshipForm), findsNothing);
    },
  );

  group('the three cards (design 2026-09-06 §6)', () {
    testWidgets('the Important switch is one labelled control, not a switch '
        'sitting near a word', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      // A screen reader reaching the control hears what it changes, and the
      // label toggles it.
      final semantics = tester.getSemantics(find.byType(Switch));
      expect(semantics.label, contains('Important'));

      await tester.tap(find.text('Important'));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('groups the form as Who · Important · How to reach them', (
      tester,
    ) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('person-form-who-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('person-form-important-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('person-form-reach-card')),
        findsOneWidget,
      );
      expect(find.text('Who'), findsOneWidget);
      expect(find.text('How to reach them'), findsOneWidget);
      // The channels card repeats the promise the person page makes.
      expect(
        find.text('Stays on this device · never shared with the AI'),
        findsOneWidget,
      );
    });

    testWidgets('the cadence appears only once the person is important — a '
        'cadence on an unimportant person is never evaluated', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.text('Nudge me every'), findsNothing);
      expect(find.text('Weekly'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Nudge me every'), findsOneWidget);
      expect(find.widgetWithText(DsPill, 'Weekly'), findsOneWidget);
    });

    testWidgets('the Important explainer names the person once they have a '
        'name, and never promises no AI at all', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Turns on a briefing, nudges and a chat. Check-in notes go to the '
          'agent; contact channels never do.',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'Ada');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Turns on a briefing, nudges and a chat for Ada. Check-in notes go '
          'to the agent; contact channels never do.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the category shows as a colour dot, and none shows no dot', (
      tester,
    ) async {
      when(() => mockCacheService.getCategoryById('cat-1')).thenReturn(
        CategoryDefinition(
          id: 'cat-1',
          name: 'Family',
          private: false,
          active: true,
          color: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('person-form-category-dot')),
        findsNothing,
        reason: 'no category, nothing to tint',
      );

      tester
          .widget<PersonCategoryRow>(find.byType(PersonCategoryRow))
          .onChanged('cat-1');
      await tester.pumpAndSettle();

      expect(find.text('Family'), findsOneWidget);
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('person-form-category-dot')),
      );
      expect(
        (dot.decoration! as BoxDecoration).color,
        const Color(0xFFFF0000),
        reason: "the dot carries the category's own colour",
      );
    });
  });

  group('adding channels from the address book', () {
    testWidgets('is not offered on a device without one', (tester) async {
      contactsService.supported = false;

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('person-form-add-channel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('person-form-add-from-contacts')),
        findsNothing,
      );
    });

    testWidgets("folds the picked contact's channels in as editable rows, "
        'saving nothing until the user does', (tester) async {
      contactsService
        ..supported = true
        ..picked = (
          id: 'os-1',
          displayName: 'Ada Lovelace',
          channels: const [
            ContactChannel(type: ContactChannelType.mobile, value: '+1 555'),
          ],
        );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('person-form-add-from-contacts')),
      );
      await tester.pumpAndSettle();

      expect(contactsService.pickCalls, 1);
      expect(find.text('+1 555'), findsOneWidget);
      // Picking is not saving: the person is written only on Save.
      verifyNever(() => mockRepository.updateRelationship(any()));
      verifyNever(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });

    testWidgets('judges sameness the way the model does, so a formatted '
        'number and its bare form are one channel', (tester) async {
      contactsService
        ..supported = true
        ..picked = (
          id: 'os-1',
          displayName: 'Ada Lovelace',
          channels: const [
            // The same number the user typed, punctuated differently, plus an
            // email that reads like the number's digits but is another type.
            ContactChannel(
              type: ContactChannelType.mobile,
              value: '+1 (555) 010-9999',
            ),
            ContactChannel(
              type: ContactChannelType.email,
              value: 'ada@example.com',
            ),
          ],
        );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('person-form-add-channel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '+15550109999');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('person-form-add-from-contacts')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('person-form-add-from-contacts')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('+1 (555) 010-9999'),
        findsNothing,
        reason: 'the punctuated form is the number already typed',
      );
      expect(find.text('ada@example.com'), findsOneWidget);
    });

    testWidgets('adds nothing when the contact only repeats what is already '
        'typed', (tester) async {
      contactsService
        ..supported = true
        ..picked = (
          id: 'os-1',
          displayName: 'Ada Lovelace',
          channels: const [
            ContactChannel(type: ContactChannelType.mobile, value: '+1 555'),
          ],
        );

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('person-form-add-channel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '+1 555');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('person-form-add-from-contacts')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('person-form-add-from-contacts')),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1 555'), findsOneWidget);
    });
  });

  testWidgets('cadence defaults to none when nothing is picked', (
    tester,
  ) async {
    when(
      () => mockRepository.createRelationship(
        data: any(named: 'data'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (invocation) async => createdEntry(
        invocation.namedArguments[#data] as RelationshipData,
      ),
    );

    await tester.pumpWidget(buildForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ben');
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final data =
        verify(
              () => mockRepository.createRelationship(
                data: captureAny(named: 'data'),
                categoryId: any(named: 'categoryId'),
              ),
            ).captured.single
            as RelationshipData;
    expect(data.checkInCadenceDays, isNull);
    expect(data.important, isFalse);
    expect(data.nickname, isNull);
  });

  group('edit mode', () {
    RelationshipEntry existing({int? cadenceDays = 14}) => RelationshipEntry(
      meta: Metadata(
        id: 'rel-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: RelationshipData(
        title: 'Anna',
        nickname: 'Sis',
        important: true,
        checkInCadenceDays: cadenceDays,
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    );

    setUp(() {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
    });

    // Regression: every collaborator was pulled through `ref.read` *after*
    // awaiting the save. Saving pops the sheet, so on a slow write the element
    // was already gone and Riverpod threw "Using ref when a widget is about to
    // or has been unmounted is unsafe" — aborting the save's tail, with the
    // observed symptom "Failed to save relationship" and the agent (or the
    // category change) silently never written.
    testWidgets('finishes the save when the sheet unmounts mid-write', (
      tester,
    ) async {
      final saved = Completer<bool>();
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) => saved.future);
      when(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-1'));

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(DesignSystemButton, 'Save'),
      );
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
      await tester.pump();

      // The sheet disappears while the repository write is still in flight.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      saved.complete(true);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).called(1);
    });

    // The category lives on metadata, not the payload, so it takes a second
    // write through the journal path. Nothing else in this suite reaches that
    // branch, and it is the one the unmount crash aborted.
    testWidgets('routes a changed category through the journal repository', (
      tester,
    ) async {
      when(
        () => mockJournalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      // Drive the row's callback rather than its picker: the picker is a
      // nested modal with its own harness, and the branch under test is what
      // the form does with the chosen category.
      tester
          .widget<PersonCategoryRow>(find.byType(PersonCategoryRow))
          .onChanged('category-7');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(DesignSystemButton, 'Save'),
      );
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Save'));
      await tester.pumpAndSettle();

      verify(
        () => mockJournalRepository.updateCategoryId(
          'rel-1',
          categoryId: 'category-7',
        ),
      ).called(1);
    });

    testWidgets('prefills the person and saves edited fields', (tester) async {
      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      // Prefilled from the entity.
      expect(find.widgetWithText(TextField, 'Anna'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Sis'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.text('Monthly'));
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(updated.id, 'rel-1');
      expect(updated.data.title, 'Anna Example');
      expect(updated.data.checkInCadenceDays, 30);
      // Untouched fields survive the round-trip.
      expect(updated.data.nickname, 'Sis');
      expect(updated.data.important, isTrue);
      // Status untouched: same instance, no history entry.
      expect(updated.data.status.id, 'status-1');
      expect(updated.data.statusHistory, isEmpty);
    });

    testWidgets(
      'changing the status mints a new one and archives the old to history',
      (tester) async {
        await tester.pumpWidget(buildForm(initial: existing()));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Dormant'));
        await tester.tap(find.text('Dormant'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final updated =
            verify(
                  () => mockRepository.updateRelationship(captureAny()),
                ).captured.single
                as RelationshipEntry;
        expect(updated.data.status, isA<RelationshipDormant>());
        expect(updated.data.status.id, isNot('status-1'));
        expect(updated.data.statusHistory, hasLength(1));
        expect(updated.data.statusHistory.single.id, 'status-1');
      },
    );

    testWidgets('does not persist when the name is cleared', (tester) async {
      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepository.updateRelationship(any()));
    });

    testWidgets('archiving mints an archived status', (tester) async {
      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Archived'));
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          verify(
                () => mockRepository.updateRelationship(captureAny()),
              ).captured.single
              as RelationshipEntry;
      expect(updated.data.status, isA<RelationshipArchived>());
      expect(updated.data.statusHistory.single.id, 'status-1');
    });

    testWidgets(
      "the picker opens on the person's current kind, so an untouched save "
      'keeps it',
      (tester) async {
        final kinds = <String, RelationshipStatus>{
          'status-dormant': RelationshipStatus.dormant(
            id: 'status-dormant',
            createdAt: testDate,
            utcOffset: 0,
          ),
          'status-archived': RelationshipStatus.archived(
            id: 'status-archived',
            createdAt: testDate,
            utcOffset: 0,
          ),
        };

        for (final entry in kinds.entries) {
          final base = existing();
          await tester.pumpWidget(
            buildForm(
              initial: base.copyWith(
                data: base.data.copyWith(status: entry.value),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Save'));
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          final updated =
              verify(
                    () => mockRepository.updateRelationship(captureAny()),
                  ).captured.single
                  as RelationshipEntry;
          // The kind round-tripped rather than resetting to active, so no
          // new status was minted and nothing was pushed to history.
          expect(updated.data.status.id, entry.key, reason: entry.key);
          expect(updated.data.statusHistory, isEmpty, reason: entry.key);

          // Pumping a fresh tree next round would hit the popped navigator.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('a refused update reports it and keeps the edits', (
      tester,
    ) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Anna Example');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Anna Example'),
        findsOneWidget,
      );
    });

    testWidgets('an update that throws reports the edit-mode failure', (
      tester,
    ) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenThrow(Exception('db gone'));

      await tester.pumpWidget(buildForm(initial: existing()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The edit-mode copy, not the create-mode one.
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.text('Could not save this person. Please try again.'),
        findsNothing,
      );
    });
  });

  group('error toasts', () {
    testWidgets('shows a toast when create returns null', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save this person. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when create throws', (tester) async {
      when(
        () => mockRepository.createRelationship(
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anna');
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save this person. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update returns false', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      final initial = RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: RelationshipData(
          title: 'Anna',
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });

    testWidgets('shows a toast when update throws', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenThrow(Exception('db locked'));

      final initial = RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: RelationshipData(
          title: 'Anna',
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      await tester.pumpWidget(buildForm(initial: initial));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });
  });

  group('the category leg of an edit', () {
    /// A person filed under `cat-1`, so the row renders that category.
    RelationshipEntry categorized() {
      when(() => mockCacheService.getCategoryById('cat-1')).thenReturn(
        CategoryDefinition(
          id: 'cat-1',
          name: 'Family',
          private: false,
          active: true,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
      return RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: 'cat-1',
        ),
        data: RelationshipData(
          title: 'Anna',
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );
    }

    /// Clears the category the way the picker reports a cleared choice,
    /// then saves.
    Future<void> clearCategoryAndSave(WidgetTester tester) async {
      await tester.pumpWidget(buildForm(initial: categorized()));
      await tester.pumpAndSettle();

      tester
          .widget<PersonCategoryRow>(find.byType(PersonCategoryRow))
          .onChanged(null);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('routes the cleared category through the journal path — a '
        'freezed copyWith cannot null the field', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);

      await clearCategoryAndSave(tester);

      verify(
        () => mockJournalRepository.updateCategoryId('rel-1', categoryId: null),
      ).called(1);
      expect(
        find.text('Could not save the changes. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('a failed category write is reported instead of being '
        'swallowed — the payload landed but the category did not, and '
        'reporting success would leave nothing to retry', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => false);

      await clearCategoryAndSave(tester);

      expect(
        find.text('Could not save the changes. Please try again.'),
        findsOne,
      );
    });

    testWidgets('the agent is still wired when only the category leg '
        'failed — importance and cadence did persist', (tester) async {
      when(
        () => mockRepository.updateRelationship(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).thenAnswer((_) async => throw StateError('unstubbed identity'));

      await tester.pumpWidget(buildForm(initial: categorized()));
      await tester.pumpAndSettle();

      tester
          .widget<PersonCategoryRow>(find.byType(PersonCategoryRow))
          .onChanged(null);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => mockAgentService.ensureAgentForRelationship(any()),
      ).called(1);
    });
  });
}
