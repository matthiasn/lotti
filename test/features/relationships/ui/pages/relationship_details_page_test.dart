import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockRelationshipAgentService mockAgentService;
  late MockRelationshipReminderService mockReminders;
  late MockUpdateNotifications mockNotifications;
  // The post-interaction prompt mounted on this page reads the device-local
  // marker, which lives in settings. A real in-memory db is simpler than a
  // mock here and keeps the prompt's "no marker → renders nothing" default.
  late SettingsDb settingsDb;

  Metadata meta(String id, {String? categoryId, bool? private}) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: categoryId,
    private: private,
  );

  RelationshipEntry relationship({
    bool important = false,
    int? cadenceDays,
    RelationshipStatus? status,
    List<ContactChannel> contactChannels = const [],
    String? categoryId,
    bool? private,
  }) => RelationshipEntry(
    meta: meta('rel-1', categoryId: categoryId, private: private),
    data: RelationshipData(
      title: 'Anna',
      nickname: 'Sis',
      important: important,
      checkInCadenceDays: cadenceDays,
      contactChannels: contactChannels,
      status:
          status ??
          RelationshipStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
    ),
  );

  Task task(
    String id, {
    String title = 'Prepare the call',
    String? categoryId,
  }) =>
      JournalEntity.task(
            meta: meta(id, categoryId: categoryId),
            data: TaskData(
              status: TaskStatus.open(
                id: 'ts-$id',
                createdAt: testDate,
                utcOffset: 0,
              ),
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: const [],
              title: title,
            ),
          )
          as Task;

  CheckInEntry checkIn(
    String id, {
    CheckInSentiment? sentiment,
    List<String> topics = const [],
    String? narrative,
  }) => CheckInEntry(
    meta: meta(id),
    data: CheckInData(
      relationshipId: 'rel-1',
      interactionType: CheckInInteractionType.call,
      sentiment: sentiment,
      topics: topics,
    ),
    entryText: narrative == null ? null : EntryText(plainText: narrative),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepository = MockRelationshipRepository();
    mockNotifications = MockUpdateNotifications();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    getIt
      ..registerSingleton<UpdateNotifications>(mockNotifications)
      ..registerSingleton<SettingsDb>(settingsDb);
    // Most tests exercise other sections; linked tasks default to empty.
    when(
      () => mockRepository.getLinkedTasks('rel-1'),
    ).thenAnswer((_) async => []);
    mockAgentService = MockRelationshipAgentService();
    when(
      () => mockAgentService.handleRelationshipDeleted(any()),
    ).thenAnswer((_) async => true);
    mockReminders = MockRelationshipReminderService();
    when(() => mockReminders.clearFor(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await getIt.unregister<UpdateNotifications>();
    await getIt.unregister<SettingsDb>();
    await settingsDb.close();
  });

  Widget buildPage({List<Override> overrides = const []}) =>
      makeTestableWidgetNoScroll(
        const RelationshipDetailsPage(relationshipId: 'rel-1'),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(mockRepository),
          relationshipAgentServiceProvider.overrideWithValue(mockAgentService),
          relationshipReminderServiceProvider.overrideWithValue(mockReminders),
          ...overrides,
        ],
      );

  testWidgets(
    'renders header chips (status, cadence, nickname) and check-in rows',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(important: true, cadenceDays: 14),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer(
        (_) async => [
          checkIn(
            'check-1',
            sentiment: CheckInSentiment.good,
            topics: ['travel'],
            narrative: 'Planned the summer trip.',
          ),
        ],
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Every two weeks'), findsOneWidget);
      expect(find.text('Sis'), findsOneWidget);
      expect(find.byIcon(LottiIcons.star), findsOneWidget);

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
      expect(find.text('Planned the summer trip.'), findsOneWidget);
    },
  );

  testWidgets(
    'a synced cadence outside the presets reads as "every N days" rather '
    'than being rounded into one',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(cadenceDays: 3),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Every 3 days'), findsOneWidget);
      expect(find.text('Weekly'), findsNothing);
    },
  );

  testWidgets('the status chip names every status kind', (tester) async {
    final statuses = <String, RelationshipStatus>{
      'Active': RelationshipStatus.active(
        id: 'st-a',
        createdAt: testDate,
        utcOffset: 0,
      ),
      'Dormant': RelationshipStatus.dormant(
        id: 'st-d',
        createdAt: testDate,
        utcOffset: 0,
      ),
      'Archived': RelationshipStatus.archived(
        id: 'st-r',
        createdAt: testDate,
        utcOffset: 0,
      ),
    };
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    for (final entry in statuses.entries) {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(status: entry.value),
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      for (final other in statuses.keys.where((k) => k != entry.key)) {
        expect(
          find.text(other),
          findsNothing,
          reason: '$other vs ${entry.key}',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('renders the no-check-ins hint when the log is empty', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      find.text('No check-ins yet — log one after you next talk.'),
      findsOneWidget,
    );
    // No star in the app bar for an unimportant relationship.
    expect(find.byIcon(LottiIcons.star), findsNothing);
  });

  testWidgets('says the person is no longer tracked when the id is gone — '
      'a synced delete is not an error', (tester) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => null,
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('This person is no longer tracked.'), findsOneWidget);
    expect(find.text('Error'), findsNothing);
  });

  testWidgets('shows the error text when loading actually fails', (
    tester,
  ) async {
    when(
      () => mockRepository.getRelationshipById('rel-1'),
    ).thenThrow(Exception('db gone'));

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('edit action opens the form prefilled with the person', (
    tester,
  ) async {
    // The form's CategoryField resolves the category name through getIt.
    final cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    getIt.registerSingleton<EntitiesCacheService>(cache);
    addTearDown(() => getIt.unregister<EntitiesCacheService>());
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(cadenceDays: 14),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LottiIcons.edit));
    await tester.pumpAndSettle();

    // Prefilled name and nickname fields, and the edit-only status picker.
    expect(
      find.widgetWithText(TextField, 'Anna'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Sis'),
      findsOneWidget,
    );
    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets(
    'delete action confirms, cascades through the repository, and beams '
    'back to the list',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.deleteRelationship('rel-1'),
      ).thenAnswer((_) async => true);

      final beamedTo = <String>[];
      beamToNamedOverride = beamedTo.add;
      addTearDown(() => beamToNamedOverride = null);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();

      // Confirmation modal names the person; nothing deleted before consent.
      expect(find.text('Delete Anna?'), findsOneWidget);
      verifyNever(() => mockRepository.deleteRelationship(any()));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.deleteRelationship('rel-1')).called(1);
      // The cascade's agent leg fires exactly once (ADR 0059 Decision 7).
      verify(
        () => mockAgentService.handleRelationshipDeleted('rel-1'),
      ).called(1);
      // ...and its reminder leg (ADR 0037 §5). This cannot be left to the
      // next Phase A tick: destroying the agent is what stops those ticks, so
      // an alarm armed weeks ago would otherwise still fire, naming someone
      // the user deleted.
      verify(() => mockReminders.clearFor('rel-1')).called(1);
      expect(beamedTo, ['/people']);
    },
  );

  testWidgets(
    'a failed agent teardown never fails the delete the user watched '
    'succeed',
    (tester) async {
      when(
        () => mockRepository.getRelationshipById('rel-1'),
      ).thenAnswer((_) async => relationship());
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.deleteRelationship('rel-1'),
      ).thenAnswer((_) async => true);
      when(
        () => mockAgentService.handleRelationshipDeleted(any()),
      ).thenAnswer((_) async => throw StateError('agent db closed'));

      final beamedTo = <String>[];
      beamToNamedOverride = beamedTo.add;
      addTearDown(() => beamToNamedOverride = null);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(beamedTo, ['/people']);
    },
  );

  testWidgets(
    'delete shows an error toast when the repository returns false',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.deleteRelationship('rel-1'),
      ).thenAnswer((_) async => false);

      final beamedTo = <String>[];
      beamToNamedOverride = beamedTo.add;
      addTearDown(() => beamToNamedOverride = null);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete this person. Please try again.'),
        findsOne,
      );
      // Crucially: no navigation away from a person who still exists.
      expect(beamedTo, isEmpty);
      expect(find.text('Anna'), findsOneWidget);
    },
  );

  testWidgets(
    'delete shows an error toast when the repository throws',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.deleteRelationship('rel-1'),
      ).thenThrow(Exception('db locked'));

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LottiIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete this person. Please try again.'),
        findsOne,
      );
    },
  );

  testWidgets(
    'the log-check-in FAB is the design-system primary action, labelled and '
    'painted in the interactive accent — not a neutral Material pill',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final fab = find.byKey(
        const ValueKey('relationship-log-check-in-fab'),
      );
      expect(fab, findsOneWidget);
      expect(
        find.byType(FloatingActionButton),
        findsNothing,
        reason: 'the Material default carried the wrong colour',
      );

      final button = tester.widget<DesignSystemFloatingActionButton>(fab);
      expect(button.label, 'Log check-in');
      expect(button.icon, LottiIcons.greeting);

      final tokens = tester.element(fab).designTokens;
      final ink = tester.widget<Ink>(
        find.descendant(of: fab, matching: find.byType(Ink)),
      );
      expect(
        (ink.decoration! as BoxDecoration).color,
        tokens.colors.interactive.enabled,
        reason: 'same accent as Link task and every other primary action',
      );
    },
  );

  testWidgets(
    'check-in topics render as the design-system tag pill, the same read-out '
    'shell labels wear elsewhere',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer(
        (_) async => [
          checkIn('check-1', topics: ['design tokens', 'Figma']),
        ],
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      final pills = tester
          .widgetList<DsPill>(find.byType(DsPill))
          .where((pill) => pill.shape == DsPillShape.tag)
          .toList();
      expect(pills.map((pill) => pill.label), ['design tokens', 'Figma']);
      for (final pill in pills) {
        expect(pill.variant, DsPillVariant.filled);
        expect(
          pill.bordered,
          isTrue,
          reason: 'the hairline is what separates a tag from bare text',
        );
      }
      expect(
        find.descendant(of: find.byType(Card), matching: find.byType(Chip)),
        findsNothing,
        reason: 'topics were the last Material Chip on the check-in row',
      );
    },
  );

  testWidgets('the FAB opens the check-in capture sheet for this person', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);
    when(
      () => mockRepository.createCheckIn(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
      ),
    ).thenAnswer((_) async => checkIn('check-new'));

    // The capture sheet is taller than the default 800x600 surface, so its
    // Save button would sit off-screen and never receive the tap.
    setTestSurfaceSize(tester, const Size(1000, 1400));

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log check-in'));
    await tester.pumpAndSettle();

    // Create mode, titled for logging rather than editing.
    expect(find.text('How did you connect?'), findsOneWidget);
    expect(find.text('Edit check-in'), findsNothing);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The sheet saved against this page's relationship, not some other id.
    final data =
        verify(
              () => mockRepository.createCheckIn(
                data: captureAny(named: 'data'),
                entryText: any(named: 'entryText'),
                dateFrom: any(named: 'dateFrom'),
              ),
            ).captured.single
            as CheckInData;
    expect(data.relationshipId, 'rel-1');
  });

  testWidgets('each interaction type gets its own glyph on the check-in row', (
    tester,
  ) async {
    // The check-in log is a lazy sliver: all five rows must fit the
    // viewport at once for one-pass glyph assertions.
    setTestSurfaceSize(tester, const Size(1000, 1400));
    const glyphs = {
      CheckInInteractionType.inPerson: LottiIcons.people,
      CheckInInteractionType.call: LottiIcons.call,
      CheckInInteractionType.videoCall: LottiIcons.video,
      CheckInInteractionType.message: LottiIcons.chat,
      CheckInInteractionType.other: LottiIcons.forum,
    };

    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(() => mockRepository.getCheckInsForRelationship('rel-1')).thenAnswer(
      (_) async => [
        for (final type in glyphs.keys)
          CheckInEntry(
            meta: meta('check-${type.name}'),
            data: CheckInData(
              relationshipId: 'rel-1',
              interactionType: type,
            ),
          ),
      ],
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    for (final entry in glyphs.entries) {
      expect(
        find.byIcon(entry.value),
        findsOneWidget,
        reason: '${entry.key} row glyph',
      );
    }
  });

  testWidgets('tapping a check-in row opens the edit sheet prefilled', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer(
      (_) async => [
        checkIn('check-1', narrative: 'Planned the summer trip.'),
      ],
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Planned the summer trip.'));
    await tester.pumpAndSettle();

    // The edit sheet is up with the narrative prefilled in a text field
    // and the delete affordance that only edit mode carries.
    expect(find.text('Edit check-in'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Planned the summer trip.'),
      findsOneWidget,
    );
    // Exactly two: the page's own app-bar action, which was already there
    // before the sheet opened, plus the sheet's edit-only one. `findsWidgets`
    // here would pass on the app-bar icon alone and prove nothing.
    expect(find.byIcon(LottiIcons.delete), findsNWidgets(2));
  });

  testWidgets('renders contact channels with value and label', (tester) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(
        contactChannels: const [
          ContactChannel(
            type: ContactChannelType.email,
            value: 'anna@example.com',
            label: 'Personal',
          ),
          ContactChannel(
            type: ContactChannelType.mobile,
            value: '+49 151 1234567',
          ),
        ],
      ),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Contact channels'), findsOneWidget);
    expect(find.text('anna@example.com'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('+49 151 1234567'), findsOneWidget);
    // A channel without a label falls back to its localized type name.
    expect(find.text('Mobile'), findsOneWidget);
  });

  testWidgets(
    'renders linked tasks with localized status; empty state otherwise',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
      when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
        (_) async => [task('task-1')],
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Link task'), findsOneWidget);
      expect(find.text('Prepare the call'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('No tasks linked yet.'), findsNothing);
    },
  );

  testWidgets('shows the linked-tasks empty state', (tester) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('No tasks linked yet.'), findsOneWidget);
  });

  testWidgets('tapping a linked task beams to the task', (tester) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);
    when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
      (_) async => [task('task-1')],
    );

    final beamedTo = <String>[];
    beamToNamedOverride = beamedTo.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prepare the call'));
    await tester.pumpAndSettle();

    expect(beamedTo, ['/tasks/task-1']);
  });

  testWidgets('uses the localized fallback for an untitled linked task', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);
    when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
      (_) async => [task('task-1', title: '')],
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('(untitled)'), findsOneWidget);

    await tester.tap(find.byIcon(LottiIcons.linkOff));
    await tester.pumpAndSettle();

    expect(
      find.text('Unlink “(untitled)”? The task itself is not deleted.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'unlink asks for confirmation and removes the link on consent',
    (tester) async {
      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
      when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
        (_) async => [task('task-1')],
      );
      when(
        () => mockRepository.unlinkTask(
          relationshipId: 'rel-1',
          taskId: 'task-1',
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LottiIcons.linkOff));
      await tester.pumpAndSettle();

      // Nothing removed before consent; the modal names the task.
      expect(
        find.textContaining('Prepare the call'),
        findsWidgets,
      );
      verifyNever(
        () => mockRepository.unlinkTask(
          relationshipId: any(named: 'relationshipId'),
          taskId: any(named: 'taskId'),
        ),
      );

      await tester.tap(find.text('Unlink Task'));
      await tester.pumpAndSettle();

      verify(
        () => mockRepository.unlinkTask(
          relationshipId: 'rel-1',
          taskId: 'task-1',
        ),
      ).called(1);
    },
  );

  testWidgets('unlink surfaces an error when the removal fails', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);
    when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
      (_) async => [task('task-1')],
    );
    when(
      () => mockRepository.unlinkTask(
        relationshipId: 'rel-1',
        taskId: 'task-1',
      ),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LottiIcons.linkOff));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink Task'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't unlink the task. Please try again."), findsOne);
  });

  testWidgets('unlink surfaces an error when the repository throws', (
    tester,
  ) async {
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);
    when(() => mockRepository.getLinkedTasks('rel-1')).thenAnswer(
      (_) async => [task('task-1')],
    );
    when(
      () => mockRepository.unlinkTask(
        relationshipId: 'rel-1',
        taskId: 'task-1',
      ),
    ).thenThrow(Exception('database unavailable'));

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LottiIcons.linkOff));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink Task'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't unlink the task. Please try again."), findsOne);
  });

  group('link task picker -', () {
    late MockJournalDb mockDb;
    late MockFts5Db mockFts5Db;
    late MockEntitiesCacheService mockCache;

    setUp(() {
      mockDb = MockJournalDb();
      mockFts5Db = MockFts5Db();
      mockCache = MockEntitiesCacheService();
      when(() => mockCache.sortedCategories).thenReturn([]);
      when(
        () => mockDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [task('task-2', title: 'Send the photos')]);
      when(
        () => mockFts5Db.watchFullTextMatches(any()),
      ).thenAnswer((_) => Stream.value(const <String>[]));

      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<EntitiesCacheService>(mockCache);

      when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
        (_) async => relationship(),
      );
      when(
        () => mockRepository.getCheckInsForRelationship('rel-1'),
      ).thenAnswer((_) async => []);
    });

    tearDown(() async {
      await getIt.unregister<JournalDb>();
      await getIt.unregister<Fts5Db>();
      await getIt.unregister<EntitiesCacheService>();
    });

    Future<void> pickTask(WidgetTester tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send the photos'));
      await tester.pumpAndSettle();
    }

    testWidgets('links the picked task and closes the picker', (tester) async {
      when(
        () => mockRepository.linkTask(
          relationshipId: 'rel-1',
          taskId: 'task-2',
        ),
      ).thenAnswer((_) async => true);

      await pickTask(tester);

      verify(
        () => mockRepository.linkTask(
          relationshipId: 'rel-1',
          taskId: 'task-2',
        ),
      ).called(1);
      expect(find.text('Send the photos'), findsNothing);
      expect(
        find.text('Could not link the task. Please try again.'),
        findsNothing,
      );
    });

    testWidgets(
      'surfaces an error when the link write changes no row — a silent '
      'close would read as a link that worked',
      (tester) async {
        when(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'task-2',
          ),
        ).thenAnswer((_) async => false);

        await pickTask(tester);

        expect(
          find.text('Could not link the task. Please try again.'),
          findsOne,
        );
      },
    );

    testWidgets('surfaces an error when the link repository throws', (
      tester,
    ) async {
      when(
        () => mockRepository.linkTask(
          relationshipId: 'rel-1',
          taskId: 'task-2',
        ),
      ).thenThrow(Exception('database unavailable'));

      await pickTask(tester);

      expect(
        find.text('Could not link the task. Please try again.'),
        findsOne,
      );
    });

    // The picker offers a create row once the query matches nothing, and
    // feeds whatever it creates back through the same pick callback that
    // links it. These cover what the page contributes to that: what the task
    // is created *as*, and that creating and linking stay one act.
    group('create task from the query -', () {
      late MockPersistenceLogic mockPersistence;
      late MockProjectRepository mockProjects;
      late MockTaskAgentService mockTaskAgents;

      final createdTask = task(
        'new-task',
        title: 'Buy flowers',
        categoryId: 'cat-1',
      );

      setUp(() {
        mockPersistence = MockPersistenceLogic();
        mockProjects = MockProjectRepository();
        mockTaskAgents = MockTaskAgentService();
        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistence)
          ..registerSingleton<ProjectRepository>(mockProjects);

        // This person lives in a category; a task created here inherits it.
        when(
          () => mockRepository.getRelationshipById('rel-1'),
        ).thenAnswer((_) async => relationship(categoryId: 'cat-1'));
        // The shared create path reads the person back to inherit privacy.
        when(
          () => mockDb.journalEntityById('rel-1'),
        ).thenAnswer((_) async => relationship(categoryId: 'cat-1'));
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        when(() => mockFts5Db.insertText(any())).thenAnswer((_) async {});
        // A person holds no project, so the inheritance the shared create
        // path attempts finds nothing. Stubbed rather than left to throw
        // inside a catch that would hide a real failure here.
        when(
          () => mockProjects.inheritProjectFromTask(
            sourceTaskId: any(named: 'sourceTaskId'),
            newTaskId: any(named: 'newTaskId'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'new-task',
          ),
        ).thenAnswer((_) async => true);
      });

      tearDown(() async {
        await getIt.unregister<PersistenceLogic>();
        await getIt.unregister<ProjectRepository>();
      });

      /// Answers the task write with [result], ignoring what it was asked.
      void stubWrite(Task? result) {
        when(
          () => mockPersistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            labelIds: any(named: 'labelIds'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((_) async => result);
      }

      /// Answers the write with [createdTask] and records the arguments, so a
      /// test can assert on the task that was created rather than on the mock
      /// call alone.
      Map<Symbol, dynamic> captureWrite() {
        final captured = <Symbol, dynamic>{};
        when(
          () => mockPersistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            labelIds: any(named: 'labelIds'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((invocation) async {
          captured.addAll(invocation.namedArguments);
          return createdTask;
        });
        return captured;
      }

      /// Opens the person's task picker, types [query] — which matches
      /// nothing here — and taps the create row that appears.
      Future<void> createFromQuery(
        WidgetTester tester, {
        String query = 'Buy flowers',
      }) async {
        await tester.pumpWidget(
          buildPage(
            overrides: [
              taskAgentServiceProvider.overrideWithValue(mockTaskAgents),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), query);
        await tester.pump(entityPickerSearchDebounce);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('link-picker-create')));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'the query becomes the title, so the task is never nameless',
        (tester) async {
          final written = captureWrite();

          await createFromQuery(tester);

          expect((written[#data] as TaskData).title, 'Buy flowers');
        },
      );

      testWidgets('the new task lands in the category the person is in', (
        tester,
      ) async {
        final written = captureWrite();

        await createFromQuery(tester);

        expect(written[#categoryId], 'cat-1');
      });

      testWidgets('a person with no category leaves the task uncategorized', (
        tester,
      ) async {
        when(
          () => mockRepository.getRelationshipById('rel-1'),
        ).thenAnswer((_) async => relationship());
        final written = captureWrite();

        await createFromQuery(tester);

        expect(written[#categoryId], isNull);
      });

      testWidgets('no plain link is written — the relationship edge is the '
          'only one', (tester) async {
        final written = captureWrite();

        await createFromQuery(tester);

        // A linkedId here would leave a basic link beside the typed one,
        // which this page would then have to unpick.
        expect(written[#linkedId], isNull);
        verify(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'new-task',
          ),
        ).called(1);
      });

      testWidgets('a private person gets a private task', (tester) async {
        when(() => mockDb.journalEntityById('rel-1')).thenAnswer(
          (_) async => relationship(categoryId: 'cat-1', private: true),
        );
        final written = captureWrite();

        await createFromQuery(tester);

        expect(written[#private], isTrue);
      });

      testWidgets('a public person does not make the task private', (
        tester,
      ) async {
        final written = captureWrite();

        await createFromQuery(tester);

        expect(written[#private], isNull);
      });

      testWidgets('creating links the task and closes the picker', (
        tester,
      ) async {
        stubWrite(createdTask);

        await createFromQuery(tester);

        verify(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'new-task',
          ),
        ).called(1);
        // The picker is gone: its search field went with it.
        expect(find.byType(TextField), findsNothing);
        expect(
          find.text('Could not link the task. Please try again.'),
          findsNothing,
        );
      });

      testWidgets('a write that returns nothing links nothing and keeps the '
          'picker open', (tester) async {
        stubWrite(null);

        await createFromQuery(tester);

        verifyNever(
          () => mockRepository.linkTask(
            relationshipId: any(named: 'relationshipId'),
            taskId: any(named: 'taskId'),
          ),
        );
        // Still on the picker, so the user can retype or pick something else
        // instead of landing back on the page with nothing to show for it.
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('a link that changes no row still reports the failure after '
          'a create', (tester) async {
        stubWrite(createdTask);
        when(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'new-task',
          ),
        ).thenAnswer((_) async => false);

        await createFromQuery(tester);

        expect(
          find.text('Could not link the task. Please try again.'),
          findsOne,
        );
      });

      testWidgets('the created task gets the default agent of its category, '
          'like every other create flow', (tester) async {
        stubWrite(createdTask);
        when(() => mockCache.getCategoryById('cat-1')).thenReturn(
          CategoryTestUtils.createTestCategory(
            id: 'cat-1',
            defaultTemplateId: 'tmpl-1',
            defaultProfileId: 'prof-1',
          ),
        );
        when(
          () => mockTaskAgents.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            setupOrigin: any(named: 'setupOrigin'),
            setupOriginEntityId: any(named: 'setupOriginEntityId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
            automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
          ),
        ).thenThrow(StateError('not asserted on the identity result'));

        await createFromQuery(tester);

        verify(
          () => mockTaskAgents.createTaskAgent(
            taskId: 'new-task',
            templateId: 'tmpl-1',
            profileId: 'prof-1',
            setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
            setupOriginEntityId: 'cat-1',
            allowedCategoryIds: {'cat-1'},
            awaitContent: any(named: 'awaitContent'),
            automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
          ),
        ).called(1);
      });

      testWidgets('a write that throws links nothing and keeps the picker '
          'open', (tester) async {
        when(
          () => mockPersistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            labelIds: any(named: 'labelIds'),
            private: any(named: 'private'),
          ),
        ).thenThrow(Exception('database unavailable'));

        await createFromQuery(tester);

        verifyNever(
          () => mockRepository.linkTask(
            relationshipId: any(named: 'relationshipId'),
            taskId: any(named: 'taskId'),
          ),
        );
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('a picker dismissed mid-write still links the task it just '
          'created', (tester) async {
        // Holds the write open so the picker can be closed while it is still
        // in flight — the race that would otherwise leave a created task
        // unlinked and unannounced.
        final write = Completer<Task?>();
        when(
          () => mockPersistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            labelIds: any(named: 'labelIds'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((_) => write.future);

        await tester.pumpWidget(
          buildPage(
            overrides: [
              taskAgentServiceProvider.overrideWithValue(mockTaskAgents),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Buy flowers');
        await tester.pump(entityPickerSearchDebounce);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('link-picker-create')));
        await tester.pump();

        // Gone before the write lands.
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);

        write.complete(createdTask);
        await tester.pumpAndSettle();

        verify(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'new-task',
          ),
        ).called(1);
      });

      testWidgets('a link that fails after the dismissal is still reported on '
          'the page', (tester) async {
        final write = Completer<Task?>();
        when(
          () => mockPersistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
            labelIds: any(named: 'labelIds'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((_) => write.future);
        when(
          () => mockRepository.linkTask(
            relationshipId: 'rel-1',
            taskId: 'new-task',
          ),
        ).thenThrow(Exception('database unavailable'));

        await tester.pumpWidget(
          buildPage(
            overrides: [
              taskAgentServiceProvider.overrideWithValue(mockTaskAgents),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Buy flowers');
        await tester.pump(entityPickerSearchDebounce);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('link-picker-create')));
        await tester.pump();
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();

        write.complete(createdTask);
        await tester.pumpAndSettle();

        // The picker is gone, but the page is back — and it is the page that
        // has to say the link never landed.
        expect(
          find.text('Could not link the task. Please try again.'),
          findsOne,
        );
      });

      testWidgets('a category without a default template creates no agent', (
        tester,
      ) async {
        stubWrite(createdTask);
        when(
          () => mockCache.getCategoryById('cat-1'),
        ).thenReturn(CategoryTestUtils.createTestCategory(id: 'cat-1'));

        await createFromQuery(tester);

        verifyNever(
          () => mockTaskAgents.createTaskAgent(
            taskId: any(named: 'taskId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      });
    });
  });

  testWidgets('a notification-triggered reload keeps the rendered detail on '
      'screen — the no-flash house rule, pinned', (tester) async {
    final updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    when(
      () => mockNotifications.updateStream,
    ).thenAnswer((_) => updates.stream);
    var calls = 0;
    final second = Completer<RelationshipEntry?>();
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer((_) {
      calls++;
      if (calls == 1) {
        return Future.value(relationship());
      }
      return second.future;
    });
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);

    updates.add({'rel-1'});
    await tester.pump();
    await tester.pump();

    // Mid-refetch: the rendered detail must stay, with no loading shell.
    expect(calls, 2, reason: 'the refetch fired');
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    second.complete(relationship());
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
  });
}
