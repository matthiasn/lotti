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

  testWidgets('renders both label and count when active', (tester) async {
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

    expect(find.byKey(SavedTaskFilterRowKeys.root('sv-1')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('In progress · P0'), findsOneWidget);
  });

  testWidgets('renders the drag handle slot when one is supplied',
      (tester) async {
    const handle = Icon(Icons.drag_indicator, size: 14, key: Key('handle'));
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: true,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () {},
          dragHandle: handle,
        ),
      ),
    );

    // When the row is active the handle must be rendered (regardless of
    // hover state); the row delegates the actual drag listener to its
    // parent reorderable list.
    expect(
      find.byKey(SavedTaskFilterRowKeys.dragHandle('sv-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('handle')), findsOneWidget);
  });
}
