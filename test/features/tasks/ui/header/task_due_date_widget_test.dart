import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';

import '../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showDueDatePicker', () {
    testWidgets('displays date picker modal', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: DateTime(2025, 6, 15),
                    onDueDateChanged: (_) async {},
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal elements are shown
      expect(find.text('Due Date'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Sunday, June 15, 2025'), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });

    testWidgets('Close button dismisses modal without callback', (
      tester,
    ) async {
      var callbackCalled = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: DateTime(2025, 6, 15),
                    onDueDateChanged: (_) async {
                      callbackCalled = true;
                    },
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(callbackCalled, isFalse);
      expect(find.text('Due Date'), findsNothing);
    });

    testWidgets('Clear button calls callback with null', (tester) async {
      DateTime? resultDate = DateTime(2025, 6, 15);

      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: DateTime(2025, 6, 15),
                    onDueDateChanged: (newDate) async {
                      resultDate = newDate;
                    },
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(resultDate, isNull);
    });

    testWidgets('Done button closes modal', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: DateTime(2025, 6, 15),
                    onDueDateChanged: (_) async {},
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Due Date'), findsNothing);
    });

    testWidgets('uses DateTime.now when initialDate is null', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: null,
                    onDueDateChanged: (_) async {},
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify picker is shown (will use DateTime.now as default)
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
    });

    testWidgets(
      'Today updates the complete due date and enables confirmation',
      (
        tester,
      ) async {
        DateTime? resultDate;
        final initialDate = DateTime(2025, 6, 15);
        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDueDatePicker(
                  context: context,
                  initialDate: initialDate,
                  onDueDateChanged: (date) async => resultDate = date,
                ),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Picker'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Today'));
        await tester.pump();
        await tester.tap(find.text('Done'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(resultDate, isNotNull);
        expect(resultDate, isNot(initialDate));
      },
    );

    testWidgets('Done does not call callback if date unchanged', (
      tester,
    ) async {
      var callbackCalled = false;
      final initialDate = DateTime(2025, 6, 15);

      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: initialDate,
                    onDueDateChanged: (_) async {
                      callbackCalled = true;
                    },
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Done without changing the date
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Callback should not be called if date is unchanged
      expect(callbackCalled, isFalse);
    });

    testWidgets('Done calls callback when date changed by user interaction', (
      tester,
    ) async {
      DateTime? resultDate;
      final initialDate = DateTime(2025, 6, 15);

      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: initialDate,
                    onDueDateChanged: (newDate) async {
                      resultDate = newDate;
                    },
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tester.tap(find.text('16'));
      await tester.pump();

      // Tap Done after changing date
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Callback should be called since user interacted with picker
      expect(resultDate, isNotNull);
    });

    testWidgets(
      'Done calls callback when existing date differs from selected',
      (tester) async {
        DateTime? resultDate;
        final initialDate = DateTime(2025, 6, 15);

        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDueDatePicker(
                      context: context,
                      initialDate: initialDate,
                      onDueDateChanged: (newDate) async {
                        resultDate = newDate;
                      },
                    );
                  },
                  child: const Text('Open Picker'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Open Picker'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('16'));
        await tester.pump();

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Since date was changed, callback should be called
        expect(resultDate, isNotNull);
        expect(resultDate, isNot(equals(initialDate)));
      },
    );

    testWidgets(
      'Done sets date when opening with null - user is explicitly confirming',
      (tester) async {
        DateTime? resultDate;

        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDueDatePicker(
                      context: context,
                      initialDate: null, // No existing due date
                      onDueDateChanged: (date) async {
                        resultDate = date;
                      },
                    );
                  },
                  child: const Text('Open Picker'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Open Picker'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Just tap Done without any interaction
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Callback SHOULD be called - when there's no existing due date and user
        // opens the picker and clicks Done, they're explicitly confirming they
        // want to set a due date. This fixes the bug where selecting "Today" on
        // a task with no due date didn't save.
        expect(resultDate, isNotNull);
      },
    );

    testWidgets('phone layout keeps Clear and dominant Done action visible', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDueDatePicker(
                    context: context,
                    initialDate: DateTime(2025, 6, 15),
                    onDueDateChanged: (_) async {},
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final clearButton = find.widgetWithText(DesignSystemButton, 'Clear');
      final doneButton = find.widgetWithText(DesignSystemButton, 'Done');

      expect(find.text('Cancel'), findsNothing);
      expect(clearButton, findsOneWidget);
      expect(doneButton, findsOneWidget);

      expect(tester.getCenter(doneButton).dy, tester.getCenter(clearButton).dy);
      expect(
        tester.getSize(doneButton).width,
        greaterThan(tester.getSize(clearButton).width),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
