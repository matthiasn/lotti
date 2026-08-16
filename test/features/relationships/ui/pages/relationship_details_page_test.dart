import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);

  late MockRelationshipRepository mockRepository;
  late MockUpdateNotifications mockNotifications;

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
  );

  RelationshipEntry relationship({
    bool important = false,
    int? cadenceDays,
    List<ContactChannel> contactChannels = const [],
  }) => RelationshipEntry(
    meta: meta('rel-1'),
    data: RelationshipData(
      title: 'Anna',
      nickname: 'Sis',
      important: important,
      checkInCadenceDays: cadenceDays,
      contactChannels: contactChannels,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  Task task(String id, {String title = 'Prepare the call'}) =>
      JournalEntity.task(
            meta: meta(id),
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

  setUp(() {
    mockRepository = MockRelationshipRepository();
    mockNotifications = MockUpdateNotifications();
    getIt.registerSingleton<UpdateNotifications>(mockNotifications);
    // Most tests exercise other sections; linked tasks default to empty.
    when(
      () => mockRepository.getLinkedTasks('rel-1'),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await getIt.unregister<UpdateNotifications>();
  });

  Widget buildPage() => ProviderScope(
    overrides: [
      relationshipRepositoryProvider.overrideWithValue(mockRepository),
    ],
    child: MaterialApp(
      theme: resolveTestTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RelationshipDetailsPage(relationshipId: 'rel-1'),
    ),
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
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
      expect(find.text('Planned the summer trip.'), findsOneWidget);
    },
  );

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
    expect(find.byIcon(Icons.star_rounded), findsNothing);
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
    when(() => mockRepository.getRelationshipById('rel-1')).thenAnswer(
      (_) async => relationship(cadenceDays: 14),
    );
    when(
      () => mockRepository.getCheckInsForRelationship('rel-1'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_rounded));
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

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Confirmation modal names the person; nothing deleted before consent.
      expect(find.text('Delete Anna?'), findsOneWidget);
      verifyNever(() => mockRepository.deleteRelationship(any()));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.deleteRelationship('rel-1')).called(1);
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

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
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

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete this person. Please try again.'),
        findsOne,
      );
    },
  );

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
    expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
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

      await tester.tap(find.byIcon(Icons.link_off_rounded));
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

    await tester.tap(find.byIcon(Icons.link_off_rounded));
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
  });
}
