import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/task_card.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:lotti/widgets/cards/modern_card_content.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/task_progress_test_controller.dart';
import '../../../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool originalIsDesktop;
  late bool originalIsMobile;

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    originalIsDesktop = platform.isDesktop;
    originalIsMobile = platform.isMobile;

    // Minimal registrations needed by ModernTaskCard children
    getIt.registerSingleton<TimeService>(TimeService());

    // Mock EntitiesCacheService so CategoryIconCompact can query it safely
    final mockCache = MockEntitiesCacheService();
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    getIt.registerSingleton<EntitiesCacheService>(mockCache);
  });

  tearDown(() async {
    platform.isDesktop = originalIsDesktop;
    platform.isMobile = originalIsMobile;
    await getIt.reset();
  });

  Task buildTask({String? categoryId}) {
    final now = DateTime(2025, 11, 3, 12);
    final meta = Metadata(
      id: 'task-1',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: categoryId,
    );
    final data = TaskData(
      status: TaskStatus.groomed(
        id: 'status-1',
        createdAt: now,
        utcOffset: 0,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Test Task Title',
      priority: TaskPriority.p3Low,
    );
    return Task(meta: meta, data: data);
  }

  testWidgets('renders category icon after status chip', (tester) async {
    final task = buildTask();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    // Rebuild with the real widget under test to ensure ProviderScope is present
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );

    // Find the Row that contains the chips (priority/status row)
    final rowFinder = find.byKey(const Key('task_status_row'));
    expect(rowFinder, findsOneWidget);
    final row = tester.widget<Row>(rowFinder);

    // Verify order: [ModernStatusChip(priority), SizedBox, ModernStatusChip(status), SizedBox, CategoryIconCompact]
    expect(row.children[0], isA<ModernStatusChip>());
    expect(row.children[1], isA<SizedBox>());
    expect(row.children[2], isA<ModernStatusChip>());
    expect(row.children[3], isA<SizedBox>());
    expect(row.children[4], isA<CategoryIconCompact>());
  });

  testWidgets('no leading ModernIconContainer remains in ModernCardContent',
      (tester) async {
    final task = buildTask();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );

    // Ensure ModernCardContent does not contain ModernIconContainer as a leading child
    expect(
      find.descendant(
        of: find.byType(ModernCardContent),
        matching: find.byType(ModernIconContainer),
      ),
      findsNothing,
    );
  });

  testWidgets('inline category icon has compact 24x24 size', (tester) async {
    final task = buildTask();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );

    final iconFinder = find.byType(CategoryIconCompact);
    expect(iconFinder, findsOneWidget);
    final size = tester.getSize(iconFinder.first);
    expect(size.width, 24);
    expect(size.height, 24);
  });

  testWidgets('shows due date icon when due is set', (tester) async {
    final now = DateTime(2025, 11, 3, 12);
    final task = buildTask().copyWith(
      data: buildTask().data.copyWith(due: now),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Due date branch should render an event icon
    expect(find.byIcon(Icons.event_rounded), findsOneWidget);
  });

  testWidgets('renders labels when labelIds are present', (tester) async {
    // Arrange labels in the cache
    final cache = getIt<EntitiesCacheService>() as MockEntitiesCacheService;
    final now = DateTime(2025, 11, 3, 12);
    final labelA = LabelDefinition(
      id: 'A',
      createdAt: now,
      updatedAt: now,
      name: 'Alpha',
      color: '#3366FF',
      vectorClock: null,
    );
    final labelB = LabelDefinition(
      id: 'B',
      createdAt: now,
      updatedAt: now,
      name: 'Beta',
      color: '#FF3366',
      vectorClock: null,
    );
    when(() => cache.getLabelById('A')).thenReturn(labelA);
    when(() => cache.getLabelById('B')).thenReturn(labelB);

    // Build a task with two labels
    final meta = buildTask().meta.copyWith(labelIds: ['A', 'B']);
    final task = buildTask().copyWith(meta: meta);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );

    // Two LabelChips should be rendered in the labels Wrap
    expect(find.byType(LabelChip), findsNWidgets(2));
  });

  testWidgets('status chip + icon reflect task status variants',
      (tester) async {
    Future<void> pumpWithStatus(TaskStatus status) async {
      final meta = buildTask().meta;
      final data = buildTask().data.copyWith(status: status);
      final task = Task(meta: meta, data: data);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
    }

    // Open
    await pumpWithStatus(TaskStatus.open(
      id: 's-open',
      createdAt: DateTime(2025),
      utcOffset: 0,
    ));
    expect(find.text('Open'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    // In Progress
    await pumpWithStatus(TaskStatus.inProgress(
      id: 's-ip',
      createdAt: DateTime(2025),
      utcOffset: 0,
    ));
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);

    // Blocked
    await pumpWithStatus(TaskStatus.blocked(
      id: 's-bl',
      createdAt: DateTime(2025),
      utcOffset: 0,
      reason: 'x',
    ));
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);

    // On Hold
    await pumpWithStatus(TaskStatus.onHold(
      id: 's-oh',
      createdAt: DateTime(2025),
      utcOffset: 0,
      reason: 'x',
    ));
    expect(find.text('On Hold'), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);

    // Done
    await pumpWithStatus(TaskStatus.done(
      id: 's-done',
      createdAt: DateTime(2025),
      utcOffset: 0,
    ));
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Rejected
    await pumpWithStatus(TaskStatus.rejected(
      id: 's-rej',
      createdAt: DateTime(2025),
      utcOffset: 0,
    ));
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
  });

  testWidgets('tapping the card navigates to task details', (tester) async {
    // Arrange NavService
    final nav = MockNavService();
    getIt.registerSingleton<NavService>(nav);
    when(() => nav.beamToNamed(any(), data: any(named: 'data')))
        .thenAnswer((_) {});

    final task = buildTask();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Test Task Title'));
    await tester.pumpAndSettle();

    // Assert
    verify(() => nav.beamToNamed('/tasks/task-1', data: any(named: 'data')))
        .called(1);
  });

  testWidgets('ModernTaskCard hides progress time text on mobile list cards',
      (tester) async {
    platform.isDesktop = false;
    platform.isMobile = true;

    final task = buildTask().copyWith(
      data: buildTask().data.copyWith(
            estimate: const Duration(hours: 1),
          ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskProgressControllerProvider(id: task.meta.id).overrideWith(
            () => TestTaskProgressController(
              progress: const Duration(minutes: 30),
              estimate: const Duration(hours: 1),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final progressFinder = find.byType(CompactTaskProgress);
    expect(progressFinder, findsOneWidget);

    final textFinder = find.descendant(
      of: progressFinder,
      matching: find.byType(Text),
    );
    expect(textFinder, findsNothing);
  });

  group('showCreationDate', () {
    // Use DateFormat to generate locale-independent expected date strings
    final taskDate = DateTime(2025, 11, 3, 12);
    final expectedTaskDateString = DateFormat.yMMMd().format(taskDate);

    testWidgets('does not show creation date when showCreationDate is false',
        (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The formatted date should NOT be present
      expect(find.text(expectedTaskDateString), findsNothing);
    });

    testWidgets('shows creation date when showCreationDate is true',
        (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
                showCreationDate: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The formatted date should be present (from dateFrom in buildTask)
      expect(find.text(expectedTaskDateString), findsOneWidget);
    });

    testWidgets('creation date is in the date row', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
                showCreationDate: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Row containing the date (date row layout)
      final rowFinder = find.ancestor(
        of: find.text(expectedTaskDateString),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);

      // Verify the date text is present
      expect(find.text(expectedTaskDateString), findsOneWidget);
    });

    testWidgets('showCreationDate defaults to false', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default should be false, so no date displayed
      expect(find.text(expectedTaskDateString), findsNothing);
    });

    testWidgets('creation date uses correct date format (yMMMd)',
        (tester) async {
      // Create a task with a specific date to verify format
      final testDate = DateTime(2024, 12, 25, 10);
      final expectedDateString = DateFormat.yMMMd().format(testDate);
      final meta = Metadata(
        id: 'task-date-format',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      final data = TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: const [],
        title: 'Date Format Test',
      );
      final task = Task(meta: meta, data: data);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
                showCreationDate: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Format should match yMMMd format for the locale
      expect(find.text(expectedDateString), findsOneWidget);
    });
  });

  group('showDueDate', () {
    testWidgets('does not show due date in date row when showDueDate is false',
        (tester) async {
      final dueDate = DateTime(2025, 11, 10);
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(due: dueDate),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
                showDueDate: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Due date should not be shown in date row when showDueDate is false
      expect(find.text(DateFormat.MMMd().format(dueDate)), findsNothing);
    });

    testWidgets('shows due date in date row when showDueDate is true',
        (tester) async {
      final dueDate = DateTime(2025, 11, 10);
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(due: dueDate),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Due date should be shown with event icon and "Due:" prefix
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(
        find.text('Due: ${DateFormat.yMMMd().format(dueDate)}'),
        findsOneWidget,
      );
    });

    testWidgets('showDueDate defaults to true', (tester) async {
      final dueDate = DateTime(2025, 11, 10);
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(due: dueDate),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default should show due date with "Due:" prefix
      expect(
        find.text('Due: ${DateFormat.yMMMd().format(dueDate)}'),
        findsOneWidget,
      );
    });

    testWidgets('does not show due date row when due is null', (tester) async {
      final task = buildTask(); // No due date set

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No event icon should be shown when there's no due date
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('shows creation date on LEFT and due date on RIGHT',
        (tester) async {
      final creationDate = DateTime(2025, 11, 3, 12);
      final dueDate = DateTime(2025, 11, 10);

      final meta = Metadata(
        id: 'task-1',
        createdAt: creationDate,
        updatedAt: creationDate,
        dateFrom: creationDate,
        dateTo: creationDate,
      );
      final data = TaskData(
        status: TaskStatus.open(id: 's', createdAt: creationDate, utcOffset: 0),
        dateFrom: creationDate,
        dateTo: creationDate,
        statusHistory: const [],
        title: 'Test',
        due: dueDate,
      );
      final task = Task(meta: meta, data: data);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
                showCreationDate: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both dates are present
      final creationDateText = DateFormat.yMMMd().format(creationDate);
      final dueDateText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';

      expect(find.text(creationDateText), findsOneWidget);
      expect(find.text(dueDateText), findsOneWidget);

      // Verify layout: creation date on left, due date on right
      final creationDateOffset = tester.getTopLeft(find.text(creationDateText));
      final dueDateOffset = tester.getTopLeft(find.text(dueDateText));

      expect(creationDateOffset.dx, lessThan(dueDateOffset.dx));
    });

    testWidgets('hides due date when task status is Done', (tester) async {
      final dueDate = DateTime(2025, 11, 10);
      final now = DateTime(2025, 11, 3, 12);
      final meta = Metadata(
        id: 'task-done',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      );
      final data = TaskData(
        status: TaskStatus.done(id: 's-done', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Completed Task',
        due: dueDate,
      );
      final task = Task(meta: meta, data: data);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Due date should NOT be shown for completed tasks
      expect(find.byIcon(Icons.event_rounded), findsNothing);
      expect(
        find.text('Due: ${DateFormat.yMMMd().format(dueDate)}'),
        findsNothing,
      );
    });

    testWidgets('hides due date when task status is Rejected', (tester) async {
      final dueDate = DateTime(2025, 11, 10);
      final now = DateTime(2025, 11, 3, 12);
      final meta = Metadata(
        id: 'task-rejected',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      );
      final data = TaskData(
        status:
            TaskStatus.rejected(id: 's-rejected', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Rejected Task',
        due: dueDate,
      );
      final task = Task(meta: meta, data: data);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Due date should NOT be shown for rejected tasks
      expect(find.byIcon(Icons.event_rounded), findsNothing);
      expect(
        find.text('Due: ${DateFormat.yMMMd().format(dueDate)}'),
        findsNothing,
      );
    });

    testWidgets('shows due date for non-completed task statuses',
        (tester) async {
      final dueDate = DateTime(2025, 11, 10);
      final now = DateTime(2025, 11, 3, 12);

      // Test with InProgress status (a non-completed status)
      final meta = Metadata(
        id: 'task-in-progress',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      );
      final data = TaskData(
        status: TaskStatus.inProgress(id: 's-ip', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'In Progress Task',
        due: dueDate,
      );
      final task = Task(meta: meta, data: data);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Due date SHOULD be shown for in-progress tasks
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(
        find.text('Due: ${DateFormat.yMMMd().format(dueDate)}'),
        findsOneWidget,
      );
    });

    testWidgets(
        'tapping due date toggles between absolute and relative display',
        (tester) async {
      // Use a date 5 days in the future for testing relative display
      final now = DateTime.now();
      final dueDate = DateTime(now.year, now.month, now.day).add(
        const Duration(days: 5),
      );
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(due: dueDate),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows absolute date
      final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
      expect(find.text(absoluteText), findsOneWidget);

      // Tap to toggle to relative display
      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();

      // Now shows relative date ("Due in 5 days")
      expect(find.text(absoluteText), findsNothing);
      expect(find.textContaining('5'), findsOneWidget);

      // Tap again to toggle back to absolute
      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();

      // Back to absolute
      expect(find.text(absoluteText), findsOneWidget);
    });
  });

  group('showCoverArt', () {
    testWidgets('showCoverArt defaults to true', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With no cover art set, should render normally regardless of showCoverArt
      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('renders without thumbnail when task has no coverArtId',
        (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should not have CoverArtThumbnail since there's no coverArtId
      expect(find.text('Test Task Title'), findsOneWidget);
      expect(find.byType(CoverArtThumbnail), findsNothing);
    });

    testWidgets('showCoverArt=false hides thumbnail even with coverArtId',
        (tester) async {
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(coverArtId: 'image-123'),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(
                task: task,
                showCoverArt: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should still be visible
      expect(find.text('Test Task Title'), findsOneWidget);
      // The layout should not include the cover art thumbnail
      // (since showCoverArt is false)
      expect(find.byType(CoverArtThumbnail), findsNothing);
    });

    testWidgets('coverArtCropX defaults to 0.5', (tester) async {
      final task = buildTask();

      // Verify the default cropX value
      expect(task.data.coverArtCropX, 0.5);
    });

    testWidgets(
        'renders CoverArtThumbnail when showCoverArt=true with coverArtId',
        (tester) async {
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(coverArtId: 'image-123'),
      );

      // Create a fake image entry for the thumbnail
      final now = DateTime(2025, 11, 3, 12);
      final image = JournalImage(
        meta: Metadata(
          id: 'image-123',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: ImageData(
          imageId: 'img-uuid',
          imageFile: 'test.jpg',
          imageDirectory: '/test/dir',
          capturedAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'image-123').overrideWith(
              () => _FakeImageController(image),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have CoverArtThumbnail since showCoverArt defaults to true
      expect(find.byType(CoverArtThumbnail), findsOneWidget);
    });

    testWidgets('cover art layout has correct structure', (tester) async {
      final task = buildTask().copyWith(
        data: buildTask().data.copyWith(coverArtId: 'image-123'),
      );

      final now = DateTime(2025, 11, 3, 12);
      final image = JournalImage(
        meta: Metadata(
          id: 'image-123',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: ImageData(
          imageId: 'img-uuid',
          imageFile: 'test.jpg',
          imageDirectory: '/test/dir',
          capturedAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'image-123').overrideWith(
              () => _FakeImageController(image),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ModernTaskCard(task: task),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should still be visible
      expect(find.text('Test Task Title'), findsOneWidget);

      // Should have ClipRRect for rounded corners on thumbnail
      expect(find.byType(ClipRRect), findsWidgets);
    });
  });
}

/// Simple fake controller for image entries
class _FakeImageController extends EntryController {
  _FakeImageController(this._image);

  final JournalImage _image;

  @override
  Future<EntryState?> build({required String id}) async {
    final value = EntryState.saved(
      entryId: id,
      entry: _image,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
    state = AsyncData(value);
    return value;
  }
}
