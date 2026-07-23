import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  late MockNavService mockNavService;

  setUp(() {
    mockNavService = MockNavService();
    getIt.registerSingleton<NavService>(mockNavService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  LinkedTaskRowData buildRowData({
    String? caption,
    LinkDirection direction = LinkDirection.outgoing,
  }) => LinkedTaskRowData(
    task: TestTaskFactory.create(id: 'other-task', title: 'Other Task'),
    direction: direction,
    caption: caption,
  );

  group('LinkedTaskRow', () {
    testWidgets('renders the direction glyph and caption when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LinkedTaskRow(
            taskId: 'anchor-task',
            data: buildRowData(caption: 'to'),
            manageMode: false,
          ),
        ),
      );

      expect(find.text('to'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Other Task'), findsOneWidget);
    });

    testWidgets('omits the direction glyph and caption when caption is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LinkedTaskRow(
            taskId: 'anchor-task',
            data: buildRowData(),
            manageMode: false,
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('Other Task'), findsOneWidget);
    });

    testWidgets(
      'shows the plain chevron in manage mode when onUnlink is null',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              taskId: 'anchor-task',
              data: buildRowData(),
              manageMode: true,
            ),
          ),
        );

        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
      },
    );

    testWidgets(
      'shows the unlink button in manage mode when onUnlink is supplied',
      (tester) async {
        var unlinkCalled = false;
        await tester.pumpWidget(
          WidgetTestBench(
            child: LinkedTaskRow(
              taskId: 'anchor-task',
              data: buildRowData(),
              manageMode: true,
              onUnlink: () => unlinkCalled = true,
            ),
          ),
        );

        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirmation dialog gates the callback.
        expect(unlinkCalled, isFalse);
        await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(unlinkCalled, isTrue);
      },
    );

    testWidgets('cancelling the unlink dialog does not invoke onUnlink', (
      tester,
    ) async {
      var unlinkCalled = false;
      await tester.pumpWidget(
        WidgetTestBench(
          child: LinkedTaskRow(
            taskId: 'anchor-task',
            data: buildRowData(),
            manageMode: true,
            onUnlink: () => unlinkCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(unlinkCalled, isFalse);
    });

    testWidgets('tapping the row in browse mode navigates to the other task', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          // Desktop sizing routes navigation through NavService instead of
          // pushing TaskDetailsPage onto the navigator.
          mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
          child: LinkedTaskRow(
            taskId: 'anchor-task',
            data: buildRowData(),
            manageMode: false,
          ),
        ),
      );

      await tester.tap(find.text('Other Task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => mockNavService.pushDesktopTaskDetail('other-task'),
      ).called(1);
    });

    testWidgets('row tap is disabled in manage mode', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
          child: LinkedTaskRow(
            taskId: 'anchor-task',
            data: buildRowData(),
            manageMode: true,
          ),
        ),
      );

      final rowInkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(rowInkWell.onTap, isNull);
    });
  });

  group('StatusGlyph', () {
    testWidgets('renders an icon colored for the given status', (
      tester,
    ) async {
      final status = TaskStatus.done(
        id: 's-done',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );

      await tester.pumpWidget(
        WidgetTestBench(child: StatusGlyph(status: status)),
      );

      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
