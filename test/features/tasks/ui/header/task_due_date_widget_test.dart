import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      await tester.pumpAndSettle();

      // Verify modal elements are shown
      expect(find.text('Due Date'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });

    testWidgets('Cancel button closes modal without callback', (tester) async {
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Verify picker is shown (will use DateTime.now as default)
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });

    testWidgets('Done does not call callback if date unchanged',
        (tester) async {
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
      await tester.pumpAndSettle();

      // Tap Done without changing the date
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Callback should not be called if date is unchanged
      expect(callbackCalled, isFalse);
    });

    testWidgets('modal has proper layout with three buttons', (tester) async {
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
      await tester.pumpAndSettle();

      // All three buttons should be in the same Row
      final cancelButton = find.text('Cancel');
      final clearButton = find.text('Clear');
      final doneButton = find.text('Done');

      expect(cancelButton, findsOneWidget);
      expect(clearButton, findsOneWidget);
      expect(doneButton, findsOneWidget);

      // Verify they share a common Row ancestor
      final rowFinder = find.ancestor(
        of: cancelButton,
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);
    });
  });
}
