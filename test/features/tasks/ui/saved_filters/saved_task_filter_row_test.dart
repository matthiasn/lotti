import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('renders the drag handle slot when one is supplied', (
    tester,
  ) async {
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

    expect(
      find.byKey(SavedTaskFilterRowKeys.dragHandle('sv-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('handle')), findsOneWidget);
  });

  testWidgets('hover reveals the delete affordance and drag handle', (
    tester,
  ) async {
    const handle = Icon(Icons.drag_indicator, size: 14, key: Key('handle'));
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          count: 3,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () {},
          dragHandle: handle,
        ),
      ),
    );

    // Without hover the handle must be absent.
    expect(find.byKey(SavedTaskFilterRowKeys.dragHandle('sv-1')), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(SavedTaskFilterRowKeys.root('sv-1'))),
    );
    await tester.pump();

    expect(
      find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(SavedTaskFilterRowKeys.dragHandle('sv-1')),
      findsOneWidget,
    );

    // Hover leave hides the handle again.
    await gesture.moveTo(const Offset(2000, 2000));
    await tester.pump();

    expect(find.byKey(SavedTaskFilterRowKeys.dragHandle('sv-1')), findsNothing);
  });

  testWidgets('two-tap delete: first arms, second invokes onDelete', (
    tester,
  ) async {
    var deletes = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () => deletes++,
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(SavedTaskFilterRowKeys.root('sv-1'))),
    );
    await tester.pump();

    // First tap arms the confirmation; onDelete is not invoked yet.
    // Pump past the parent GestureDetector's double-tap timeout so the
    // child InkWell's onTap commits.
    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    expect(deletes, 0);

    // Second tap commits.
    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    expect(deletes, 1);
  });

  testWidgets('hover exit clears an armed delete confirmation', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (_) {},
          onDelete: () => deletes++,
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    final rowCenter = tester.getCenter(
      find.byKey(SavedTaskFilterRowKeys.root('sv-1')),
    );
    await gesture.moveTo(rowCenter);
    await tester.pump();

    // Arm the confirmation.
    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);

    // Move out, then back in: confirmation should reset, so tapping once
    // again only arms (does not delete).
    await gesture.moveTo(const Offset(2000, 2000));
    await tester.pump();
    await gesture.moveTo(rowCenter);
    await tester.pump();

    await tester.tap(find.byKey(SavedTaskFilterRowKeys.deleteButton('sv-1')));
    await tester.pump(_afterDoubleTapTimeout);
    expect(deletes, 0);
  });

  testWidgets('double-tap enters rename mode and submitting commits', (
    tester,
  ) async {
    String? renamed;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (v) => renamed = v,
          onDelete: () {},
        ),
      ),
    );

    final rowFinder = find.byKey(SavedTaskFilterRowKeys.root('sv-1'));

    // Double-tap by issuing two single taps within kDoubleTapTimeout, then
    // pump past the recognizer's tail timer.
    await tester.tap(rowFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(rowFinder);
    await tester.pump(_afterDoubleTapTimeout);

    final fieldFinder = find.byKey(SavedTaskFilterRowKeys.renameField('sv-1'));
    expect(fieldFinder, findsOneWidget);

    await tester.enterText(fieldFinder, 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(renamed, 'Renamed');
    expect(
      find.byKey(SavedTaskFilterRowKeys.renameField('sv-1')),
      findsNothing,
    );
  });

  testWidgets('rename to whitespace reverts without invoking onRename', (
    tester,
  ) async {
    var renameInvocations = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (_) => renameInvocations++,
          onDelete: () {},
        ),
      ),
    );

    final rowFinder = find.byKey(SavedTaskFilterRowKeys.root('sv-1'));
    await tester.tap(rowFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(rowFinder);
    await tester.pump(_afterDoubleTapTimeout);

    await tester.enterText(
      find.byKey(SavedTaskFilterRowKeys.renameField('sv-1')),
      '   ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(renameInvocations, 0);
    expect(find.text('In progress · P0'), findsOneWidget);
  });

  testWidgets('rename to the same name does not invoke onRename', (
    tester,
  ) async {
    var renameInvocations = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (_) => renameInvocations++,
          onDelete: () {},
        ),
      ),
    );

    final rowFinder = find.byKey(SavedTaskFilterRowKeys.root('sv-1'));
    await tester.tap(rowFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(rowFinder);
    await tester.pump(_afterDoubleTapTimeout);

    // Same value (already the original); commit.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(renameInvocations, 0);
  });

  testWidgets('Escape cancels rename without invoking onRename', (
    tester,
  ) async {
    var renameInvocations = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SavedTaskFilterRow(
          view: _view,
          active: false,
          onActivate: () {},
          onRename: (_) => renameInvocations++,
          onDelete: () {},
        ),
      ),
    );

    final rowFinder = find.byKey(SavedTaskFilterRowKeys.root('sv-1'));
    await tester.tap(rowFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(rowFinder);
    await tester.pump(_afterDoubleTapTimeout);

    await tester.enterText(
      find.byKey(SavedTaskFilterRowKeys.renameField('sv-1')),
      'Throwaway',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(renameInvocations, 0);
    expect(
      find.byKey(SavedTaskFilterRowKeys.renameField('sv-1')),
      findsNothing,
    );
    // Original label is restored.
    expect(find.text('In progress · P0'), findsOneWidget);
  });

  testWidgets('didUpdateWidget syncs controller text when name changes', (
    tester,
  ) async {
    const originalView = _view;
    final renamedView = _view.copyWith(name: 'New Name');

    Widget build(SavedTaskFilter view) => makeTestableWidget(
      SavedTaskFilterRow(
        view: view,
        active: false,
        onActivate: () {},
        onRename: (_) {},
        onDelete: () {},
      ),
    );

    await tester.pumpWidget(build(originalView));
    expect(find.text('In progress · P0'), findsOneWidget);

    await tester.pumpWidget(build(renamedView));
    await tester.pump();
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('In progress · P0'), findsNothing);
  });
}
