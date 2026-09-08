import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_view.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

import '../../../widget_test_utils.dart';

void main() {
  test('scripted modes explicitly opt in and benchmark wins over tour', () {
    expect(HarnessMode.fromEnvironment({}), HarnessMode.interactive);
    expect(HarnessMode.fromEnvironment({'PLAZA_TOUR': '1'}), HarnessMode.tour);
    expect(
      HarnessMode.fromEnvironment({'PLAZA_BENCH': '1', 'PLAZA_TOUR': '1'}),
      HarnessMode.bench,
    );
    expect(HarnessMode.interactive.scripted, isFalse);
    expect(HarnessMode.tour.scripted, isTrue);
    expect(HarnessMode.bench.scripted, isTrue);
  });

  testWidgets('unavailable GPU becomes a recoverable page error', (
    tester,
  ) async {
    final world = PlazaWorld(
      tasks: const [],
      now: DateTime.utc(2026, 9, 7),
      projectLabel: 'Project Waddle',
      layout: StreetLayout(projectSeed: 1),
    );
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(width: 800, height: 600, child: PlazaView(world: world)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final error = tester.widget<ErrorStateWidget>(
      find.byType(ErrorStateWidget),
    );
    expect(error.error, 'This device cannot display the 3D world.');
    expect(error.mode, ErrorDisplayMode.inline);
  });
}
