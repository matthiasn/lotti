import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/agents/ui/knowledge/agent_knowledge_panel.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_persona_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page_header.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agent_status_chip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_week_strip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/screenshot_harness.dart';
import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';
import 'day_page_test_helpers.dart';

/// Layout tests for the day header's custom render object
/// (`day_page_header.dart`): when the toggle rides the title row, when day
/// navigation takes a row of its own, and when the actions drop below the
/// toggle. Driven through [DayPage], which is what builds that header.
void main() {
  // The header's break points are text-width driven, so pin the production
  // fonts rather than inheriting whatever the run happened to load: font
  // loading is process-wide and irreversible, so the ambient default is not a
  // stable baseline in a bundled run.
  setUpAll(loadAppFonts);

  group('DayHeader layout', () {
    testWidgets(
      'phone: the masthead leads its row with the actions at its end; the '
      'week strip, then the toggle, beneath',
      (tester) async {
        setTestSurfaceSize(tester, const Size(390, 844));
        await tester.pumpWidget(
          wrapDayPage(
            DayPage(draft: draftedPlan(), navigation: _navigation()),
            mediaQueryData: phoneMediaQueryData.copyWith(
              size: const Size(390, 844),
            ),
          ),
        );
        await tester.pump();

        final masthead = tester.getRect(_masthead);
        final filter = tester.getRect(
          find.byType(ProcessingCategoryFilterButton),
        );
        final strip = tester.getRect(find.byType(DayWeekStrip));
        final toggle = tester.getRect(find.byType(PlanViewToggle));

        expect(filter.left, greaterThan(masthead.right));
        expect(filter.top, lessThan(masthead.bottom));
        expect(strip.top, greaterThanOrEqualTo(masthead.bottom));
        expect(toggle.top, greaterThanOrEqualTo(strip.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'wide: the toggle joins the masthead row, the week strip beneath it',
      (tester) async {
        setTestSurfaceSize(tester, const Size(1024, 900));
        await tester.pumpWidget(
          wrapDayPage(
            DayPage(draft: draftedPlan(), navigation: _navigation()),
            mediaQueryData: phoneMediaQueryData.copyWith(
              size: const Size(1024, 900),
            ),
          ),
        );
        await tester.pump();

        final masthead = tester.getRect(_masthead);
        final toggle = tester.getRect(find.byType(PlanViewToggle));
        final strip = tester.getRect(find.byType(DayWeekStrip));

        expect(toggle.left, greaterThan(masthead.right));
        expect(toggle.center.dy, closeTo(masthead.center.dy, 0.5));
        expect(strip.top, greaterThanOrEqualTo(masthead.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a masthead row too narrow for the actions sends them after the toggle, '
      'never over it',
      (tester) async {
        // Large text and the "Needs attention" pill make the actions too
        // wide to sit beside the masthead on a phone.
        setTestSurfaceSize(tester, const Size(390, 900));
        await tester.pumpWidget(
          wrapDayPage(
            DayPage(draft: draftedPlan(), navigation: _navigation()),
            mediaQueryData: phoneMediaQueryData.copyWith(
              size: const Size(390, 900),
              textScaler: const TextScaler.linear(1.3),
            ),
            overrides: [
              dayAgentPersonaStateProvider.overrideWith(
                (ref, date) async => DayAgentPersonaState.attention,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final masthead = tester.getRect(_masthead);
        final strip = tester.getRect(find.byType(DayWeekStrip));
        final toggle = tester.getRect(find.byType(PlanViewToggle));
        final actions = tester.getRect(
          find.byType(ProcessingCategoryFilterButton),
        );
        expect(actions.top, greaterThanOrEqualTo(masthead.bottom));
        expect(actions.top, greaterThanOrEqualTo(strip.bottom));
        expect(
          toggle.overlaps(actions),
          isFalse,
          reason: 'the toggle and the header actions must never overlap',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('without day navigation there is no week strip', (
      tester,
    ) async {
      setTestSurfaceSize(tester, phoneMediaQueryData.size);
      await tester.pumpWidget(
        wrapDayPage(
          DayPage(draft: draftedPlan()),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.pump();

      expect(find.byType(DayWeekStrip), findsNothing);
      expect(find.text('May 26'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('the nav row', () {
      testWidgets(
        'carries the chevron and the actions on one centre line, the '
        'masthead and toggle beneath',
        (tester) async {
          setTestSurfaceSize(tester, phoneMediaQueryData.size);
          await tester.pumpWidget(
            wrapDayPage(
              DayPage(draft: draftedPlan()),
              mediaQueryData: phoneMediaQueryData,
            ),
          );
          await tester.pump();

          final back = tester.getRect(
            find.byTooltip(
              tester.element(find.byType(DayPage)).messages.dailyOsNextDayBack,
            ),
          );
          final filter = tester.getRect(
            find.byType(ProcessingCategoryFilterButton),
          );
          final title = tester.getRect(find.text('May 26'));
          final toggle = tester.getRect(find.byType(PlanViewToggle));

          expect(filter.center.dy, closeTo(back.center.dy, 0.5));
          expect(title.top, greaterThanOrEqualTo(back.bottom));
          expect(toggle.left, greaterThan(title.right));
          expect(toggle.top, greaterThanOrEqualTo(back.bottom));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'keeps the masthead and the content below on one rail, and the '
        'actions flush with the toolbar edge',
        (tester) async {
          setTestSurfaceSize(tester, phoneMediaQueryData.size);
          await tester.pumpWidget(
            wrapDayPage(
              DayPage(draft: draftedPlan()),
              mediaQueryData: phoneMediaQueryData,
            ),
          );
          await tester.pump();

          final tokens = tester.element(find.byType(DayPage)).designTokens;
          final rail = tokens.spacing.step5;
          final title = tester.getRect(find.text('May 26'));
          final menu = tester.getRect(find.byIcon(LottiIcons.moreVertical));

          expect(title.left, closeTo(rail, 1));
          expect(
            phoneMediaQueryData.size.width - menu.center.dx,
            closeTo(rail + kMinInteractiveDimension / 2, 1),
          );
          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets('header relayouts when design-system spacing changes', (
      tester,
    ) async {
      // Tall enough that the inflated spacing — which every surface on the
      // page also uses — still leaves the body below room of its own.
      setTestSurfaceSize(tester, const Size(640, 1200));
      final mediaQueryData = phoneMediaQueryData.copyWith(
        size: const Size(640, 1200),
      );
      Future<double> titleTopAt(double step2) async {
        await tester.pumpWidget(
          wrapDayPage(
            DayPage(draft: draftedPlan(), navigation: _navigation()),
            mediaQueryData: mediaQueryData,
            theme: themeWithHeaderSpacing(step2),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        return tester.getTopLeft(find.text('May 26')).dy;
      }

      final first = await titleTopAt(20);
      final second = await titleTopAt(32);

      expect(second, greaterThan(first));
      expect(tester.takeException(), isNull);
    });
  });

  group('DayHeader masthead', () {
    // The plan's day is Tuesday, May 26 2026; `today` moves around it.
    for (final (today, overline) in [
      (DateTime(2026, 5, 26), 'Today · Tuesday'),
      (DateTime(2026, 5, 25), 'Tomorrow · Tuesday'),
      (DateTime(2026, 5, 27), 'Yesterday · Tuesday'),
      (DateTime(2026, 5, 20), 'Tuesday'),
      (DateTime(2026, 6, 2), 'Tuesday'),
      (DateTime(2027, 1, 4), 'Tuesday · 2026'),
    ]) {
      testWidgets('reads "$overline" over the date when today is '
          '${today.toIso8601String().substring(0, 10)}', (tester) async {
        await _pumpHeader(tester, navigation: _navigation(today: today));

        expect(find.text(overline), findsOneWidget);
        expect(find.text('May 26'), findsOneWidget);
      });
    }

    testWidgets('a tomorrow across a new year is still Tomorrow, no year', (
      tester,
    ) async {
      await _pumpHeader(
        tester,
        draftDay: DateTime(2027),
        navigation: _navigation(today: DateTime(2026, 12, 31)),
      );

      expect(find.text('Tomorrow · Friday'), findsOneWidget);
      expect(find.text('January 1'), findsOneWidget);
    });

    testWidgets('sets the date in heading2 with tabular figures', (
      tester,
    ) async {
      await _pumpHeader(tester, navigation: _navigation());
      final tokens = tester.element(find.byType(DayPage)).designTokens;

      final title = tester.widget<Text>(find.text('May 26'));
      expect(
        title.style?.fontSize,
        tokens.typography.styles.heading.heading2.fontSize,
      );
      expect(title.style?.color, tokens.colors.text.highEmphasis);
      expect(
        title.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('a tap opens the picker, a long press returns to today', (
      tester,
    ) async {
      var picks = 0;
      var todays = 0;
      await _pumpHeader(
        tester,
        navigation: _navigation(
          onPick: () => picks++,
          onToday: () => todays++,
        ),
      );

      await tester.tap(_masthead);
      expect((picks, todays), (1, 0));

      await tester.longPress(_masthead);
      expect((picks, todays), (1, 1));
    });

    testWidgets('without day navigation the masthead is not a button', (
      tester,
    ) async {
      await _pumpHeader(tester);

      expect(find.text('May 26'), findsOneWidget);
      expect(_masthead, findsNothing);
    });
  });

  group('DayHeader week strip', () {
    testWidgets('a tapped day is handed to the navigation', (tester) async {
      final selected = <DateTime>[];
      await _pumpHeader(
        tester,
        navigation: _navigation(onSelect: selected.add),
      );

      await tester.tap(
        find.byKey(
          ValueKey(
            'daily_os_week_strip_${DateTime(2026, 5, 28).toIso8601String()}',
          ),
        ),
      );

      expect(selected, [DateTime(2026, 5, 28)]);
    });

    for (final (width, chevrons) in [(1400.0, true), (390.0, false)]) {
      testWidgets(
        '${chevrons ? 'carries' : 'leaves out'} the week chevrons at '
        '${width.toInt()} px',
        (tester) async {
          await _pumpHeader(
            tester,
            size: Size(width, 900),
            navigation: _navigation(),
          );

          expect(
            find.byKey(const Key('daily_os_week_strip_next')),
            chevrons ? findsOneWidget : findsNothing,
          );
        },
      );
    }
  });

  group('DayHeader menu', () {
    testWidgets('the knowledge entry opens what the planner has learned', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(1024, 900));
      final learned =
          AgentDomainEntity.plannerKnowledge(
                id: 'k-krill',
                agentId: 'daily_os_planner',
                key: 'krill-mornings',
                hook: 'hook',
                statementText: 'Krill deliveries go better before 10am',
                source: KnowledgeSource.agentInferred,
                status: KnowledgeStatus.confirmed,
                createdAt: DateTime(2026, 5, 20),
                updatedAt: DateTime(2026, 5, 20),
                vectorClock: null,
              )
              as PlannerKnowledgeEntity;
      await tester.pumpWidget(
        wrapDayPage(
          DayPage(draft: draftedPlan()),
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(1024, 900),
          ),
          overrides: [
            agentKnowledgeProvider(dailyOsPlannerAgentId).overrideWith(
              (ref) async => AgentKnowledgeView(
                confirmed: [learned],
                proposed: const [],
              ),
            ),
            agentKnowledgeServiceProvider.overrideWithValue(
              MockAgentKnowledgeService(),
            ),
          ],
        ),
      );
      await tester.pump();
      final messages = tester.element(find.byType(DayPage)).messages;

      await tester.tap(find.byIcon(LottiIcons.moreVertical));
      await tester.pumpAndSettle();
      // The unified menu every agent surface opens, not a Material popup.
      expect(
        find.ancestor(
          of: find.text(messages.agentKnowledgeTitle),
          matching: find.byType(DesignSystemContextMenu),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(messages.agentKnowledgeTitle));
      await tester.pumpAndSettle();

      expect(find.byType(AgentKnowledgePanel), findsOneWidget);
      expect(
        find.text('Krill deliveries go better before 10am'),
        findsOneWidget,
      );
    });
  });
  group('DayHeader companion', () {
    testWidgets('she leads the actions, level with the agent chip', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(1024, 900));
      await tester.pumpWidget(
        wrapDayPage(
          DayPage(draft: draftedPlan()),
          mediaQueryData: phoneMediaQueryData.copyWith(
            size: const Size(1024, 900),
          ),
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(
                flagName == enableCompanionFlag ||
                    flagName == enableAiSummaryTtsFlag,
              ),
            ),
            ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
            spokenTrackLoaderProvider.overrideWithValue(
              (clip, text) => Completer<MouthTrack>().future,
            ),
          ],
        ),
      );
      // Her ticker never settles: pump frames rather than settle.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final her = tester.getRect(find.byType(CompanionSpeaker));
      final chip = tester.getRect(find.byType(DayAgentStatusChip));
      expect(her.right, lessThanOrEqualTo(chip.left));
      expect(her.center.dy, closeTo(chip.center.dy, 0.5));
      expect(tester.takeException(), isNull);
    });
  });
}

final Finder _masthead = find.byKey(const Key('daily_os_day_masthead'));

DayNavigation _navigation({
  DateTime? today,
  ValueChanged<DateTime>? onSelect,
  VoidCallback? onPick,
  VoidCallback? onToday,
}) => DayNavigation(
  today: today ?? DateTime(2026, 5, 26),
  onSelect: onSelect ?? (_) {},
  onPick: onPick ?? () {},
  onToday: onToday ?? () {},
);

Future<void> _pumpHeader(
  WidgetTester tester, {
  DayNavigation? navigation,
  DateTime? draftDay,
  Size size = const Size(1024, 900),
}) async {
  setTestSurfaceSize(tester, size);
  final draft = draftedPlan();
  await tester.pumpWidget(
    wrapDayPage(
      DayPage(
        draft: draftDay == null ? draft : draft.copyWith(dayDate: draftDay),
        navigation: navigation,
      ),
      mediaQueryData: phoneMediaQueryData.copyWith(size: size),
    ),
  );
  await tester.pump();
}
