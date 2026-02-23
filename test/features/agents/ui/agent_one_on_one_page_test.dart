import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_one_on_one_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String templateId = kTestTemplateId,
    TemplatePerformanceMetrics? metrics,
    List<Override> extraOverrides = const [],
  }) {
    final template = makeTestTemplate(id: templateId, agentId: templateId);
    final version = makeTestTemplateVersion(agentId: templateId);
    final testMetrics = metrics ?? makeTestMetrics(templateId: templateId);

    return makeTestableWidgetNoScroll(
      AgentOneOnOnePage(templateId: templateId),
      overrides: [
        agentTemplateProvider.overrideWith(
          (ref, id) async => template,
        ),
        activeTemplateVersionProvider.overrideWith(
          (ref, id) async => version,
        ),
        templatePerformanceMetricsProvider.overrideWith(
          (ref, id) async => testMetrics,
        ),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        ...extraOverrides,
      ],
    );
  }

  group('AgentOneOnOnePage', () {
    testWidgets('shows page title with template name', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(
          context.messages.agentTemplateOneOnOneTitle('Test Template'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows metrics dashboard with data', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(context.messages.agentTemplateMetricsTitle),
        findsOneWidget,
      );
      // Total wakes
      expect(find.text('10'), findsOneWidget);
      // Success rate
      expect(find.text('80.0%'), findsOneWidget);
    });

    testWidgets('shows "no metrics" when totalWakes is 0', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metrics: makeTestMetrics(
            totalWakes: 0,
            successCount: 0,
            failureCount: 0,
            successRate: 0,
            averageDuration: null,
            activeInstanceCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(context.messages.agentTemplateNoMetrics),
        findsOneWidget,
      );
    });

    testWidgets('shows feedback form fields', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(context.messages.agentTemplateFeedbackTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateFeedbackEnjoyedLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateFeedbackDidntWorkLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateFeedbackChangesLabel),
        findsOneWidget,
      );
    });

    testWidgets('evolve button is disabled when all feedback empty',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Scroll down to reveal the evolve button.
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      final evolveButton = find.text(
        context.messages.agentTemplateEvolveButton,
      );
      expect(evolveButton, findsOneWidget);

      // LottiPrimaryButton uses FilledButton internally.
      final buttonWidget = tester.widget<FilledButton>(
        find.ancestor(
          of: evolveButton,
          matching: find.byType(FilledButton),
        ),
      );
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('evolve button enables after entering feedback',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Enter text in first TextField (enjoyed field).
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
      await tester.enterText(textFields.first, 'Great reports');
      await tester.pump();

      // Scroll down to reveal the evolve button.
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      final evolveButton = find.text(
        context.messages.agentTemplateEvolveButton,
      );
      final buttonWidget = tester.widget<FilledButton>(
        find.ancestor(
          of: evolveButton,
          matching: find.byType(FilledButton),
        ),
      );
      expect(buttonWidget.onPressed, isNotNull);
    });
  });
}
