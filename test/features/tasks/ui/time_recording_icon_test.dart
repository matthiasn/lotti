import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockTimeService mockTimeService;
  late StreamController<JournalEntity?> timerController;

  setUp(() {
    mockTimeService = MockTimeService();
    timerController = StreamController<JournalEntity?>.broadcast();
    when(mockTimeService.getStream).thenAnswer((_) => timerController.stream);
    when(() => mockTimeService.linkedFrom).thenReturn(null);

    getIt
      ..pushNewScope()
      ..registerSingleton<TimeService>(mockTimeService);
  });

  tearDown(() async {
    await timerController.close();
    await getIt.popScope();
  });

  Future<void> pumpIcon(WidgetTester tester, {required String taskId}) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(TimeRecordingIcon(taskId: taskId)),
    );
    await tester.pump();
  }

  group('TimeRecordingIcon', () {
    testWidgets('hidden when no timer is recording', (tester) async {
      await pumpIcon(tester, taskId: testTask.meta.id);

      expect(find.byType(ColorIcon), findsNothing);
    });

    testWidgets('shows the dot when the timer is linked to THIS task', (
      tester,
    ) async {
      when(() => mockTimeService.linkedFrom).thenReturn(testTask);

      await pumpIcon(tester, taskId: testTask.meta.id);

      expect(find.byType(ColorIcon), findsOneWidget);
    });

    testWidgets('hidden when the timer belongs to a DIFFERENT task', (
      tester,
    ) async {
      when(() => mockTimeService.linkedFrom).thenReturn(testTextEntry);

      await pumpIcon(tester, taskId: testTask.meta.id);

      expect(find.byType(ColorIcon), findsNothing);
    });

    testWidgets('stream events toggle the dot on and off', (tester) async {
      await pumpIcon(tester, taskId: testTask.meta.id);
      expect(find.byType(ColorIcon), findsNothing);

      // Timer starts for this task.
      when(() => mockTimeService.linkedFrom).thenReturn(testTask);
      timerController.add(testTextEntry);
      await tester.pump();
      await tester.pump();
      expect(find.byType(ColorIcon), findsOneWidget);

      // Timer stops again.
      when(() => mockTimeService.linkedFrom).thenReturn(null);
      timerController.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(ColorIcon), findsNothing);
    });
  });

  group('TimeRecordingIndicatorDot', () {
    testWidgets('always renders the dot', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(const TimeRecordingIndicatorDot()),
      );
      await tester.pump();

      expect(find.byType(ColorIcon), findsOneWidget);
    });
  });
}
