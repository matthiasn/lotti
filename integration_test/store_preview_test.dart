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
///     --dart-define=LOTTI_STORE_THEME=dark --dart-define=LOTTI_MANUAL_LOCALE=en \
///     --dart-define=LOTTI_PREVIEW_BEATS=tasks=4500,task=6600,…
///
/// The walk prints `LOTTI_PREVIEW_MARK ready` and waits for the script to
/// start its recorder ([holdForHost]). It then plays the storyboard as
/// [_beatIds], each held until it has lasted its floor from
/// `LOTTI_PREVIEW_BEATS` — long enough for the line the host will lay over
/// it — and writes a timeline of when the cut and every beat began and ended
/// into [hostHandoffDirectory] before a closing `… end` handshake, so the
/// script can copy it while the app is still up. The timeline is in epoch
/// milliseconds: a simulator shares its host's clock, so the script sets it
/// against the moment its recorder started and cuts, and places narration,
/// without guessing at log latency. App Store Connect takes 15–30 seconds,
/// so every beat is paced on the wall clock and the script refuses a cut
/// outside that range. Not a verification suite, and not run by
/// `make integration_test`.
@Tags(['store-screenshots'])
library;

import 'dart:convert';
import 'dart:io';

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
import 'package:path/path.dart' as p;

import 'store_walk.dart';
import 'tutorial/tutorial_harness.dart';

/// The line prefix the recording script watches the drive output for.
const _mark = 'LOTTI_PREVIEW_MARK';

/// The storyboard's beats, in order. They are the step ids of
/// `tools/tutorial_videos/config/scenarios/app_store_preview.yaml`, whose
/// narration the host lays over each one; a test there
/// (`tests/test_app_preview.py`) keeps the two lists in step.
const _beatIds = ['tasks', 'task', 'habits', 'logbook'];

/// Each beat's floor from the host's narration pass, as comma-separated
/// `beat=milliseconds` (`python3 -m tutorial_videos.app_preview pacing`).
/// Empty for a silent preview: every beat then lasts as long as its moves.
const _beatFloors = String.fromEnvironment('LOTTI_PREVIEW_BEATS');

/// What the walk leaves in [hostHandoffDirectory] for the script.
const _timelineFile = 'store_preview_timeline.json';

/// [_beatFloors] parsed, refusing a beat the walk does not have — a
/// narration script out of step with the storyboard fails before anything
/// is recorded.
Map<String, Duration> _parseBeatFloors(String define) {
  final floors = <String, Duration>{};
  for (final pair in define.split(',')) {
    if (pair.isEmpty) continue;
    final parts = pair.split('=');
    final milliseconds = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (milliseconds == null || !_beatIds.contains(parts[0])) {
      throw TestFailure(
        'LOTTI_PREVIEW_BEATS: "$pair" is not <beat>=<milliseconds> for one '
        'of $_beatIds',
      );
    }
    floors[parts[0]] = Duration(milliseconds: milliseconds);
  }
  return floors;
}

/// Hands on the app, paced for a camera: every wait renders frames at display
/// rate, so transitions and scrolls record smoothly. Keeps the timeline the
/// host cuts and narrates by.
class _Walk {
  _Walk(this.tester, this.floors);

  final WidgetTester tester;

  /// Minimum length per beat id; a beat without one lasts as long as its
  /// moves.
  final Map<String, Duration> floors;

  final List<Map<String, Object>> _beats = [];
  late final int _cutStart;
  late final int _cutEnd;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> hold(Duration duration) async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < duration) {
      await tester.pump(storeWalkFrame);
    }
  }

  /// Where the preview begins; everything before it is the recorder's
  /// lead-in.
  void startCut() => _cutStart = _now();

  /// Where the preview ends.
  void endCut() => _cutEnd = _now();

  /// Plays one beat's [moves], then holds its last frame until the beat has
  /// lasted its floor, and records when it began and ended. The host starts
  /// the beat's line where the beat began.
  Future<void> beat(String id, Future<void> Function() moves) async {
    final startedAt = _now();
    final clock = Stopwatch()..start();
    await moves();
    final floor = floors[id];
    if (floor != null && clock.elapsed < floor) {
      await hold(floor - clock.elapsed);
    }
    _beats.add({'id': id, 'start_epoch_ms': startedAt, 'end_epoch_ms': _now()});
  }

  /// The cut and every beat, for the host. Fails when the walk skipped a
  /// beat or played them out of order: the narration would land on the
  /// wrong footage.
  Map<String, Object> timeline() {
    final played = [for (final beat in _beats) beat['id']];
    if (played.join(',') != _beatIds.join(',')) {
      throw TestFailure('the walk played $played, the storyboard is $_beatIds');
    }
    return {
      'cut': {'start_epoch_ms': _cutStart, 'end_epoch_ms': _cutEnd},
      'beats': _beats,
    };
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
    final floors = _parseBeatFloors(_beatFloors);
    final harness = await bootStoreWorld(tester);
    final walk = _Walk(tester, floors);
    final task = harness.world.orbitalHabitatTask;

    final tasksPage = find.byType(TasksTabPage);
    final navigate = find.descendant(
      of: find.byType(MobileNavigationLauncher),
      matching: find.text(messages.navTabTitleNavigate),
    );

    // The host starts its recorder on this line and answers once the camera
    // is rolling, so the file holds the walk and not the build before it.
    await holdForHost(_mark, 'ready');

    // A still lead-in, so the cut never starts on the recording's first
    // frame.
    await walk.hold(const Duration(milliseconds: 500));
    walk.startCut();

    // 1. The task list — what you meant to do.
    await walk.beat('tasks', () async {
      await walk.hold(const Duration(milliseconds: 1200));
      await walk.glide(tasksPage, 420, const Duration(milliseconds: 1500));
      await walk.hold(const Duration(milliseconds: 500));
      await walk.glide(tasksPage, -420, const Duration(milliseconds: 1100));
    });

    // 2. One task: cover art, then the checklist, an item ticked off, and
    //    back to the list.
    await walk.beat('task', () async {
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
      await walk.tap(
        find.descendant(
          of: detailsPage,
          matching: find.byType(GlassBackButton),
        ),
        then: const Duration(milliseconds: 1000),
      );
    });

    // 3. Habits, through the Navigate sheet, and two of them done for today.
    await walk.beat('habits', () async {
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
    });

    // 4. The logbook, where both completions have just landed on top of the
    //    day's photos: what you did is what it keeps. It stays put —
    //    scrolling would push the two rows that close the story off the last
    //    frame.
    await walk.beat('logbook', () async {
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
    });

    walk.endCut();
    // The same still on the far side, so the cut never ends on the last one.
    await walk.hold(const Duration(milliseconds: 500));

    File(
      p.join(hostHandoffDirectory().path, _timelineFile),
    ).writeAsStringSync(jsonEncode(walk.timeline()));
    // The script copies the timeline and answers; only then may the app go.
    await holdForHost(_mark, 'end');
  });
}
