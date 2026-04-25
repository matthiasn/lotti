import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_row.dart';

import '../../../../widget_test_utils.dart';

const _view = SavedTaskFilter(
  id: 'sv-1',
  name: 'In progress · P0',
  filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
);

/// GestureDetector defers single-tap by `kDoubleTapTimeout` (300 ms) when
/// `onDoubleTap` is also wired, so tap-driven tests pump past that.
const _afterDoubleTapTimeout = Duration(milliseconds: 350);

Future<void> _hoverRow(WidgetTester tester) async {
  final row = find.byKey(SavedTaskFilterRowKeys.root('sv-1'));
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(row));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  testWidgets('renders the saved filter name and count', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          count: 7,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('In progress · P0'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('hides the count when count is null', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('In progress · P0'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('invokes onActivate when row body is tapped', (tester) async {
    var activatedCount = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () => activatedCount++,
          onRename: (_) {},
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(SavedTaskFilterRowKeys.root('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);

    expect(activatedCount, 1);
  });

  testWidgets('two-tap delete: first arms, second commits', (tester) async {
    var deleteCount = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          count: 3,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () => deleteCount++,
        ),
      ),
    );

    await _hoverRow(tester);

    final deleteButton = find.byKey(
      SavedTaskFilterRowKeys.deleteButton('sv-1'),
    );
    expect(deleteButton, findsOneWidget);

    final deleteCenter = tester.getCenter(deleteButton);
    await tester.tapAt(deleteCenter);
    await tester.pump();
    expect(deleteCount, 0);

    await tester.tapAt(deleteCenter);
    await tester.pump();
    expect(deleteCount, 1);
  });

  testWidgets('renders the active accent bar when active', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: true,
          count: 5,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () {},
        ),
      ),
    );

    // Active state shifts the count colour; the row + count are rendered.
    expect(find.byKey(SavedTaskFilterRowKeys.root('sv-1')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('In progress · P0'), findsOneWidget);
  });
}
