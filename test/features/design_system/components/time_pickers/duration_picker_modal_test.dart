import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/time_pickers/duration_picker_modal.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_helper.dart';

void main() {
  const oneHour = Duration(hours: 1);
  const fortySeven = Duration(minutes: 47);

  /// Opens the picker from a button, with a chip row that records the draft
  /// it was built for and commits a fixed value on tap.
  Future<List<Duration>> open(
    WidgetTester tester, {
    required Duration initial,
    required Future<void> Function(Duration) onChanged,
    Duration chipValue = const Duration(minutes: 15),
  }) async {
    final drafts = <Duration>[];
    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDurationPicker(
                  context: context,
                  title: 'Length',
                  initialDuration: initial,
                  quickPicks: (context, current, onQuickPick) {
                    drafts.add(current);
                    return TextButton(
                      onPressed: () => onQuickPick(chipValue),
                      child: const Text('chip'),
                    );
                  },
                  semanticsLabelOf: (duration) =>
                      'Length ${duration.inMinutes}',
                  onDurationChanged: onChanged,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return drafts;
  }

  void spinWheelTo(WidgetTester tester, Duration duration) => tester
      .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
      .onTimerDurationChanged(duration);

  testWidgets('the chips sit above the wheel, and the wheel opens on the '
      'initial value', (tester) async {
    final drafts = await open(
      tester,
      initial: oneHour,
      onChanged: (_) async {},
    );

    expect(find.text('Length'), findsOneWidget);
    expect(drafts, const [oneHour]);
    expect(
      tester.getRect(find.text('chip')).bottom,
      lessThan(tester.getRect(find.byType(CupertinoTimerPicker)).top),
      reason: 'the cheap path is met before the fallback',
    );
    expect(
      tester
          .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
          .initialTimerDuration,
      oneHour,
    );
  });

  testWidgets('Done without a change closes and writes nothing', (
    tester,
  ) async {
    final written = <Duration>[];
    await open(
      tester,
      initial: oneHour,
      onChanged: (d) async => written.add(d),
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsNothing);
    expect(written, isEmpty);
  });

  testWidgets('spinning the wheel rebuilds the chips for the draft, and Done '
      'commits it', (tester) async {
    final written = <Duration>[];
    final drafts = await open(
      tester,
      initial: oneHour,
      onChanged: (d) async => written.add(d),
    );

    spinWheelTo(tester, fortySeven);
    await tester.pumpAndSettle();
    expect(
      drafts.last,
      fortySeven,
      reason: 'the row tracks the wheel, not the value the modal opened on',
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(written, const [fortySeven]);
    expect(find.byType(CupertinoTimerPicker), findsNothing);
  });

  testWidgets('a quick pick closes first and then writes its value', (
    tester,
  ) async {
    final events = <String>[];
    await open(
      tester,
      initial: oneHour,
      onChanged: (d) async {
        // The route is already off the stack when the write starts — the
        // modal never sits open over an awaited save.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        events.add('write ${d.inMinutes} open=${navigator.canPop()}');
      },
    );

    await tester.tap(find.text('chip'));
    await tester.pumpAndSettle();

    expect(events, ['write 15 open=false']);
  });

  testWidgets('a quick pick equal to the initial value only closes', (
    tester,
  ) async {
    final written = <Duration>[];
    await open(
      tester,
      initial: oneHour,
      onChanged: (d) async => written.add(d),
      chipValue: oneHour,
    );

    await tester.tap(find.text('chip'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsNothing);
    expect(written, isEmpty);
  });

  testWidgets('Clear is offered only when there is something to clear, and '
      'commits zero', (tester) async {
    final written = <Duration>[];
    await open(
      tester,
      initial: oneHour,
      onChanged: (d) async => written.add(d),
    );
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(written, const [Duration.zero]);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('a zero initial value has no Clear', (tester) async {
    await open(tester, initial: Duration.zero, onChanged: (_) async {});

    expect(find.text('Clear'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the wheel announces the draft through the host label', (
    tester,
  ) async {
    await open(tester, initial: oneHour, onChanged: (_) async {});

    expect(
      find.bySemanticsLabel(RegExp('Length 60')),
      findsOneWidget,
    );

    spinWheelTo(tester, fortySeven);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Length 47')), findsOneWidget);
  });
}
