import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/task_compact_app_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Task buildTask({String id = 'task-1'}) {
    final now = DateTime(2025, 12, 31, 12);
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
      ),
    );
  }

  Widget buildTestWidget(Task task) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              TaskCompactAppBar(task: task),
            ],
          ),
        ),
      ),
    );
  }

  group('TaskCompactAppBar', () {
    testWidgets('renders SliverAppBar', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders back button with chevron_left icon', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('renders more_horiz action button', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('contains GlassIconContainer for AI menu', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      expect(find.byType(GlassIconContainer), findsOneWidget);
    });

    testWidgets('SliverAppBar is pinned', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.pinned, isTrue);
    });

    testWidgets('SliverAppBar has correct toolbarHeight', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.toolbarHeight, 45);
    });

    testWidgets('SliverAppBar has correct leadingWidth', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.leadingWidth, 100);
    });

    testWidgets('does not automatically imply leading', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('has no expandedHeight (compact)', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(buildTestWidget(task));
      await tester.pumpAndSettle();

      final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(appBar.expandedHeight, isNull);
    });
  });
}
