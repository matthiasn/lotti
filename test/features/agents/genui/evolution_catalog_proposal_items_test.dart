import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import 'evolution_catalog_test_helpers.dart';

void main() {
  group('EvolutionProposal', () {
    testWidgets('renders proposal with directives and rationale', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'Be concise and helpful.',
            'reportDirective': 'Use bullet points.',
            'rationale': 'Users prefer brevity.',
          }),
        ),
      );

      expect(find.text('Be concise and helpful.'), findsOneWidget);
      expect(find.text('Use bullet points.'), findsOneWidget);
      expect(find.text('Users prefer brevity.'), findsOneWidget);
    });

    testWidgets('renders only general directive when report is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'New general directive',
            'reportDirective': '',
            'rationale': 'Better performance',
          }),
        ),
      );

      expect(find.text('New general directive'), findsOneWidget);
      expect(find.text('Better performance'), findsOneWidget);
      // Report directive section should be absent when empty.
      expect(
        find.textContaining('Report Directive'),
        findsNothing,
      );
    });

    testWidgets('hides directive sections when empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': '',
            'reportDirective': '',
            'rationale': 'Rationale text',
          }),
        ),
      );

      expect(find.text('Rationale text'), findsOneWidget);
      // Both directive sections should be absent when empty.
      expect(
        find.textContaining('General Directive'),
        findsNothing,
      );
      expect(
        find.textContaining('Report Directive'),
        findsNothing,
      );
    });

    testWidgets('renders current general and report directives when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'New general approach.',
            'reportDirective': 'New report format.',
            'rationale': 'Improvement rationale.',
            'currentGeneralDirective': 'Old general approach.',
            'currentReportDirective': 'Old report format.',
          }),
        ),
      );

      // Current directive sections should be present.
      expect(
        find.textContaining('Current Directives'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('General Directive'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('Report Directive'),
        findsNWidgets(2),
      );
      expect(find.text('Old general approach.'), findsOneWidget);
      expect(find.text('Old report format.'), findsOneWidget);
      // Proposed directives should also be present.
      expect(find.text('New general approach.'), findsOneWidget);
      expect(find.text('New report format.'), findsOneWidget);
    });

    testWidgets('renders only current report directive when general is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'New general.',
            'reportDirective': '',
            'rationale': 'Rationale.',
            'currentGeneralDirective': '',
            'currentReportDirective': 'Old report only.',
          }),
        ),
      );

      // Only the report current directive should appear.
      expect(find.text('Old report only.'), findsOneWidget);
      expect(
        find.textContaining('Current Directives'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders only report proposed directive when general is empty',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            buildCatalogWidget(evolutionProposalItem, {
              'generalDirective': '',
              'reportDirective': 'New report directive only.',
              'rationale': 'Report-focused rationale.',
            }),
          ),
        );

        expect(find.text('New report directive only.'), findsOneWidget);
        expect(find.text('Report-focused rationale.'), findsOneWidget);
        // General directive section should be absent.
        expect(
          find.textContaining('General Directive'),
          findsNothing,
        );
        // Proposed Report Directive section should be present.
        expect(
          find.textContaining('Proposed Directives'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    for (final (label, expectedEvent) in [
      ('Approve & Save', 'proposal_approved'),
      ('Reject', 'proposal_rejected'),
    ]) {
      testWidgets('dispatches $expectedEvent on $label tap', (tester) async {
        final events = <UiEvent>[];

        await tester.pumpWidget(
          makeTestableWidget(
            buildCatalogWidgetWithEvents(
              evolutionProposalItem,
              <String, Object?>{
                'generalDirective': 'Test general directive',
                'reportDirective': 'Test report directive',
                'rationale': 'Test rationale',
              },
              events: events,
            ),
          ),
        );

        await tester.tap(find.text(label));
        await tester.pump();

        expect(events, hasLength(1));
        final event = events.first as UserActionEvent;
        expect(event.name, expectedEvent);
      });
    }
  });

  group('SoulProposal', () {
    testWidgets('renders all directive fields and rationale', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'Be warm and clear.',
            'toneBounds': 'Never be sarcastic.',
            'coachingStyle': 'Celebrate wins.',
            'antiSycophancyPolicy': 'Push back firmly.',
            'rationale': 'Personality refinement.',
          }),
        ),
      );

      expect(find.text('Be warm and clear.'), findsOneWidget);
      expect(find.text('Never be sarcastic.'), findsOneWidget);
      expect(find.text('Celebrate wins.'), findsOneWidget);
      expect(find.text('Push back firmly.'), findsOneWidget);
      expect(find.text('Personality refinement.'), findsOneWidget);
    });

    testWidgets('renders only non-empty directive fields', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'Updated voice.',
            'toneBounds': '',
            'coachingStyle': '',
            'antiSycophancyPolicy': '',
            'rationale': 'Voice-only change.',
          }),
        ),
      );

      expect(find.text('Updated voice.'), findsOneWidget);
      expect(find.text('Voice-only change.'), findsOneWidget);

      final context = tester.element(find.byType(Padding).first);
      // Only the Voice field label should appear.
      expect(
        find.textContaining(context.messages.agentSoulFieldVoice),
        findsAtLeastNWidgets(1),
      );
      // Other field labels should be absent.
      expect(
        find.textContaining(context.messages.agentSoulFieldToneBounds),
        findsNothing,
      );
      expect(
        find.textContaining(context.messages.agentSoulFieldCoachingStyle),
        findsNothing,
      );
    });

    testWidgets('renders current vs proposed comparison', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'New voice.',
            'rationale': 'Better personality.',
            'currentVoiceDirective': 'Old voice.',
          }),
        ),
      );

      expect(find.text('Old voice.'), findsOneWidget);
      expect(find.text('New voice.'), findsOneWidget);

      final context = tester.element(find.byType(Padding).first);
      expect(
        find.text(
          context.messages.agentEvolutionSoulCurrentField(
            context.messages.agentSoulFieldVoice,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          context.messages.agentEvolutionSoulProposedField(
            context.messages.agentSoulFieldVoice,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('trims and renders current coaching and anti-sycophancy', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'coachingStyle': 'Celebrate small wins.',
            'antiSycophancyPolicy': 'Disagree when warranted.',
            'rationale': 'Refine coaching and pushback.',
            // Surrounding whitespace proves the `?.trim()` on the current
            // values actually runs (only reached when the value is non-null).
            'currentCoachingStyle': '  Always agree.  ',
            'currentAntiSycophancyPolicy': '\tNever push back.\n',
          }),
        ),
      );

      final context = tester.element(find.byType(Padding).first);

      // Trimmed current values are rendered (no leading/trailing whitespace).
      expect(find.text('Always agree.'), findsOneWidget);
      expect(find.text('Never push back.'), findsOneWidget);
      // Proposed values render alongside.
      expect(find.text('Celebrate small wins.'), findsOneWidget);
      expect(find.text('Disagree when warranted.'), findsOneWidget);

      // The "current" section label appears for both fields.
      expect(
        find.text(
          context.messages.agentEvolutionSoulCurrentField(
            context.messages.agentSoulFieldCoachingStyle,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          context.messages.agentEvolutionSoulCurrentField(
            context.messages.agentSoulFieldAntiSycophancy,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides current section when no current values', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'New voice.',
            'rationale': 'Change.',
          }),
        ),
      );

      final context = tester.element(find.byType(Padding).first);
      // Current section should not appear.
      expect(
        find.textContaining(
          context.messages.agentEvolutionSoulCurrentField(
            context.messages.agentSoulFieldVoice,
          ),
        ),
        findsNothing,
      );
      // Proposed section should appear.
      expect(
        find.textContaining(
          context.messages.agentEvolutionSoulProposedField(
            context.messages.agentSoulFieldVoice,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders cross-template notice', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'New voice.',
            'rationale': 'Update.',
            'crossTemplateNotice':
                'Also affects: Laura Project Analyst, Tom Task Agent',
          }),
        ),
      );

      expect(
        find.text('Also affects: Laura Project Analyst, Tom Task Agent'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hides cross-template notice when absent', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'New voice.',
            'rationale': 'Update.',
          }),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('hides rationale when empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'New voice.',
            'rationale': '',
          }),
        ),
      );

      final context = tester.element(find.byType(Padding).first);
      expect(
        find.text(context.messages.agentEvolutionProposalRationale),
        findsNothing,
      );
    });

    testWidgets('dispatches soul_proposal_approved on approve tap', (
      tester,
    ) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidgetWithEvents(
            soulProposalItem,
            <String, Object?>{
              'voiceDirective': 'Test voice.',
              'rationale': 'Test rationale.',
            },
            events: events,
          ),
        ),
      );

      await tester.tap(find.text('Approve & Save'));
      await tester.pump();

      expect(events, hasLength(1));
      final event = events.first as UserActionEvent;
      expect(event.name, 'soul_proposal_approved');
    });

    testWidgets('dispatches soul_proposal_rejected on reject tap', (
      tester,
    ) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidgetWithEvents(
            soulProposalItem,
            <String, Object?>{
              'voiceDirective': 'Test voice.',
              'rationale': 'Test rationale.',
            },
            events: events,
          ),
        ),
      );

      await tester.tap(find.text('Reject'));
      await tester.pump();

      expect(events, hasLength(1));
      final event = events.first as UserActionEvent;
      expect(event.name, 'soul_proposal_rejected');
    });

    testWidgets('renders title and subtitle from localization', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': 'Voice.',
            'rationale': 'Reason.',
          }),
        ),
      );

      final context = tester.element(find.byType(Padding).first);
      expect(
        find.text(context.messages.agentSoulProposalTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulProposalSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('returns shrink when all directive fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(soulProposalItem, {
            'voiceDirective': '',
            'toneBounds': '',
            'coachingStyle': '',
            'antiSycophancyPolicy': '',
            'rationale': 'Some rationale.',
          }),
        ),
      );

      // No approve/reject buttons should be shown.
      expect(find.text('Approve & Save'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('returns shrink widget for non-map data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final itemContext = CatalogItemContext(
                data: 'not a map', // Non-map data triggers is! Map guard
                id: 'test-component',
                type: 'SoulProposal',
                buildChild: (id, [dataContext]) => const SizedBox.shrink(),
                dispatchEvent: (_) {},
                buildContext: context,
                dataContext: DataContext(InMemoryDataModel(), DataPath.root),
                getComponent: (_) => null,
                getCatalogItem: (_) => null,
                surfaceId: 'test-surface',
                reportError: (_, _) {},
              );
              return soulProposalItem.widgetBuilder(itemContext);
            },
          ),
        ),
      );

      // Should render a zero-size SizedBox from the is! Map guard.
      expect(find.byType(SizedBox), findsWidgets);
      // No proposal card content should be present.
      expect(find.text('Approve & Save'), findsNothing);
    });
  });
}
