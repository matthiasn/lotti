import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late StreamController<Set<String>> updateStreamController;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockEntitiesCacheService = MockEntitiesCacheService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => updateStreamController.stream,
    );
    when(
      () => mockJournalDb.getHabitById(habitFlossing.id),
    ).thenAnswer((_) async => habitFlossing);
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(null);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() async {
    await updateStreamController.close();
    await getIt.reset();
  });

  Future<void> pumpSummary(
    WidgetTester tester, {
    bool showIcon = false,
    bool showText = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitSummary(
          testHabitCompletionEntry,
          showIcon: showIcon,
          showText: showText,
        ),
      ),
    );
    // Deliver the first fetch result from the notification-driven stream.
    await tester.pump();
  }

  group('HabitSummary', () {
    testWidgets('renders nothing while the habit definition is unknown', (
      tester,
    ) async {
      when(
        () => mockJournalDb.getHabitById(habitFlossing.id),
      ).thenAnswer((_) async => null);

      await pumpSummary(tester);

      expect(find.textContaining('Habit completed'), findsNothing);
      expect(find.byType(TextViewerWidget), findsNothing);
    });

    testWidgets('renders habit name without icon by default', (tester) async {
      await pumpSummary(tester);

      expect(find.text('Habit completed: Flossing'), findsOneWidget);
      expect(find.byType(CategoryIconCompact), findsNothing);
      // showText defaults to true and the entry has text.
      expect(find.byType(TextViewerWidget), findsOneWidget);
    });

    testWidgets('shows the category icon when showIcon is true', (
      tester,
    ) async {
      await pumpSummary(tester, showIcon: true);

      expect(find.byType(CategoryIconCompact), findsOneWidget);
    });

    testWidgets('hides the entry text when showText is false', (tester) async {
      await pumpSummary(tester, showText: false);

      expect(find.text('Habit completed: Flossing'), findsOneWidget);
      expect(find.byType(TextViewerWidget), findsNothing);
    });

    testWidgets('refetches and rebuilds when a habits notification fires', (
      tester,
    ) async {
      await pumpSummary(tester);
      expect(find.text('Habit completed: Flossing'), findsOneWidget);

      // The habit is renamed; a habitsNotification must trigger a refetch.
      when(() => mockJournalDb.getHabitById(habitFlossing.id)).thenAnswer(
        (_) async => habitFlossing.copyWith(name: 'Flossing nightly'),
      );
      updateStreamController.add({habitsNotification});
      await tester.pump();
      await tester.pump();

      expect(find.text('Habit completed: Flossing nightly'), findsOneWidget);
    });
  });
}
