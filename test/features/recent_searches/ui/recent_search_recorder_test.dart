import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_controller.dart';
import 'package:lotti/features/recent_searches/ui/recent_search_recorder.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/test_view.dart';
import '../test_utils.dart';

void main() {
  /// Pumps a probe at [width] and returns what [recentSearchRecorder] hands
  /// it, with [recents] standing in for the real controller.
  Future<RecentSearchesController?> recorderAt(
    WidgetTester tester,
    double width,
    FakeRecentSearchesController recents,
  ) async {
    setTestSurfaceSize(tester, Size(width, 800));
    RecentSearchesController? recorder;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fakeRecentSearches(recents)],
        child: Consumer(
          builder: (context, ref, _) {
            recorder = recentSearchRecorder(context, ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return recorder;
  }

  testWidgets('hands a compact window the Recents controller', (
    tester,
  ) async {
    final recents = FakeRecentSearchesController();
    final recorder = await recorderAt(
      tester,
      kDesktopBreakpoint - 1,
      recents,
    );

    recorder?.noteQuery(RecentSearchSurface.tasks, 'fish feeder');
    expect(recents.noted, [(RecentSearchSurface.tasks, 'fish feeder')]);
  });

  testWidgets('hands the desktop layout nothing, since it shows no Recents', (
    tester,
  ) async {
    final recorder = await recorderAt(
      tester,
      kDesktopBreakpoint,
      FakeRecentSearchesController(),
    );

    expect(recorder, isNull);
  });
}
