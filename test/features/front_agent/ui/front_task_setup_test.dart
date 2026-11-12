// The band's render object is private to its library: the test reaches
// its gaps the only way it can, dynamically.
// ignore_for_file: avoid_dynamic_calls

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/ui/front_task_setup.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  // A Wednesday in the penguin world.
  final today = DateTime(2026, 11, 11);
  final now = DateTime(2026, 11, 11, 9, 30);
  const plain = FrontTaskChoices(
    start: FrontTaskStart.open,
    priority: TaskPriority.p2Medium,
  );

  late List<FrontTaskChoices> created;
  late int backs;

  setUp(() {
    created = [];
    backs = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    FrontTaskChoices initial = plain,
    bool busy = false,
    bool failed = false,
    double? width,
    TextDirection direction = TextDirection.ltr,
    bool heard = false,
    double endInset = 0,
  }) async {
    final setup = FrontTaskSetup(
      index: 0,
      initial: initial,
      heard: heard,
      endInset: endInset,
      busy: busy,
      failed: failed,
      onCreate: created.add,
      onBack: () => backs++,
    );
    await tester.pumpWidget(
      makeTestableWidget(
        Directionality(
          textDirection: direction,
          child: width == null
              ? setup
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: width, child: setup),
                ),
        ),
      ),
    );
    await tester.pump();
  }

  DesignSystemChip chip(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemChip>(find.byKey(key));
  String labelOf(WidgetTester tester, Key key) => chip(tester, key).label;

  /// Opens a chip's menu and taps the row that sets [option].
  Future<void> choose(WidgetTester tester, Key chipKey, String option) async {
    await tester.tap(find.byKey(chipKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FrontTaskSetupKeys.option(0, option)));
    await tester.pumpAndSettle();
  }

  Future<void> create(WidgetTester tester) async {
    await tester.tap(find.byKey(FrontTaskSetupKeys.create(0)));
    await tester.pump();
  }

  testWidgets('asks in her voice, the chips saying what she read, and '
      'create alone makes it as she read it', (tester) async {
    await withClock(Clock.fixed(now), () async {
      final read = FrontTaskChoices(
        start: FrontTaskStart.inProgress,
        priority: TaskPriority.p0Urgent,
        due: today,
      );
      await pump(tester, initial: read, heard: true);

      expect(find.text("Here's what I heard. Change anything?"), findsOne);
      expect(labelOf(tester, FrontTaskSetupKeys.status(0)), 'In Progress');
      expect(labelOf(tester, FrontTaskSetupKeys.priority(0)), 'Urgent');
      expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'Due Today');
      expect(
        chip(tester, FrontTaskSetupKeys.priority(0)).semanticsLabel,
        'Priority: Urgent',
      );
      expect(
        chip(tester, FrontTaskSetupKeys.status(0)).semanticsLabel,
        'Status: In Progress',
      );

      // The task's own glyphs: an urgent task reads urgent before it is made.
      expect(
        tester
            .widget<TaskShowcaseStatusGlyph>(
              find.byType(TaskShowcaseStatusGlyph),
            )
            .status,
        isA<TaskInProgress>(),
      );
      expect(
        tester
            .widget<TaskShowcasePriorityGlyph>(
              find.byType(TaskShowcasePriorityGlyph),
            )
            .priority,
        TaskPriority.p0Urgent,
      );

      await create(tester);
      expect(created, [read]);
    });
  });

  group('the keyboard', () {
    testWidgets('the step takes focus when it opens: Enter creates, Escape '
        'goes back', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(created, [plain]);
        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        expect(created, [plain, plain]);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(backs, 1);
      });
    });

    testWidgets('once focus moves to a button in it, Enter is the '
        "button's: on cancel it cancels, and creates nothing", (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester);
        Focus.of(tester.element(find.text('Cancel'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(created, isEmpty);
        expect(backs, 1);

        // Escape is not the step's either while a button holds focus.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(backs, 1);
      });
    });

    testWidgets('other keys pass the step by', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        expect(created, isEmpty);
        expect(backs, 0);
      });
    });

    testWidgets('while the task is made the keys do nothing', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, busy: true);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(created, isEmpty);
        expect(backs, 0);
      });
    });
  });

  testWidgets('the tap that closes a menu does not also press cancel', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, width: 700);
      await tester.tap(find.byKey(FrontTaskSetupKeys.status(0)));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.byKey(FrontTaskSetupKeys.back(0))),
      );
      await tester.pumpAndSettle();

      expect(backs, 0);
      expect(find.text('Groomed'), findsNothing);
      expect(labelOf(tester, FrontTaskSetupKeys.status(0)), 'Open');
    });
  });

  group('the band', () {
    Rect rectOf(WidgetTester tester, Key key) =>
        tester.getRect(find.byKey(key));

    // The test font sets every glyph a full em wide: a line that fits both
    // needs a wider view than the default.
    void wideView(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1600, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('where it fits, the chips and the buttons share one line, '
        'the buttons at its end', (tester) async {
      await withClock(Clock.fixed(now), () async {
        wideView(tester);
        await pump(tester, width: 1400);
        final status = rectOf(tester, FrontTaskSetupKeys.status(0));
        final create = rectOf(tester, FrontTaskSetupKeys.create(0));
        expect(create.center.dy, moreOrLessEquals(status.center.dy));
        expect(create.right, moreOrLessEquals(1400));
      });
    });

    testWidgets('where it does not, the buttons drop below the chips, still '
        'at the end', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, width: 360);
        final due = rectOf(tester, FrontTaskSetupKeys.due(0));
        final create = rectOf(tester, FrontTaskSetupKeys.create(0));
        expect(create.top, greaterThan(due.bottom));
        expect(create.right, moreOrLessEquals(360));
      });
    });

    testWidgets('on a shared line, keeps the room after create only while '
        'the line still fits with it', (tester) async {
      await withClock(Clock.fixed(now), () async {
        wideView(tester);
        await pump(tester, width: 1400, endInset: 44);
        expect(
          rectOf(tester, FrontTaskSetupKeys.create(0)).right,
          moreOrLessEquals(1400 - 44),
        );

        // Just wide enough for one line without the room: the room goes.
        final status = rectOf(tester, FrontTaskSetupKeys.status(0));
        final due = rectOf(tester, FrontTaskSetupKeys.due(0));
        final back = rectOf(tester, FrontTaskSetupKeys.back(0));
        final create = rectOf(tester, FrontTaskSetupKeys.create(0));
        final band =
            tester.renderObject<RenderBox>(find.byType(Wrap).first).parent!
                as RenderBox;
        final dynamic gaps = band;
        final tight =
            (due.right - status.left) +
            (gaps.gap as double) +
            (create.right - back.left) +
            1;
        await tester.pumpWidget(const SizedBox());
        await pump(tester, width: tight, endInset: 44);
        final shared = rectOf(tester, FrontTaskSetupKeys.create(0));
        expect(
          shared.center.dy,
          moreOrLessEquals(
            rectOf(tester, FrontTaskSetupKeys.status(0)).center.dy,
          ),
        );
        expect(shared.right, moreOrLessEquals(tight));
      });
    });

    testWidgets('the buttons stand as tall as the row they replace', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, width: 360);
        final row = find
            .ancestor(
              of: find.byKey(FrontTaskSetupKeys.create(0)),
              matching: find.byType(ConstrainedBox),
            )
            .first;
        final overflow = DesignSystemContextMenuButton.extent(
          tester.element(find.byType(FrontTaskSetup)).designTokens,
        );
        expect(tester.getSize(row).height, greaterThanOrEqualTo(overflow));
      });
    });

    testWidgets('stacked, the room after create shrinks to what the '
        "buttons leave: they never reach past the band's start", (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, width: 360, endInset: 300);
        final back = rectOf(tester, FrontTaskSetupKeys.back(0));
        expect(back.left, greaterThanOrEqualTo(0));
        // Cancel answers a tap at its very start.
        await tester.tapAt(back.centerLeft + const Offset(2, 0));
        expect(backs, 1);
      });
    });

    testWidgets('where even the two buttons do not fit side by side, create '
        'goes under cancel, inside the band, and answers a tap', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, width: 160);
        final back = rectOf(tester, FrontTaskSetupKeys.back(0));
        final create = rectOf(tester, FrontTaskSetupKeys.create(0));
        expect(create.top, greaterThanOrEqualTo(back.bottom));
        expect(create.left, greaterThanOrEqualTo(0));
        expect(create.right, lessThanOrEqualTo(160));
        expect(tester.takeException(), isNull);

        await tester.tapAt(create.center);
        expect(created, [plain]);
      });
    });

    testWidgets('keeps the room asked for after create', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, width: 360, endInset: 44);
        final create = rectOf(tester, FrontTaskSetupKeys.create(0));
        expect(create.right, moreOrLessEquals(360 - 44));
      });
    });

    testWidgets('right to left, it mirrors: the chips at the right, the '
        'buttons at the left', (tester) async {
      await withClock(Clock.fixed(now), () async {
        wideView(tester);
        await pump(tester, width: 1400, direction: TextDirection.rtl);
        final create = rectOf(tester, FrontTaskSetupKeys.create(0));
        final status = rectOf(tester, FrontTaskSetupKeys.status(0));
        expect(create.left, moreOrLessEquals(0));
        expect(status.right, moreOrLessEquals(1400));
      });
    });

    testWidgets('measures without laying out as it lays out, and follows a '
        'change of gaps', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, width: 360);
        final band =
            tester.renderObject<RenderBox>(find.byType(Wrap).first).parent!
                as RenderBox;
        expect(
          band.getDryLayout(BoxConstraints.loose(const Size(360, 999))),
          band.size,
        );
        // Unbounded, it is as wide as one line of both.
        final unbounded = band.getDryLayout(const BoxConstraints());
        expect(unbounded.width, greaterThan(360));

        // Measured by an intrinsic parent, it agrees with its own layout:
        // its widest is the one line, its height at a width what it lays
        // out to, and its narrowest no wider than the stacked buttons need.
        expect(band.getMaxIntrinsicWidth(double.infinity), unbounded.width);
        expect(band.getMinIntrinsicHeight(360), band.size.height);
        expect(band.getMaxIntrinsicHeight(360), band.size.height);
        final narrowest = band.getMinIntrinsicWidth(double.infinity);
        expect(narrowest, greaterThan(0));
        expect(narrowest, lessThan(360));

        final dynamic gaps = band;
        final before = band.size.height;
        gaps
          ..gap = gaps.gap
          ..endInset = gaps.endInset
          ..runGap = gaps.runGap + 10
          ..textDirection = gaps.textDirection;
        await tester.pump();
        expect(band.size.height, moreOrLessEquals(before + 10));
        gaps.gap = 2000.0;
        await tester.pump();
        expect(gaps.gap, 2000.0);
        gaps.endInset = 30.0;
        await tester.pump();
        expect(
          rectOf(tester, FrontTaskSetupKeys.create(0)).right,
          moreOrLessEquals(360 - 30),
        );
        // Mirrored, the buttons keep the room at the left.
        gaps.textDirection = TextDirection.rtl;
        await tester.pump();
        expect(
          rectOf(tester, FrontTaskSetupKeys.back(0)).left,
          moreOrLessEquals(30),
        );
      });
    });
  });

  testWidgets('with nothing heard, she only asks', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester);
      expect(find.text('Anything to set before I make it?'), findsOne);
    });
  });

  testWidgets('a status picked from its chip is the one it is made in, the '
      'menu marking the one set', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester);
      await tester.tap(find.byKey(FrontTaskSetupKeys.status(0)));
      await tester.pumpAndSettle();
      // Open while its menu is: the chip shows it, and the chevron turns.
      expect(chip(tester, FrontTaskSetupKeys.status(0)).selected, isTrue);
      expect(find.byIcon(LottiIcons.chevronUp), findsOne);
      expect(find.text('Groomed'), findsOne);
      expect(find.text('In Progress'), findsOne);

      await tester.tap(
        find.byKey(FrontTaskSetupKeys.option(0, FrontTaskStart.groomed.name)),
      );
      await tester.pumpAndSettle();

      expect(labelOf(tester, FrontTaskSetupKeys.status(0)), 'Groomed');
      await create(tester);
      expect(created.single.start, FrontTaskStart.groomed);
    });
  });

  testWidgets('a priority picked from its chip is the one it is made at', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester);
      await choose(tester, FrontTaskSetupKeys.priority(0), 'P1');

      expect(labelOf(tester, FrontTaskSetupKeys.priority(0)), 'High');
      await create(tester);
      expect(created.single.priority, TaskPriority.p1High);
    });
  });

  group('the due day', () {
    Color? dueInk(WidgetTester tester) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(FrontTaskSetupKeys.due(0)),
            matching: find.byIcon(LottiIcons.calendar),
          ),
        )
        .color;

    testWidgets('escalates as the task will: today warns, a past day is '
        'late, any other is plain', (tester) async {
      await withClock(Clock.fixed(now), () async {
        final cases = {
          today: TaskShowcasePalette.warning,
          DateTime(2026, 11, 9): TaskShowcasePalette.error,
          DateTime(2026, 11, 20): (BuildContext c) =>
              c.designTokens.colors.text.mediumEmphasis,
          null: (BuildContext c) => c.designTokens.colors.text.mediumEmphasis,
        };
        for (final MapEntry(key: due, value: ink) in cases.entries) {
          // A fresh setup each time: its chips start from what it is given.
          await tester.pumpWidget(const SizedBox());
          await pump(tester, initial: plain.copyWith(due: () => due));
          final context = tester.element(find.byType(FrontTaskSetup));
          expect(dueInk(tester), ink(context), reason: '$due');
        }
      });
    });

    testWidgets('is none until set; today, tomorrow and none are one tap '
        'each', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester);
        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'No due date');

        await tester.tap(find.byKey(FrontTaskSetupKeys.due(0)));
        await tester.pumpAndSettle();
        // The menu says the days plainly; the chip says what they are.
        expect(find.text('Today'), findsOne);
        expect(find.text('Tomorrow'), findsOne);
        await tester.tap(find.byKey(FrontTaskSetupKeys.option(0, 'today')));
        await tester.pumpAndSettle();
        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'Due Today');
        await create(tester);
        expect(created.last.due, today);

        await choose(tester, FrontTaskSetupKeys.due(0), 'tomorrow');
        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'Due Tomorrow');
        await create(tester);
        expect(created.last.due, DateTime(2026, 11, 12));

        await choose(tester, FrontTaskSetupKeys.due(0), 'none');
        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'No due date');
        await create(tester);
        expect(created.last.due, isNull);
      });
    });

    testWidgets('today and tomorrow are the days as of the tap: a setup '
        'left open over midnight never saves yesterday', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 11, 23, 59)), () async {
        await pump(tester);
      });
      await withClock(Clock.fixed(DateTime(2026, 11, 12, 0, 1)), () async {
        await choose(tester, FrontTaskSetupKeys.due(0), 'today');
        await create(tester);
        expect(created.last.due, DateTime(2026, 11, 12));

        await choose(tester, FrontTaskSetupKeys.due(0), 'tomorrow');
        await create(tester);
        expect(created.last.due, DateTime(2026, 11, 13));
      });
    });

    testWidgets('another day is picked on the calendar, and named by its '
        'date', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester);
        await choose(tester, FrontTaskSetupKeys.due(0), 'pick');
        expect(find.text('Due Date'), findsOne);

        await tester.tap(find.text('20'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'Due: Nov 20');
        await create(tester);
        expect(created.single.due, DateTime(2026, 11, 20));
      });
    });

    testWidgets('a day in another year names its year, so it never reads '
        'as the same day this year', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(
          tester,
          initial: plain.copyWith(due: () => DateTime(2027, 11, 20)),
        );
        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'Due: Nov 20, 2027');
      });
    });

    testWidgets('a day already set outside the usual range — past, or past '
        'the ten-year horizon — opens on itself, and Done keeps it', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        for (final (due, label) in [
          (DateTime(2026, 11, 9), 'Due: Nov 9'),
          (DateTime(2037, 11, 11), 'Due: Nov 11, 2037'),
        ]) {
          await tester.pumpWidget(const SizedBox());
          await pump(tester, initial: plain.copyWith(due: () => due));
          await choose(tester, FrontTaskSetupKeys.due(0), 'pick');
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();

          expect(labelOf(tester, FrontTaskSetupKeys.due(0)), label);
          await create(tester);
          expect(created.last.due, due);
        }
      });
    });

    testWidgets('a calendar closed without a day leaves the due day as it '
        'was', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pump(tester, initial: plain.copyWith(due: () => today));
        await choose(tester, FrontTaskSetupKeys.due(0), 'pick');

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();

        expect(find.text('Due Date'), findsNothing);
        expect(labelOf(tester, FrontTaskSetupKeys.due(0)), 'Due Today');
      });
    });
  });

  testWidgets('cancel goes back, nothing made', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester);
      await tester.tap(find.byKey(FrontTaskSetupKeys.back(0)));
      expect(backs, 1);
      expect(created, isEmpty);
    });
  });

  testWidgets('while the task is made nothing can change: create spins, '
      'and no chip or cancel answers', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, busy: true);

      final createButton = tester.widget<DesignSystemButton>(
        find.byKey(FrontTaskSetupKeys.create(0)),
      );
      expect(createButton.isLoading, isTrue);
      expect(createButton.onPressed, isNull);
      expect(
        tester
            .widget<DesignSystemButton>(find.byKey(FrontTaskSetupKeys.back(0)))
            .onPressed,
        isNull,
      );
      for (final key in [
        FrontTaskSetupKeys.status(0),
        FrontTaskSetupKeys.priority(0),
        FrontTaskSetupKeys.due(0),
      ]) {
        expect(chip(tester, key).onPressed, isNull);
      }
    });
  });

  testWidgets('a create that did not go through says so in the error ink, '
      'and create can be tapped again', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, failed: true);

      final ask = tester.widget<Text>(find.byKey(FrontTaskSetupKeys.ask(0)));
      expect(ask.data, 'That did not go through.');
      final tokens = tester.element(find.byType(FrontTaskSetup)).designTokens;
      expect(ask.style!.color, tokens.colors.alert.error.ink);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(FrontTaskSetupKeys.create(0)),
            )
            .label,
        'Try again',
      );

      await create(tester);
      expect(created, [plain]);
    });
  });
}
