import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/provisioned/add_device_join_timeline.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/test_app.dart';

/// The pulsing dot marks the live stop; it is private, so it is found by its
/// type name.
final Finder _pulsing = find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_PulsingDot',
);

/// Filled circles, the pulsing dot's own included.
final Finder _filledCircles = find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).color != null &&
      (widget.decoration as BoxDecoration).shape == BoxShape.circle,
);

/// The stops already reached: filled circles that are not the live stop.
int _reached(WidgetTester tester) =>
    tester.widgetList(_filledCircles).length -
    tester
        .widgetList(find.descendant(of: _pulsing, matching: _filledCircles))
        .length;

void main() {
  Future<void> pump(WidgetTester tester, AddDeviceJoinState state) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(AddDeviceJoinTimeline(state: state)),
    );
    await tester.pump();
  }

  testWidgets('waiting: the first stop is live and nothing is reached yet', (
    tester,
  ) async {
    await pump(tester, AddDeviceJoinState.waiting);

    expect(_pulsing, findsOneWidget);
    expect(_reached(tester), 0);
  });

  testWidgets('joined: the first stop is reached, the second is live', (
    tester,
  ) async {
    await pump(tester, AddDeviceJoinState.joined);

    expect(_pulsing, findsOneWidget);
    expect(_reached(tester), 1);
  });

  testWidgets('ready: every stop is reached and none pulses', (tester) async {
    await pump(tester, AddDeviceJoinState.ready);

    expect(_pulsing, findsNothing);
    expect(_reached(tester), 3);
  });

  testWidgets(
    'a roster failure pauses the poll, not the journey: the stops keep the '
    'waiting reading',
    (tester) async {
      await pump(tester, AddDeviceJoinState.rosterFailed);

      expect(_pulsing, findsOneWidget);
      expect(_reached(tester), 0);
    },
  );
}
