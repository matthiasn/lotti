import 'dart:ui' show Tristate;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 7, 16, 9);

  Widget subject({
    bool automaticUpdatesEnabled = false,
    bool automationBusy = false,
    bool inferenceAvailable = true,
    bool isRunning = false,
    bool showCountdown = false,
    DateTime? nextWakeAt,
    bool hasReportContent = false,
    bool isStale = false,
    bool compact = false,
    ValueChanged<bool>? onAutomaticUpdatesChanged,
    VoidCallback? onRunNow,
    VoidCallback? onSkipScheduledUpdate,
    VoidCallback? onCountdownExpired,
  }) {
    return AgentAutomationRow(
      automaticUpdatesEnabled: automaticUpdatesEnabled,
      automationBusy: automationBusy,
      inferenceAvailable: inferenceAvailable,
      isRunning: isRunning,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
      hasReportContent: hasReportContent,
      isStale: isStale,
      compact: compact,
      onAutomaticUpdatesChanged: onAutomaticUpdatesChanged ?? (_) {},
      onRunNow: onRunNow,
      onSkipScheduledUpdate: onSkipScheduledUpdate ?? () {},
      onCountdownExpired: onCountdownExpired ?? () {},
    );
  }

  /// Pumps [child] at an explicit measure. The view — not `MediaQuery` — is
  /// what actually sizes the surface, so the fit decision under test sees the
  /// width the test names.
  Future<void> pumpRow(
    WidgetTester tester,
    Widget child, {
    double width = 730,
    Locale? locale,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    tester.view
      ..physicalSize = Size(width, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      makeTestableWidget(
        child,
        mediaQueryData: MediaQueryData(
          size: Size(width, 1200),
          textScaler: textScaler,
        ),
        locale: locale,
      ),
    );
  }

  Finder trigger() => find.byKey(const ValueKey('taskAgentWakeButton'));
  Finder toggle() => find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox'));
  Finder scheduleLabel() =>
      find.byKey(const ValueKey('taskAgentScheduleLabel'));

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(AgentAutomationRow)).designTokens;

  testWidgets('compact mode keeps freshness and the manual action only', (
    tester,
  ) async {
    await pumpRow(
      tester,
      subject(
        compact: true,
        automaticUpdatesEnabled: true,
        showCountdown: true,
        nextWakeAt: now.add(const Duration(hours: 1)),
        hasReportContent: true,
      ),
    );

    expect(
      find.byKey(const ValueKey('agentAutomationRowCompact')),
      findsOneWidget,
    );
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(toggle(), findsNothing);
    expect(scheduleLabel(), findsNothing);
  });

  group('manual trigger', () {
    testWidgets('is labelled, glyphed and fires the callback', (tester) async {
      var runs = 0;
      await pumpRow(tester, subject(onRunNow: () => runs++));

      expect(find.text('Update now'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      await tester.tap(trigger());
      expect(runs, 1);
    });

    testWidgets('stays live and in the same slot while a wake is scheduled', (
      tester,
    ) async {
      var runs = 0;
      var skips = 0;
      late Offset idleOffset;

      await withClock(Clock.fixed(now), () async {
        await pumpRow(tester, subject(onRunNow: () => runs++));
        idleOffset = tester.getTopLeft(trigger());

        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () => runs++,
            onSkipScheduledUpdate: () => skips++,
          ),
        );

        // The scheduled update is information beside the action, not instead
        // of it: the trigger keeps its slot and stays pressable.
        expect(find.text('Update now'), findsOneWidget);
        expect(tester.getTopLeft(trigger()), idleOffset);
        expect(find.textContaining('1:30'), findsOneWidget);

        await tester.tap(trigger());
        expect(runs, 1);
        expect(skips, 0, reason: 'running by hand must not cancel the wake');
      });
    });

    testWidgets('swaps to the thinking label in place while running', (
      tester,
    ) async {
      await pumpRow(tester, subject(onRunNow: () {}));
      final idleRect = tester.getRect(trigger());

      await pumpRow(tester, subject(isRunning: true, onRunNow: () {}));

      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.text('Update now'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Same slot, same height — a run in flight must not reflow the row.
      expect(trigger(), findsOneWidget);
      expect(tester.getRect(trigger()).height, idleRect.height);
      expect(
        tester.widget<DesignSystemButton>(trigger()).onPressed,
        isNull,
        reason: 'a run already in flight has nothing to re-trigger',
      );
    });

    testWidgets('is disabled, not hidden, when no AI setup is available', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(inferenceAvailable: false, onRunNow: () {}),
      );

      expect(trigger(), findsOneWidget);
      expect(tester.widget<DesignSystemButton>(trigger()).onPressed, isNull);
      final toggleWidget = tester.widget<DesignSystemToggle>(toggle());
      expect(toggleWidget.enabled, isFalse);
      expect(
        toggleWidget.tooltipMessage,
        'Choose an AI setup before turning on automatic updates.',
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('automatic-updates switch', () {
    testWidgets('reports changes and keeps a full-size interaction slot', (
      tester,
    ) async {
      bool? changedTo;
      await pumpRow(
        tester,
        subject(onAutomaticUpdatesChanged: (value) => changedTo = value),
      );

      await tester.tap(toggle());
      expect(changedTo, isTrue);

      final tokens = tokensOf(tester);
      final target = find.byKey(
        const ValueKey('taskAgentAutomaticUpdatesTarget'),
      );
      // The row is the target, not a box beside the switch. An earlier
      // revision reserved a step9 square around a 24px-tall track and left it
      // inert: it cost the column 48px of height while the only tappable part
      // stayed the track. Now the whole row height is real, and it is one
      // step8 box like every other row in the band.
      expect(tester.getSize(target).height, tokens.spacing.step8);
      expect(
        tester.getSize(target).width,
        greaterThan(tokens.spacing.step9 * 2),
      );

      // Tapping the label, not the switch, must toggle it too.
      changedTo = null;
      await tester.tap(find.text('Automatic updates'));
      expect(changedTo, isTrue);
    });

    testWidgets('the enlarged row target adds no second focus stop', (
      tester,
    ) async {
      await pumpRow(tester, subject());

      // Excluding semantics does nothing to focus traversal. Without an
      // explicit opt-out the pointer-only wrapper is its own focusable node,
      // so Tab stops twice on one setting and both stops toggle it.
      final focusables = tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('taskAgentAutomationSetting')),
              matching: find.byType(InkWell),
            ),
          )
          .where((ink) => ink.canRequestFocus)
          .length;

      expect(
        focusables,
        1,
        reason: 'only the switch itself may take keyboard focus',
      );
    });

    testWidgets('the whole row is one actionable node for assistive tech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      bool? changedTo;
      await pumpRow(
        tester,
        subject(onAutomaticUpdatesChanged: (value) => changedTo = value),
      );

      // Enlarging the pointer target is not enough on its own: with the row's
      // semantics excluded and the label inert, the only actionable node was
      // the switch's own 40x24 track, so touch exploration never reached the
      // advertised full-row target.
      final node = tester.getSemantics(
        find.byKey(const ValueKey('taskAgentAutomationSetting')),
      );
      final data = node.getSemanticsData();
      expect(data.label, 'Automatic updates');
      // A switch that is off: applicable, and currently false.
      expect(data.flagsCollection.isToggled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      // One node, not two: the label must not announce separately from the
      // control it belongs to.
      final rowRect = tester.getRect(
        find.byKey(const ValueKey('taskAgentAutomaticUpdatesTarget')),
      );
      // Both dimensions, not just width: a node as wide as the row but only
      // as tall as the switch would still leave the label unreachable by
      // touch exploration. Size only — `SemanticsNode.rect` is in the node's
      // own coordinate space, so its origin is (0,0) by construction and
      // comparing it to a global rect would assert nothing.
      expect(node.rect.size.width, moreOrLessEquals(rowRect.width, epsilon: 1));
      expect(
        node.rect.size.height,
        moreOrLessEquals(rowRect.height, epsilon: 1),
      );

      await tester.tap(find.text('Automatic updates'));
      expect(changedTo, isTrue);
      handle.dispose();
    });

    testWidgets('is disabled while an automation write is in flight', (
      tester,
    ) async {
      await pumpRow(tester, subject(automationBusy: true));
      expect(tester.widget<DesignSystemToggle>(toggle()).enabled, isFalse);
    });
  });

  group('freshness', () {
    testWidgets('is omitted entirely without report content', (tester) async {
      await pumpRow(tester, subject());

      expect(find.byKey(const ValueKey('taskAgentStaleGlyph')), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsNothing);
      expect(
        find.byKey(const ValueKey('taskAgentFreshnessLabel')),
        findsNothing,
      );
    });

    testWidgets('carries a word, not just a glyph, in both states', (
      tester,
    ) async {
      for (final (stale, glyphKey, label, tooltip) in [
        (
          true,
          'taskAgentStaleGlyph',
          'Out of date',
          'This summary is out of date',
        ),
        (
          false,
          'taskAgentFreshGlyph',
          'Up to date',
          'Summary is up to date',
        ),
      ]) {
        await pumpRow(
          tester,
          subject(hasReportContent: true, isStale: stale, onRunNow: () {}),
        );

        expect(find.byKey(ValueKey(glyphKey)), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(
          tester
              .widget<Tooltip>(
                find.ancestor(
                  of: find.byKey(ValueKey(glyphKey)),
                  matching: find.byType(Tooltip),
                ),
              )
              .message,
          tooltip,
        );
      }
    });

    testWidgets('spends the alert tint on the glyph, never on the word', (
      tester,
    ) async {
      // The band is a settings zone; it must not out-chroma the content it
      // sits under. Tinting the word as well made the footer the loudest
      // thing on the card and, in dark, lowered the word's own contrast.
      for (final (stale, label) in [
        (true, 'Out of date'),
        (false, 'Up to date'),
      ]) {
        await pumpRow(
          tester,
          subject(hasReportContent: true, isStale: stale, onRunNow: () {}),
        );
        final tokens = tokensOf(tester);

        expect(
          tester.widget<Text>(find.text(label)).style?.color,
          tokens.colors.aiCard.bodyText,
          reason: 'the freshness word reads as state, not as an alert',
        );
      }

      // The distinction still has to be visible somewhere, so the glyph — and
      // only the glyph — changes ink between the two states.
      for (final (stale, glyphKey, tint) in [
        (
          true,
          'taskAgentStaleGlyph',
          (DsTokens t) => t.colors.alert.warning.defaultColor,
        ),
        (
          false,
          'taskAgentFreshGlyph',
          (DsTokens t) => t.colors.aiCard.metaText,
        ),
      ]) {
        await pumpRow(
          tester,
          subject(hasReportContent: true, isStale: stale, onRunNow: () {}),
        );
        expect(
          tester.widget<Icon>(find.byKey(ValueKey(glyphKey))).color,
          tint(tokensOf(tester)),
        );
      }
    });

    testWidgets('shares the trigger baseline when they fit one line', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(hasReportContent: true, isStale: true, onRunNow: () {}),
      );

      expect(
        tester.getCenter(find.text('Out of date')).dy,
        moreOrLessEquals(tester.getCenter(trigger()).dy, epsilon: 2),
      );
    });
  });

  group('schedule line', () {
    testWidgets('offers Skip, which cancels only the pending wake', (
      tester,
    ) async {
      var skips = 0;
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
            onSkipScheduledUpdate: () => skips++,
          ),
        );

        // A worded action, not a bare glyph beside the switch it does not
        // control.
        expect(find.text('Skip once'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
        );
        expect(skips, 1);
      });
    });

    testWidgets('inks Skip no quieter than the value it cancels', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
        );
        final tokens = tokensOf(tester);
        final skip = tester.widget<Text>(find.text('Skip once')).style;

        // An action rendered fainter than the static text beside it inverts
        // the two, so Skip shares the countdown's register rather than
        // dropping to metadata ink.
        expect(skip?.color, tokens.colors.aiCard.bodyText);
        // ...and the affordance is the shared hover fill, not a third
        // "this is tappable" dialect in a band that already has two.
        expect(skip?.decoration, anyOf(isNull, TextDecoration.none));
        // Accent still means "this starts work" — and Skip stops it.
        expect(skip?.color, isNot(tokens.colors.aiCard.accent));
      });
    });

    testWidgets('resyncs in place when the deadline moves', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
        );
        expect(find.textContaining('1:30'), findsOneWidget);

        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(seconds: 45)),
            onRunNow: () {},
          ),
        );
        expect(find.textContaining('0:45'), findsOneWidget);
        expect(find.textContaining('1:30'), findsNothing);
      });
    });

    testWidgets('reports expiry once for an already-passed deadline', (
      tester,
    ) async {
      var expiries = 0;
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.subtract(const Duration(seconds: 1)),
            onRunNow: () {},
            onCountdownExpired: () => expiries++,
          ),
        );
        await tester.pump();
      });

      expect(find.textContaining('Next update in'), findsNothing);
      expect(expiries, 1);
    });

    testWidgets('says what happens next when nothing is pending', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(automaticUpdatesEnabled: true, onRunNow: () {}),
      );

      // The line is reserved rather than appearing and disappearing as the
      // user flips the switch.
      expect(find.text('Updates on changes'), findsOneWidget);
    });

    testWidgets('says nothing about the next update while one is running', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(
          automaticUpdatesEnabled: true,
          isRunning: true,
          onRunNow: () {},
        ),
      );

      // The trigger already reads "Thinking…"; promising a future update
      // beside it describes a settled state the card is not in.
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.text('Updates on changes'), findsNothing);
      expect(scheduleLabel(), findsNothing);
    });

    testWidgets('is absent while automatic updates are off', (tester) async {
      await pumpRow(tester, subject(onRunNow: () {}));
      expect(scheduleLabel(), findsNothing);
    });

    testWidgets('never reports an expiry it does not have', (tester) async {
      var expiries = 0;
      await pumpRow(
        tester,
        subject(
          automaticUpdatesEnabled: true,
          onRunNow: () {},
          onCountdownExpired: () => expiries++,
        ),
      );
      await tester.pump();

      // "Updates on changes" has no deadline behind it; treating
      // it as an expired countdown would loop the card through rebuilds.
      expect(find.text('Updates on changes'), findsOneWidget);
      expect(expiries, 0);
    });
  });

  group('responsive behaviour', () {
    testWidgets('the idle automation promise fits a narrow goal surface', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(automaticUpdatesEnabled: true, onRunNow: () {}),
        width: 320,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(1.3),
      );

      expect(find.text('Aktualisiert bei Änderungen'), findsOneWidget);
      final label = tester.widget<Text>(scheduleLabel());
      expect(label.maxLines, 2);
      expect(label.softWrap, isTrue);
      expect(tester.getSize(scheduleLabel()).width, 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops schedule prose before it drops the countdown value', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          width: 320,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
        );

        // The sentence gives way, but the time itself is still on screen and
        // is not truncated.
        expect(find.text('Nächste Aktualisierung in 1:30'), findsNothing);
        expect(find.textContaining('1:30'), findsOneWidget);
        final label = tester.widget<Text>(scheduleLabel());
        expect(label.overflow, isNot(TextOverflow.ellipsis));
        expect(label.softWrap, isFalse);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('stacks the trigger and the switch when they cannot share', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          width: 320,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
        );

        expect(
          find.byKey(const ValueKey('taskAgentAutomationRowStacked')),
          findsOneWidget,
        );
        // Stacked, every group shares the leading edge instead of being flung
        // to opposite ends of a wrapped run.
        final left = tester
            .getTopLeft(find.byKey(const ValueKey('taskAgentStatusCluster')))
            .dx;
        for (final group in [
          const ValueKey('taskAgentScheduleCluster'),
          const ValueKey('taskAgentAutomationSetting'),
        ]) {
          expect(
            tester.getTopLeft(find.byKey(group)).dx,
            moreOrLessEquals(left),
            reason: '$group left the shared leading edge',
          );
        }
      });
    });

    testWidgets('stacked, the trigger and the switch share a trailing rail', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            onRunNow: () {},
          ),
          width: 390,
        );

        expect(
          find.byKey(const ValueKey('taskAgentAutomationRowStacked')),
          findsOneWidget,
        );
        // The point of the stacked form: the manual trigger terminates on the
        // same rail as the switch below it. Left-packed against the status
        // word — which is what it used to do — the two controls landed at
        // unrelated x positions and the band read as clutter.
        expect(
          tester.getBottomRight(trigger()).dx,
          moreOrLessEquals(
            tester.getBottomRight(toggle()).dx,
            epsilon: 0.5,
          ),
          reason: 'the trigger and the switch do not share a trailing rail',
        );
        // ...while the status word it describes keeps the leading edge, so the
        // pair spans the band rather than clustering at either end.
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('taskAgentStatusCluster')))
              .dx,
          moreOrLessEquals(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('taskAgentAutomationSetting')),
                )
                .dx,
            epsilon: 0.5,
          ),
          reason: 'the status word left the leading column',
        );
      });
    });

    testWidgets('a rule separates the two questions only when stacked', (
      tester,
    ) async {
      const rule = ValueKey('taskAgentAutomationRowRule');
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            onRunNow: () {},
          ),
          width: 390,
        );
        expect(find.byKey(rule), findsOneWidget);
        // The rule sits between the two bands, not above or below both.
        final ruleY = tester.getCenter(find.byKey(rule)).dy;
        expect(ruleY, greaterThan(tester.getCenter(trigger()).dy));
        expect(ruleY, lessThan(tester.getCenter(toggle()).dy));
        // The schedule readout belongs to the switch that governs it, so it
        // sits below the rule too. Above it, the countdown read as a footnote
        // to the manual trigger — the one control it has nothing to do with.
        expect(
          tester.getCenter(scheduleLabel()).dy,
          greaterThan(ruleY),
          reason: 'the schedule line left the automation band',
        );

        // One line needs no rule: the two questions are already at opposite
        // ends of the same row, and a horizontal rule cannot separate them.
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          width: 1400,
        );
        expect(
          find.byKey(const ValueKey('taskAgentAutomationRowWide')),
          findsOneWidget,
        );
        expect(find.byKey(rule), findsNothing);
      });
    });

    testWidgets('every stacked row starts on one leading column', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            isStale: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          width: 320,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
        );

        // The trigger is a DS button that pays its own content inset, so a
        // button box on the edge puts its glyph inside it. The row negates
        // that inset; this is the assertion that keeps it honest, because the
        // break is only visible once the row stacks.
        final column = tester
            .getTopLeft(find.byKey(const ValueKey('taskAgentStatusCluster')))
            .dx;
        expect(
          tester.getTopLeft(find.byIcon(Icons.refresh_rounded)).dx,
          moreOrLessEquals(column, epsilon: 0.5),
          reason: 'the trigger glyph left the leading column',
        );
        expect(
          tester.getTopLeft(scheduleLabel()).dx,
          moreOrLessEquals(column, epsilon: 0.5),
          reason: 'the schedule readout left the leading column',
        );
        expect(
          tester.getTopLeft(find.text('Automatische Aktualisierungen')).dx,
          moreOrLessEquals(column, epsilon: 0.5),
          reason: 'the switch label left the leading column',
        );
      });
    });

    testWidgets('keeps one line when the measure genuinely allows it', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          // Generous: the test font is far wider per glyph than Inter, so a
          // production-realistic 730px here would stack for the wrong reason.
          width: 1400,
        );

        expect(
          find.byKey(const ValueKey('taskAgentAutomationRowWide')),
          findsOneWidget,
        );
        expect(
          tester.getCenter(scheduleLabel()).dy,
          moreOrLessEquals(tester.getCenter(toggle()).dy, epsilon: 1),
        );
      });
    });

    testWidgets(
      'survives every width, locale and text scale without overflow',
      (
        tester,
      ) async {
        for (final (width, locale, scale) in [
          (320.0, 'de', 1.3),
          (320.0, 'en', 1.0),
          (390.0, 'de', 1.2),
          (730.0, 'de', 1.3),
          (900.0, 'en', 1.0),
        ]) {
          for (final state in ['idle', 'running', 'countdown']) {
            await withClock(Clock.fixed(now), () async {
              await pumpRow(
                tester,
                subject(
                  hasReportContent: true,
                  isStale: state == 'idle',
                  isRunning: state == 'running',
                  automaticUpdatesEnabled: state == 'countdown',
                  showCountdown: state == 'countdown',
                  nextWakeAt: state == 'countdown'
                      ? now.add(const Duration(minutes: 1, seconds: 30))
                      : null,
                  onRunNow: () {},
                ),
                width: width,
                locale: Locale(locale),
                textScaler: TextScaler.linear(scale),
              );
            });

            expect(
              tester.takeException(),
              isNull,
              reason: '$state at ${width}px $locale ×$scale overflowed',
            );
            expect(
              trigger(),
              findsOneWidget,
              reason: 'trigger vanished at ${width}px $locale ×$scale',
            );
            expect(
              toggle(),
              findsOneWidget,
              reason: 'switch vanished at ${width}px $locale ×$scale',
            );
          }
        }
      },
    );
  });

  testWidgets('a ticking countdown moves nothing around it', (tester) async {
    var clockNow = DateTime(2026, 7, 16, 9);
    await withClock(Clock(() => clockNow), () async {
      await pumpRow(
        tester,
        subject(
          hasReportContent: true,
          automaticUpdatesEnabled: true,
          showCountdown: true,
          nextWakeAt: clockNow.add(const Duration(hours: 1)),
          onRunNow: () {},
        ),
      );

      expect(find.text('Next update in 1:00:00'), findsOneWidget);
      expect(
        tester.widget<Text>(scheduleLabel()).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final labelSize = tester.getSize(scheduleLabel());
      final triggerOffset = tester.getTopLeft(trigger());
      final toggleOffset = tester.getTopLeft(toggle());
      final skipOffset = tester.getTopLeft(find.text('Skip once'));

      // Crosses the h:mm:ss → m:ss boundary, where the label's own text gets
      // materially shorter.
      clockNow = clockNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Next update in 59:59'), findsOneWidget);
      expect(tester.getSize(scheduleLabel()), labelSize);
      expect(tester.getTopLeft(trigger()), triggerOffset);
      expect(tester.getTopLeft(toggle()), toggleOffset);
      expect(tester.getTopLeft(find.text('Skip once')), skipOffset);
    });
  });
}
