import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_one_on_one_page.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

/// Creates metrics with truly nullable optional date/duration fields
/// (unlike [makeTestMetrics] which defaults to non-null dates).
TemplatePerformanceMetrics _metrics({
  String templateId = kTestTemplateId,
  int totalWakes = 10,
  int successCount = 8,
  int failureCount = 2,
  double successRate = 0.8,
  Duration? averageDuration = const Duration(seconds: 5),
  DateTime? firstWakeAt,
  DateTime? lastWakeAt,
  int activeInstanceCount = 2,
}) {
  return TemplatePerformanceMetrics(
    templateId: templateId,
    totalWakes: totalWakes,
    successCount: successCount,
    failureCount: failureCount,
    successRate: successRate,
    averageDuration: averageDuration,
    firstWakeAt: firstWakeAt,
    lastWakeAt: lastWakeAt,
    activeInstanceCount: activeInstanceCount,
  );
}

void main() {
  late MockTemplateEvolutionWorkflow mockWorkflow;
  late MockAgentTemplateService mockTemplateService;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
    mockWorkflow = MockTemplateEvolutionWorkflow();
    mockTemplateService = MockAgentTemplateService();
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String templateId = kTestTemplateId,
    TemplatePerformanceMetrics? metrics,
    FutureOr<TemplatePerformanceMetrics> Function(Ref, String)? metricsOverride,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? templateOverride,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? versionOverride,
    List<Override> extraOverrides = const [],
  }) {
    final tpl = makeTestTemplate(id: templateId, agentId: templateId);
    final ver = makeTestTemplateVersion(agentId: templateId);
    final testMetrics = metrics ?? makeTestMetrics(templateId: templateId);

    return makeTestableWidgetNoScroll(
      AgentOneOnOnePage(templateId: templateId),
      overrides: [
        agentTemplateProvider.overrideWith(
          templateOverride ?? (ref, id) async => tpl,
        ),
        activeTemplateVersionProvider.overrideWith(
          versionOverride ?? (ref, id) async => ver,
        ),
        templatePerformanceMetricsProvider.overrideWith(
          metricsOverride ?? (ref, id) async => testMetrics,
        ),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        templateEvolutionWorkflowProvider.overrideWithValue(mockWorkflow),
        agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ...extraOverrides,
      ],
    );
  }

  /// Sets up a tall test surface so all widgets are visible without scrolling.
  void setTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Scrolls down in the CustomScrollView.
  Future<void> scrollDown(WidgetTester tester, {double dy = -400}) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, dy));
    await tester.pumpAndSettle();
  }

  /// Enters feedback text and scrolls to the evolve button.
  Future<void> enterFeedbackAndScrollToEvolve(WidgetTester tester) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'Great reports');
    await tester.pump();
    await scrollDown(tester);
  }

  /// Enters feedback text (for tall surface, no scrolling needed).
  Future<void> enterFeedback(WidgetTester tester) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.first, 'Great reports');
    await tester.pump();
  }

  /// Sets up mock, pumps widget, enters feedback, taps evolve on a tall
  /// surface. Returns the BuildContext for l10n access.
  Future<BuildContext> tapEvolveAndGetProposal(
    WidgetTester tester, {
    String proposedDirectives = 'Improved directives.',
  }) async {
    setTallSurface(tester);

    when(
      () => mockWorkflow.proposeEvolution(
        template: any(named: 'template'),
        currentVersion: any(named: 'currentVersion'),
        metrics: any(named: 'metrics'),
        feedback: any(named: 'feedback'),
      ),
    ).thenAnswer(
      (_) async => EvolutionProposal(
        proposedDirectives: proposedDirectives,
        originalDirectives: 'You are a helpful agent.',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await enterFeedback(tester);

    final context = tester.element(find.byType(AgentOneOnOnePage));

    await tester.tap(find.text(context.messages.agentTemplateEvolveButton));
    await tester.pumpAndSettle();

    return context;
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

    testWidgets('shows empty title when template is null', (tester) async {
      await tester.pumpWidget(
        buildSubject(templateOverride: (ref, id) async => null),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Template'), findsNothing);
    });

    testWidgets('shows metrics dashboard with data', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(context.messages.agentTemplateMetricsTitle),
        findsOneWidget,
      );
      expect(find.text('10'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
    });

    testWidgets('shows "no metrics" when totalWakes is 0', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metrics: _metrics(
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

      await scrollDown(tester);

      final context = tester.element(find.byType(AgentOneOnOnePage));
      final evolveButton = find.text(
        context.messages.agentTemplateEvolveButton,
      );
      expect(evolveButton, findsOneWidget);

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

      await enterFeedbackAndScrollToEvolve(tester);

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

    testWidgets('shows metrics loading state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: (ref, id) =>
              Completer<TemplatePerformanceMetrics>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows metrics error state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: (ref, id) =>
              Future<TemplatePerformanceMetrics>.error(
            Exception('metrics error'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows optional metric cards when data present',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metrics: _metrics(
            averageDuration: const Duration(seconds: 42),
            firstWakeAt: DateTime(2024, 3, 15, 10, 30),
            lastWakeAt: DateTime(2024, 3, 22, 10, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(context.messages.agentTemplateMetricsAvgDuration),
        findsOneWidget,
      );
      expect(find.text('42s'), findsOneWidget);
      expect(
        find.text(context.messages.agentTemplateMetricsFirstWake),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsLastWake),
        findsOneWidget,
      );
    });

    testWidgets('hides optional metric cards when data is null',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(metrics: _metrics(averageDuration: null)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentOneOnOnePage));
      expect(
        find.text(context.messages.agentTemplateMetricsAvgDuration),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsFirstWake),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsLastWake),
        findsNothing,
      );
    });

    group('_handleEvolve', () {
      testWidgets('shows evolving progress during workflow execution',
          (tester) async {
        setTallSurface(tester);

        final completer = Completer<EvolutionProposal?>();
        when(
          () => mockWorkflow.proposeEvolution(
            template: any(named: 'template'),
            currentVersion: any(named: 'currentVersion'),
            metrics: any(named: 'metrics'),
            feedback: any(named: 'feedback'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await enterFeedback(tester);

        final context = tester.element(find.byType(AgentOneOnOnePage));
        await tester.tap(find.text(context.messages.agentTemplateEvolveButton));
        await tester.pump();

        // During workflow, shows progress indicator and text
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text(context.messages.agentTemplateEvolvingProgress),
          findsOneWidget,
        );

        // Complete to avoid dangling future
        completer.complete(null);
        await tester.pumpAndSettle();
      });

      testWidgets('shows proposal preview on success', (tester) async {
        final context = await tapEvolveAndGetProposal(tester);

        expect(
          find.text(context.messages.agentTemplateEvolvePreviewTitle),
          findsOneWidget,
        );
        expect(find.text('Improved directives.'), findsOneWidget);
        expect(find.text('You are a helpful agent.'), findsOneWidget);
      });

      testWidgets('shows error snackbar when template is null', (tester) async {
        setTallSurface(tester);

        await tester.pumpWidget(
          buildSubject(templateOverride: (ref, id) async => null),
        );
        await tester.pumpAndSettle();

        await enterFeedback(tester);

        final context = tester.element(find.byType(AgentOneOnOnePage));
        await tester.tap(find.text(context.messages.agentTemplateEvolveButton));
        await tester.pumpAndSettle();

        expect(
          find.text(context.messages.agentTemplateEvolveError),
          findsOneWidget,
        );
      });

      testWidgets('shows error snackbar when workflow returns null',
          (tester) async {
        setTallSurface(tester);

        when(
          () => mockWorkflow.proposeEvolution(
            template: any(named: 'template'),
            currentVersion: any(named: 'currentVersion'),
            metrics: any(named: 'metrics'),
            feedback: any(named: 'feedback'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await enterFeedback(tester);

        final context = tester.element(find.byType(AgentOneOnOnePage));
        await tester.tap(find.text(context.messages.agentTemplateEvolveButton));
        await tester.pumpAndSettle();

        expect(
          find.text(context.messages.agentTemplateEvolveError),
          findsOneWidget,
        );
      });

      testWidgets('shows error snackbar when workflow throws', (tester) async {
        setTallSurface(tester);

        when(
          () => mockWorkflow.proposeEvolution(
            template: any(named: 'template'),
            currentVersion: any(named: 'currentVersion'),
            metrics: any(named: 'metrics'),
            feedback: any(named: 'feedback'),
          ),
        ).thenThrow(Exception('workflow failed'));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await enterFeedback(tester);

        final context = tester.element(find.byType(AgentOneOnOnePage));
        await tester.tap(find.text(context.messages.agentTemplateEvolveButton));
        await tester.pumpAndSettle();

        expect(
          find.text(context.messages.agentTemplateEvolveError),
          findsOneWidget,
        );
      });
    });

    group('proposal preview', () {
      testWidgets('shows current and proposed directives', (tester) async {
        final context = await tapEvolveAndGetProposal(tester);

        expect(
          find.text(context.messages.agentTemplateEvolveCurrentLabel),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.agentTemplateEvolveProposedLabel),
          findsOneWidget,
        );
        expect(find.text('You are a helpful agent.'), findsOneWidget);
        expect(find.text('Improved directives.'), findsOneWidget);
      });

      testWidgets('reject clears proposal', (tester) async {
        final context = await tapEvolveAndGetProposal(tester);

        await tester.tap(find.text(context.messages.agentTemplateEvolveReject));
        await tester.pumpAndSettle();

        expect(find.text('Improved directives.'), findsNothing);
      });
    });

    group('_handleApprove', () {
      testWidgets('calls createVersion and shows success snackbar',
          (tester) async {
        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
          ),
        ).thenAnswer((_) async => makeTestTemplateVersion(version: 2));

        final context = await tapEvolveAndGetProposal(
          tester,
          proposedDirectives: 'Approved directives.',
        );

        // Capture l10n strings before Navigator.pop() deactivates the context.
        final approveLabel = context.messages.agentTemplateEvolveApprove;

        await tester.tap(find.text(approveLabel));
        await tester.pumpAndSettle();

        verify(
          () => mockTemplateService.createVersion(
            templateId: kTestTemplateId,
            directives: 'Approved directives.',
            authoredBy: 'agent',
          ),
        ).called(1);

        // After approve, Navigator.pop() is called — verify the page
        // is no longer visible.
        expect(find.byType(AgentOneOnOnePage), findsNothing);
      });

      testWidgets('shows error snackbar when createVersion throws',
          (tester) async {
        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
          ),
        ).thenThrow(Exception('create version failed'));

        final context = await tapEvolveAndGetProposal(tester);

        await tester
            .tap(find.text(context.messages.agentTemplateEvolveApprove));
        await tester.pumpAndSettle();

        expect(
          find.text(context.messages.agentTemplateEvolveError),
          findsOneWidget,
        );
      });
    });
  });
}
