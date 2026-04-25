import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_toast.dart';

import '../../../../widget_test_utils.dart';

const _wideMq = MediaQueryData(
  size: Size(900, 700),
  textScaler: TextScaler.noScaling,
);

/// Pumps a Scaffold whose body builds a button that, on tap, invokes [trigger]
/// with the surrounding [BuildContext]. Uses [makeTestableWidget2] which does
/// NOT wrap in a SingleChildScrollView — `ScaffoldMessenger` and the Scaffold
/// need a bounded vertical extent for the floating SnackBar to lay out.
Future<void> _pumpHarness(
  WidgetTester tester,
  void Function(BuildContext context) trigger,
) async {
  await tester.pumpWidget(
    makeTestableWidget2(
      Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => trigger(context),
                child: const Text('fire'),
              ),
            );
          },
        ),
      ),
      mediaQueryData: _wideMq,
    ),
  );
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  testWidgets('showSavedTaskFilterSavedToast surfaces the localised label', (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      (context) => showSavedTaskFilterSavedToast(context, name: 'My filter'),
    );

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();

    expect(find.text("Saved 'My filter'"), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('showSavedTaskFilterUpdatedToast surfaces the localised label', (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      (context) => showSavedTaskFilterUpdatedToast(context, name: 'My filter'),
    );

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();

    expect(find.text("Updated 'My filter'"), findsOneWidget);
  });

  testWidgets('showSavedTaskFilterDeletedToast surfaces the localised label', (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      showSavedTaskFilterDeletedToast,
    );

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();

    expect(find.text('Filter deleted'), findsOneWidget);
  });

  testWidgets('renders the success check icon inside the SnackBar', (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      (context) => showSavedTaskFilterSavedToast(context, name: 'A'),
    );

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();

    final inSnackBar = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(inSnackBar, findsOneWidget);
  });
}
