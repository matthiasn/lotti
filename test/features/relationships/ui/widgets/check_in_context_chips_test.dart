import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_context_chips.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final calls = <String>[];
  setUp(calls.clear);

  Future<void> pump(
    WidgetTester tester, {
    CheckInInteractionType type = CheckInInteractionType.call,
    bool enabled = true,
    bool hasDuration = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CheckInContextChips(
          type: type,
          startedLabel: 'Now · 14:55',
          durationLabel: hasDuration ? '11 min' : 'Duration',
          hasDuration: hasDuration,
          enabled: enabled,
          onPickType: () => calls.add('type'),
          onPickStart: () => calls.add('start'),
          onPickDuration: () => calls.add('duration'),
        ),
      ),
    );
    await tester.pump();
  }

  DesignSystemChip chip(WidgetTester tester, String key) =>
      tester.widget<DesignSystemChip>(find.byKey(ValueKey(key)));

  testWidgets('reads the type, the start and the duration, and each chip '
      'opens its own picker', (tester) async {
    await pump(tester);

    expect(chip(tester, 'check-in-type').label, 'Call');
    expect(chip(tester, 'check-in-type').leadingIcon, LottiIcons.call);
    expect(chip(tester, 'check-in-type').selected, isTrue);
    expect(chip(tester, 'check-in-started').label, 'Now · 14:55');
    expect(chip(tester, 'check-in-duration').label, 'Duration');

    await tester.tap(find.byKey(const ValueKey('check-in-type')));
    await tester.tap(find.byKey(const ValueKey('check-in-started')));
    await tester.tap(find.byKey(const ValueKey('check-in-duration')));
    expect(calls, ['type', 'start', 'duration']);
  });

  testWidgets('the semantics name what each chip changes', (tester) async {
    await pump(tester, hasDuration: true);
    expect(
      chip(tester, 'check-in-type').semanticsLabel,
      'Interaction: Call. Change',
    );
    expect(
      chip(tester, 'check-in-started').semanticsLabel,
      'Started: Now · 14:55. Change',
    );
    expect(
      chip(tester, 'check-in-duration').semanticsLabel,
      'Duration: 11 min. Change',
    );
  });

  testWidgets('disabled chips stay visible and take no taps', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byType(DesignSystemChip), findsNWidgets(3));
    for (final key in [
      'check-in-type',
      'check-in-started',
      'check-in-duration',
    ]) {
      expect(chip(tester, key).onPressed, isNull, reason: key);
    }
  });

  group('showCheckInTypePicker', () {
    /// Opens the picker and hands back a reader for what it resolved to,
    /// for the test to call once it has tapped or dismissed.
    Future<CheckInInteractionType? Function()> open(
      WidgetTester tester, {
      required CheckInInteractionType current,
    }) async {
      CheckInInteractionType? picked;
      var resolved = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showCheckInTypePicker(
                  context: context,
                  current: current,
                );
                resolved = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(resolved, isFalse);
      return () {
        expect(resolved, isTrue, reason: 'the picker has resolved');
        return picked;
      };
    }

    testWidgets('lists every kind and resolves to the tapped one', (
      tester,
    ) async {
      final result = await open(tester, current: CheckInInteractionType.call);
      expect(find.text('How did you connect?'), findsOneWidget);
      for (final type in CheckInInteractionType.values) {
        expect(
          find.byKey(ValueKey('check-in-type-${type.name}')),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('check-in-type-message')));
      await tester.pumpAndSettle();
      expect(find.text('How did you connect?'), findsNothing);
      expect(result(), CheckInInteractionType.message);
    });

    testWidgets('dismissing resolves to nothing', (tester) async {
      final result = await open(tester, current: CheckInInteractionType.call);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('How did you connect?'), findsNothing);
      expect(result(), isNull);
    });
  });
}
