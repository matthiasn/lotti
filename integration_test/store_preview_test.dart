/// App Store App Preview — the store listing's video — walked on an iOS
/// simulator while the host records its screen.
///
/// Where `store_screenshots_test.dart` jumps between routes and holds still,
/// this moves the way a person does, and only through what a phone can reach
/// by touch: it scrolls the task list, opens a task, ticks a checklist item,
/// goes back, completes two habits through the Navigate sheet, and ends in the
/// logbook, where both completions have just landed. Time analysis is absent
/// on purpose — its only entry point is the desktop sidebar — and so is Daily
/// OS, which in this world opens on its set-up card.
///
/// Run through `tool/store_screenshots/ios_preview.sh`
/// (`make store_preview_ios`), which records the simulator around:
///
///   flutter drive --driver=test_driver/tutorial_driver.dart \
///     --target=integration_test/store_preview_test.dart -d UDID \
///     --dart-define=LOTTI_STORE_THEME=dark --dart-define=LOTTI_MANUAL_LOCALE=en
///
/// The walk prints `LOTTI_PREVIEW_MARK ready` and waits for the script to
/// start its recorder ([holdForHost]), then prints `… start` and `… end`
/// around the footage worth keeping; the script times those two lines against
/// the recorder and cuts the slice between them. App Store Connect takes 15–30 seconds, so every
/// beat below is paced on the wall clock and the script refuses a cut outside
/// that range. Not a verification suite, and not run by
/// `make integration_test`.
@Tags(['store-screenshots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

import 'store_walk.dart';
import 'tutorial/tutorial_harness.dart';

/// The line prefix the recording script watches the drive output for.
const _mark = 'LOTTI_PREVIEW_MARK';

/// Hands on the app, paced for a camera: every wait renders frames at display
/// rate, so transitions and scrolls record smoothly.
class _Walk {
  _Walk(this.tester);

  final WidgetTester tester;

  Future<void> hold(Duration duration) async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < duration) {
      await tester.pump(storeWalkFrame);
    }
  }

  /// Taps the visible match of [finder], then stays on the result for [then].
  Future<void> tap(Finder finder, {required Duration then}) async {
    final target = finder.hitTestable();
    await pumpUntilFound(tester, target);
    await tester.tap(target.first);
    await hold(then);
  }

  /// Scrolls the page inside [within] by [delta] logical pixels over
  /// [duration], easing in and out the way a thumb does.
  Future<void> glide(Finder within, double delta, Duration duration) async {
    final scrollable = widestRangeScrollable(
      find.descendant(
        of: within,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    if (scrollable == null) {
      throw TestFailure('Nothing scrolls inside $within');
    }
    final position = scrollable.position;
    final arrived = position.animateTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: duration,
      curve: Curves.easeInOut,
    );
    await hold(duration + const Duration(milliseconds: 120));
    await arrived;
  }

  /// Brings [target] to the middle of its page, animated.
  Future<void> reveal(Finder target, Duration duration) async {
    await pumpUntilFound(tester, target);
    final arrived = Scrollable.ensureVisible(
      target.evaluate().first,
      alignment: 0.5,
      duration: duration,
      curve: Curves.easeInOut,
    );
    await hold(duration + const Duration(milliseconds: 120));
    await arrived;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final messages = lookupAppLocalizations(storeLocale);

  testWidgets('walks the App Preview', (tester) async {
    final harness = await bootStoreWorld(tester);
    final walk = _Walk(tester);
    final task = harness.world.orbitalHabitatTask;

    final tasksPage = find.byType(TasksTabPage);
    final navigate = find.descendant(
      of: find.byType(MobileNavigationLauncher),
      matching: find.text(messages.navTabTitleNavigate),
    );

    // The host starts its recorder on this line and answers once the camera
    // is rolling, so the file holds the walk and not the build before it.
    await holdForHost(_mark, 'ready');

    // A still lead-in on either side of the marks absorbs the latency between
    // a line leaving the device and the script reading it.
    await walk.hold(const Duration(milliseconds: 1500));
    debugPrint('$_mark start');

    // 1. The task list — what you meant to do.
    await walk.hold(const Duration(milliseconds: 1200));
    await walk.glide(tasksPage, 420, const Duration(milliseconds: 1500));
    await walk.hold(const Duration(milliseconds: 500));
    await walk.glide(tasksPage, -420, const Duration(milliseconds: 1100));

    // 2. One task: cover art, then the checklist, and an item ticked off.
    await walk.tap(
      find.descendant(of: tasksPage, matching: find.text(task.data.title)),
      then: const Duration(milliseconds: 1800),
    );
    final detailsPage = find.byType(TaskDetailsPage);
    final checkboxes = find.descendant(
      of: detailsPage,
      matching: find.byType(Checkbox),
    );
    await walk.reveal(checkboxes, const Duration(milliseconds: 1000));
    await walk.hold(const Duration(milliseconds: 600));
    await walk.tap(checkboxes, then: const Duration(milliseconds: 1600));

    // 3. Back to the list.
    await walk.tap(
      find.descendant(of: detailsPage, matching: find.byType(GlassBackButton)),
      then: const Duration(milliseconds: 1000),
    );

    // 4. Habits, through the Navigate sheet, and two of them done for today.
    await walk.tap(navigate, then: const Duration(milliseconds: 900));
    await walk.tap(
      find.text(messages.navTabTitleHabits),
      then: const Duration(milliseconds: 1400),
    );
    final completeHabit = find.descendant(
      of: find.descendant(
        of: find.byType(HabitsTabPage),
        matching: find.byType(HabitActionRow),
      ),
      matching: find.byIcon(LottiIcons.add),
    );
    await walk.tap(completeHabit, then: const Duration(milliseconds: 1500));
    await walk.tap(completeHabit, then: const Duration(milliseconds: 1500));

    // 5. The logbook, where both completions have just landed on top of the
    //    day's photos: what you did is what it keeps. It stays put — scrolling
    //    would push the two rows that close the story off the last frame.
    await walk.tap(navigate, then: const Duration(milliseconds: 900));
    await walk.tap(
      find.text(messages.navTabTitleJournal),
      then: const Duration(milliseconds: 600),
    );
    await pumpUntilFound(
      tester,
      find.byType(InfiniteJournalPage).hitTestable(),
    );
    await walk.hold(const Duration(milliseconds: 2600));

    debugPrint('$_mark end');
    await walk.hold(const Duration(milliseconds: 1500));
  });
}
