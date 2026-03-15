import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/template_selector.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  group('TemplateSelector', () {
    final template1 = makeTestTemplate(
      id: 'tpl-1',
      displayName: 'Task Helper',
    );
    final template2 = makeTestTemplate(
      id: 'tpl-2',
      displayName: 'Research Bot',
    );
    // Improver template — should be filtered out.
    final improverTemplate = AgentDomainEntity.agentTemplate(
      id: 'tpl-improver',
      agentId: 'tpl-improver',
      displayName: 'Improver',
      kind: AgentTemplateKind.templateImprover,
      modelId: 'models/test',
      categoryIds: {},
      createdAt: kAgentTestDate,
      updatedAt: kAgentTestDate,
      vectorClock: null,
    );

    Widget buildWidget({
      String? selectedTemplateId,
      ValueChanged<String?>? onTemplateSelected,
      List<AgentDomainEntity> templates = const [],
    }) {
      return makeTestableWidgetWithScaffold(
        TemplateSelector(
          selectedTemplateId: selectedTemplateId,
          onTemplateSelected: onTemplateSelected ?? (_) {},
        ),
        overrides: [
          agentTemplatesProvider.overrideWith(
            (ref) async => templates,
          ),
        ],
      );
    }

    testWidgets('shows hint text when no template is selected', (tester) async {
      await tester.pumpWidget(
        buildWidget(templates: [template1, template2]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select a template…'), findsOneWidget);
      expect(find.text('Default agent template'), findsOneWidget);
    });

    testWidgets('shows selected template name', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          selectedTemplateId: 'tpl-1',
          templates: [template1, template2],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task Helper'), findsOneWidget);
      expect(find.text('Select a template…'), findsNothing);
    });

    testWidgets('shows clear button when template is selected', (tester) async {
      String? cleared;
      await tester.pumpWidget(
        buildWidget(
          selectedTemplateId: 'tpl-1',
          templates: [template1, template2],
          onTemplateSelected: (id) => cleared = id,
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the clear icon button
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);

      expect(cleared, isNull);
    });

    testWidgets('no clear button when no template selected', (tester) async {
      await tester.pumpWidget(
        buildWidget(templates: [template1]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('opens picker and selects template', (tester) async {
      String? selected;
      await tester.pumpWidget(
        buildWidget(
          templates: [template1, template2],
          onTemplateSelected: (id) => selected = id,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the selector to open the picker
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Both templates should appear in the modal
      expect(find.text('Task Helper'), findsWidgets);
      expect(find.text('Research Bot'), findsOneWidget);

      // Tap on 'Research Bot'
      await tester.tap(find.text('Research Bot'));
      await tester.pumpAndSettle();

      expect(selected, equals('tpl-2'));
    });

    testWidgets('filters out non-taskAgent templates', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          templates: [template1, improverTemplate],
        ),
      );
      await tester.pumpAndSettle();

      // Open picker
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Task Helper'), findsWidgets);
      expect(find.text('Improver'), findsNothing);
    });

    testWidgets('disabled when no templates available', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Select a template…'), findsOneWidget);
      // The InkWell should have a null onTap (disabled)
      final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inkWell.onTap, isNull);
    });

    testWidgets('shows check icon for selected template in picker',
        (tester) async {
      await tester.pumpWidget(
        buildWidget(
          selectedTemplateId: 'tpl-1',
          templates: [template1, template2],
        ),
      );
      await tester.pumpAndSettle();

      // Open picker
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('shows hint when templates are still loading', (tester) async {
      // Use a Completer that never completes to keep the provider in loading
      // state without leaving a pending Timer.
      final completer = Completer<List<AgentDomainEntity>>();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TemplateSelector(
            selectedTemplateId: null,
            onTemplateSelected: (_) {},
          ),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );
      // Don't pumpAndSettle — let it stay in loading state
      await tester.pump();

      // Should show hint text (empty templates → disabled)
      expect(find.text('Select a template…'), findsOneWidget);
    });
  });
}
