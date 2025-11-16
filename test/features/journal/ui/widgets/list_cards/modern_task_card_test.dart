import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_task_card.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:lotti/widgets/cards/modern_card_content.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:mocktail/mocktail.dart';

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
          home: Scaffold(
            body: ModernTaskCard(task: task),
          ),
        ),
      ),
    );

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

  testWidgets(
      'ModernTaskCard hides progress time text on mobile list cards',
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
            () => _TestProgressController(
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
}

class _TestProgressController extends TaskProgressController {
  _TestProgressController({
    required this.progress,
    required this.estimate,
  });

  final Duration progress;
  final Duration estimate;

  @override
  Future<TaskProgressState?> build({required String id}) async {
    return TaskProgressState(
      progress: progress,
      estimate: estimate,
    );
  }
}
