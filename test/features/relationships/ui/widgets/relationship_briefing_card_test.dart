import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/screenshot_harness.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(() async {
    // Real font metrics: the band-label measurement below is only
    // meaningful against Inter, not the test placeholder face whose glyphs
    // are all the same (much wider) box. Awaited: `loadAppFonts` is async,
    // and an unawaited call leaves the placeholder face installed while the
    // measurement runs.
    await loadAppFonts();
    registerAllFallbackValues();
    registerFallbackValue(
      RelationshipEntry(
        meta: Metadata(
          id: 'fallback',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          dateFrom: DateTime(2026),
          dateTo: DateTime(2026),
        ),
        data: RelationshipData(
          title: 'fallback',
          status: RelationshipStatus.active(
            id: 's',
            createdAt: DateTime(2026),
            utcOffset: 0,
          ),
        ),
      ),
    );
  });

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  final testDate = DateTime(2026, 8, 1, 9);

  late MockRelationshipAgentService agentService;

  RelationshipEntry relationship({bool important = true}) => RelationshipEntry(
    meta: Metadata(
      id: relationshipId,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: 'Anna',
      important: important,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  AgentReportEntity report({
    String? tldr,
    String content = 'Full briefing.',
    String? band = 'needsAttention',
    String rationale = 'Two difficult calls in a row.',
    String scope = AgentReportScopes.current,
    DateTime? deletedAt,
  }) =>
      AgentDomainEntity.agentReport(
            id: 'report-1',
            agentId: agentId,
            scope: scope,
            createdAt: DateTime(2026, 8, 15),
            vectorClock: null,
            content: content,
            tldr: tldr,
            deletedAt: deletedAt,
            provenance: {
              RelationshipReportProvenanceKeys.healthBand: ?band,
              RelationshipReportProvenanceKeys.healthRationale: rationale,
            },
          )
          as AgentReportEntity;

  setUp(() {
    agentService = MockRelationshipAgentService();
    when(
      () => agentService.requestBriefing(any()),
    ).thenAnswer((_) async {});
  });

  Widget build({
    RelationshipEntry? entry,
    AgentReportEntity? current,
    String? disclosureProviderName,
    String agentDisplayName = "Anna's companion",
    bool identityResolves = true,
  }) => makeTestableWidgetWithScaffold(
    RelationshipBriefingCard(relationship: entry ?? relationship()),
    overrides: [
      agentReportProvider(agentId).overrideWith((ref) async => current),
      agentIdentityProvider(agentId).overrideWith(
        (ref) async => identityResolves
            ? makeTestIdentity(
                agentId: agentId,
                kind: AgentKinds.relationshipAgent,
                displayName: agentDisplayName,
              )
            : null,
      ),
      relationshipAgentServiceProvider.overrideWithValue(agentService),
      relationshipBriefingDisclosureProvider(
        relationshipId,
      ).overrideWith((ref) async => disclosureProviderName),
    ],
  );

  /// Every string the widget tree actually paints, markdown already
  /// resolved — the only way to tell "rendered as Markdown" apart from
  /// "printed the source".
  Iterable<String> paintedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

  final cardFinder = find.byKey(
    const ValueKey('relationship-briefing-card'),
  );

  group('gating', () {
    testWidgets('renders nothing for an unimportant person with no briefing — '
        'no advertising a feature they are not enrolled in', (tester) async {
      await tester.pumpWidget(build(entry: relationship(important: false)));
      await tester.pumpAndSettle();
      expect(cardFinder, findsNothing);
    });

    testWidgets('a standing briefing keeps the card even after importance is '
        'switched off — the report is still theirs to read', (tester) async {
      await tester.pumpWidget(
        build(
          entry: relationship(important: false),
          current: report(tldr: 'You last spoke two weeks ago.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(cardFinder, findsOneWidget);
    });

    testWidgets('an important person with no briefing gets the empty line, '
        'not an empty report body', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(cardFinder, findsOneWidget);
      expect(find.byType(TldrBody), findsNothing);
      expect(
        find.textContaining('No briefing yet'),
        findsOneWidget,
      );
    });

    testWidgets('a superseded report is not the current briefing', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          current: report(scope: 'archived', tldr: 'Old news.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TldrBody), findsNothing);
      expect(find.textContaining('No briefing yet'), findsOneWidget);
    });

    testWidgets('a soft-deleted report is not the current briefing', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          current: report(tldr: 'Retracted.', deletedAt: DateTime(2026, 8, 16)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TldrBody), findsNothing);
      expect(find.textContaining('No briefing yet'), findsOneWidget);
    });
  });

  group('AI card chrome', () {
    testWidgets('wears the shared AI card decoration, not a bespoke surface', (
      tester,
    ) async {
      await tester.pumpWidget(build(current: report(tldr: 'Short version.')));
      await tester.pumpAndSettle();

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: cardFinder,
              matching: find.byType(DecoratedBox),
              matchRoot: true,
            )
            .first,
      );
      expect(
        box.decoration,
        aiCardDecoration(tester.element(cardFinder)),
        reason: 'the briefing is the same panel as the task and goal cards',
      );
    });

    testWidgets('the header is the shared identity block titled "Briefing", '
        'carrying the agent name below it', (tester) async {
      await tester.pumpWidget(build(current: report(tldr: 'Short version.')));
      await tester.pumpAndSettle();

      expect(find.byType(TldrHeader), findsOneWidget);
      expect(find.text('Briefing'), findsOneWidget);
      expect(
        find.text('AI summary'),
        findsNothing,
        reason: 'the briefing names itself, it is not a task summary',
      );
      expect(find.text("Anna's companion"), findsOneWidget);
    });

    testWidgets('an agent named after the person leaves the subtitle empty — '
        'the app bar above already says "Anna"', (tester) async {
      await tester.pumpWidget(
        build(
          current: report(tldr: 'Short version.'),
          agentDisplayName: 'Anna',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TldrHeader>(find.byType(TldrHeader)).agentName,
        isNull,
        reason: 'the relationship agent is named after the person it watches',
      );
      expect(find.text('Anna'), findsNothing);
    });

    testWidgets('a display name that has diverged from the person is still '
        'shown — it carries information the app bar does not', (tester) async {
      await tester.pumpWidget(
        build(
          current: report(tldr: 'Short version.'),
          agentDisplayName: 'Anna Sørensen (old)',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anna Sørensen (old)'), findsOneWidget);
    });

    testWidgets('an unresolved identity leaves the header nameless rather '
        'than blank-lined', (tester) async {
      await tester.pumpWidget(
        build(current: report(tldr: 'Short version.'), identityResolves: false),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TldrHeader>(find.byType(TldrHeader)).agentName,
        isNull,
      );
      expect(find.text('Briefing'), findsOneWidget);
    });
  });

  group('health chip', () {
    Future<DsPill> pumpBand(WidgetTester tester, String band) async {
      await tester.pumpWidget(build(current: report(band: band)));
      await tester.pumpAndSettle();
      return tester.widget<DsPill>(
        find.byKey(const ValueKey('relationship-health-chip')),
      );
    }

    testWidgets('thriving reads as its own label, tinted with success', (
      tester,
    ) async {
      final pill = await pumpBand(tester, 'thriving');
      expect(pill.label, 'Thriving');
      expect(
        pill.color,
        tester
            .element(cardFinder)
            .designTokens
            .colors
            .alert
            .success
            .defaultColor,
      );
    });

    testWidgets('steady reads as its own label, tinted with the AI accent', (
      tester,
    ) async {
      final pill = await pumpBand(tester, 'steady');
      expect(pill.label, 'Steady');
      expect(
        pill.color,
        tester.element(cardFinder).designTokens.colors.aiCard.accent,
      );
    });

    testWidgets('needs attention reads as its own label, tinted with warning', (
      tester,
    ) async {
      final pill = await pumpBand(tester, 'needsAttention');
      expect(pill.label, 'Needs attention');
      expect(
        pill.color,
        tester
            .element(cardFinder)
            .designTokens
            .colors
            .alert
            .warning
            .defaultColor,
      );
    });

    testWidgets('strained reads as its own label, tinted with error', (
      tester,
    ) async {
      final pill = await pumpBand(tester, 'strained');
      expect(pill.label, 'Strained');
      expect(
        pill.color,
        tester.element(cardFinder).designTokens.colors.alert.error.defaultColor,
      );
    });

    testWidgets('the pill sits in the card body, not the header rail whose '
        'half-width cap would ellipsize a longer band label', (tester) async {
      await tester.pumpWidget(build(current: report()));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TldrHeader),
          matching: find.byKey(const ValueKey('relationship-health-chip')),
        ),
        findsNothing,
      );
      expect(
        tester.widget<TldrHeader>(find.byType(TldrHeader)).trailing,
        isNull,
      );
    });

    testWidgets('the band label stays whole on a small phone at a raised '
        'text scale, in the longest locale we ship', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 900) * 3
        ..devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          // The page insets the card by `step5` on each side; measuring
          // without that would hand the pill room it never gets.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RelationshipBriefingCard(relationship: relationship()),
          ),
          locale: const Locale('de'),
          mediaQueryData: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          overrides: [
            agentReportProvider(agentId).overrideWith((ref) async => report()),
            agentIdentityProvider(agentId).overrideWith((ref) async => null),
            relationshipAgentServiceProvider.overrideWithValue(agentService),
            relationshipBriefingDisclosureProvider(
              relationshipId,
            ).overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(cardFinder);
      final label = find.descendant(
        of: find.byKey(const ValueKey('relationship-health-chip')),
        matching: find.byType(Text),
      );
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
        reason: 'a truncated health verdict is the card losing its headline',
      );

      // Non-vacuous: the pill genuinely needs more than the header rail
      // could ever have given it, so this passes because the pill left the
      // rail — not because "Braucht Aufmerksamkeit" happens to be short.
      final headerContentWidth =
          tester.getSize(find.byType(TldrHeader)).width -
          (context.designTokens.spacing.cardPadding * 2);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('relationship-health-chip')))
            .width,
        greaterThan(headerContentWidth / 2),
      );
    });

    testWidgets('the chip explains itself through the model rationale', (
      tester,
    ) async {
      await tester.pumpWidget(build(current: report()));
      await tester.pumpAndSettle();
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('relationship-health-chip')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'Two difficult calls in a row.');
    });

    testWidgets('a report with no parseable band shows no chip at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(current: report(band: null, tldr: 'Short version.')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('relationship-health-chip')),
        findsNothing,
      );
    });
  });

  group('briefing prose', () {
    testWidgets('renders the briefing as Markdown — the reader never sees the '
        'hashes and asterisks the model wrote', (tester) async {
      await tester.pumpWidget(
        build(
          current: report(
            tldr: '## State of the relationship\n\n**Anna** is drifting.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsWidgets);
      final painted = paintedText(tester).toList();
      expect(
        painted.any((text) => text.contains('State of the relationship')),
        isTrue,
      );
      expect(
        painted.any((text) => text.contains('Anna')),
        isTrue,
      );
      expect(
        painted.where((text) => text.contains('##') || text.contains('**')),
        isEmpty,
        reason: 'markdown syntax on screen is the bug this fixes',
      );
    });

    testWidgets('the summary is the report tldr when it has one', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(current: report(tldr: 'You last spoke two weeks ago.')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AgentMarkdownView>(find.byType(AgentMarkdownView)).text,
        'You last spoke two weeks ago.',
      );
    });

    testWidgets('the full content stands in when the run produced no tldr', (
      tester,
    ) async {
      await tester.pumpWidget(build(current: report()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AgentMarkdownView>(find.byType(AgentMarkdownView)).text,
        'Full briefing.',
      );
      expect(
        find.text('Read more'),
        findsNothing,
        reason: 'there is nothing further to disclose',
      );
    });

    testWidgets('a full text identical to the tldr offers no disclosure', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          current: report(tldr: 'Same words.', content: 'Same words.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsNothing);
    });

    testWidgets('an empty full text offers no disclosure either', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          current: report(tldr: 'Only a summary.', content: '   '),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsNothing);
      expect(
        tester.widget<AgentMarkdownView>(find.byType(AgentMarkdownView)).text,
        'Only a summary.',
      );
    });
  });

  group('disclosure', () {
    Future<void> pumpExpandable(WidgetTester tester) async {
      await tester.pumpWidget(
        build(
          current: report(
            tldr: 'Short version.',
            content: 'The **long** version.',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Read more reveals the full briefing and flips its own label', (
      tester,
    ) async {
      await pumpExpandable(tester);
      expect(find.byType(AgentMarkdownView), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('relationship-briefing-expand')),
      );
      await tester.pumpAndSettle();

      final views = tester
          .widgetList<AgentMarkdownView>(find.byType(AgentMarkdownView))
          .map((view) => view.text)
          .toList();
      expect(views, ['Short version.', 'The **long** version.']);
      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
    });

    testWidgets('Show less collapses it again', (tester) async {
      await pumpExpandable(tester);
      final disclosure = find.byKey(
        const ValueKey('relationship-briefing-expand'),
      );
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.byType(AgentMarkdownView), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('the expanded body offers the way into the agent internals', (
      tester,
    ) async {
      await pumpExpandable(tester);
      expect(find.text('Open agent internals'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('relationship-briefing-expand')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open agent internals'), findsOneWidget);
    });
  });

  group('agent internals', () {
    Widget buildWithInternals() => makeTestableWidgetNoScroll(
      RelationshipBriefingCard(relationship: relationship()),
      overrides: [
        agentReportProvider(agentId).overrideWith(
          (ref) async => report(
            tldr: 'Short version.',
            content: 'The long version.',
          ),
        ),
        agentIdentityProvider.overrideWith(
          (ref, id) async => makeTestIdentity(
            agentId: id,
            kind: AgentKinds.relationshipAgent,
            displayName: "Anna's companion",
          ),
        ),
        agentStateProvider.overrideWith((ref, id) async => null),
        relationshipAgentServiceProvider.overrideWithValue(agentService),
        relationshipBriefingDisclosureProvider(
          relationshipId,
        ).overrideWith((ref) async => null),
      ],
    );

    testWidgets('tapping the card identity opens the internals panel', (
      tester,
    ) async {
      await tester.pumpWidget(buildWithInternals());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Briefing'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentInternalsPanel), findsOneWidget);
      expect(
        tester
            .widget<AgentInternalsPanel>(
              find.byType(AgentInternalsPanel),
            )
            .agentId,
        agentId,
      );
    });

    testWidgets('so does the expanded body link', (tester) async {
      await tester.pumpWidget(buildWithInternals());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('relationship-briefing-expand')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open agent internals'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentInternalsPanel), findsOneWidget);
    });
  });

  group('actions footer', () {
    testWidgets('the chat entry beams to the person-scoped chat route', (
      tester,
    ) async {
      final beamedTo = <String>[];
      beamToNamedOverride = beamedTo.add;
      addTearDown(() => beamToNamedOverride = null);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('relationship-chat-button')));
      expect(beamedTo, ['/people/$relationshipId/chat']);
    });

    testWidgets('Brief me on a LOCAL route runs without any dialog', (
      tester,
    ) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      verify(() => agentService.requestBriefing(any())).called(1);
      expect(find.textContaining('Briefing requested'), findsOneWidget);
    });

    testWidgets('Brief me on a CLOUD route names the provider first and only '
        'proceeds on consent (ADR 0037)', (tester) async {
      await tester.pumpWidget(build(disclosureProviderName: 'Melious'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Melious'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => agentService.requestBriefing(any()));

      await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      verify(() => agentService.requestBriefing(any())).called(1);
    });

    testWidgets('a failed request surfaces the error toast instead of '
        'silence', (tester) async {
      when(
        () => agentService.requestBriefing(any()),
      ).thenAnswer((_) async => throw StateError('wake enqueue failed'));
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('relationship-brief-me')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not request'), findsOneWidget);
    });

    testWidgets('an in-flight request disables Brief me, so a second tap '
        'cannot enqueue a second wake', (tester) async {
      final gate = Completer<void>();
      when(
        () => agentService.requestBriefing(any()),
      ).thenAnswer((_) => gate.future);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('relationship-brief-me'));
      await tester.tap(button);
      await tester.pump();

      expect(
        tester.widget<DesignSystemButton>(button).onPressed,
        isNull,
        reason: 'the control has to say the request is already running',
      );
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      verify(() => agentService.requestBriefing(any())).called(1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<DesignSystemButton>(button).onPressed,
        isNotNull,
        reason: 'and hand the action back once it finishes',
      );
    });
  });
}
