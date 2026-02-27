import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Widget buildSubject({
    List<AgentDomainEntity> templates = const [],
    List<AgentDomainEntity> agents = const [],
    List<AgentDomainEntity> evolutions = const [],
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentSettingsPage(),
      overrides: [
        agentTemplatesProvider.overrideWith(
          (ref) async => templates,
        ),
        activeTemplateVersionProvider.overrideWith(
          (ref, templateId) async => makeTestTemplateVersion(
            agentId: templateId,
          ),
        ),
        allAgentInstancesProvider.overrideWith(
          (ref) async => agents,
        ),
        allEvolutionSessionsProvider.overrideWith(
          (ref) async => evolutions,
        ),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(false),
        ),
        templateForAgentProvider.overrideWith(
          (ref, agentId) async => null,
        ),
        ...extraOverrides,
      ],
    );
  }

  group('AgentSettingsPage', () {
    testWidgets('shows Templates tab by default with template cards',
        (tester) async {
      final laura = makeTestTemplate(
        id: 'tpl-laura',
        agentId: 'tpl-laura',
        displayName: 'Laura',
      );
      final tom = makeTestTemplate(
        id: 'tpl-tom',
        agentId: 'tpl-tom',
        displayName: 'Tom',
      );

      await tester.pumpWidget(
        buildSubject(templates: [laura, tom]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.agentTemplatesTitle),
        findsOneWidget,
      );
      expect(find.text('Laura'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
    });

    testWidgets('shows empty state when no templates', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.agentTemplateEmptyList),
        findsOneWidget,
      );
    });

    testWidgets('switches to Instances tab and shows agent cards',
        (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-a',
        agentId: 'agent-a',
        displayName: 'Worker Agent',
      );

      await tester.pumpWidget(
        buildSubject(agents: [agent]),
      );
      await tester.pumpAndSettle();

      // Tap on Instances tab
      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentInstancesTitle));
      await tester.pumpAndSettle();

      expect(find.text('Worker Agent'), findsOneWidget);
    });

    testWidgets('instances tab shows evolution sessions', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'evo-001',
        sessionNumber: 3,
      );

      await tester.pumpWidget(
        buildSubject(evolutions: [session]),
      );
      await tester.pumpAndSettle();

      // Switch to Instances tab
      final context = tester.element(find.byType(AgentSettingsPage));
      await tester.tap(find.text(context.messages.agentInstancesTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentEvolutionSessionTitle(3)),
        findsOneWidget,
      );
    });

    testWidgets('template card shows kind badge and model ID', (tester) async {
      final template = makeTestTemplate(
        id: 'tpl-1',
        agentId: 'tpl-1',
        displayName: 'My Template',
      );

      await tester.pumpWidget(
        buildSubject(templates: [template]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.agentTemplateKindTaskAgent),
        findsOneWidget,
      );
      expect(find.text('models/gemini-3-flash-preview'), findsOneWidget);
    });

    testWidgets('has FAB for creating templates', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows error state when templates fail to load',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSettingsPage(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) async => throw Exception('load failed'),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => null,
            ),
            allAgentInstancesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.commonError),
        findsOneWidget,
      );
    });

    testWidgets('shows version number on template card', (tester) async {
      final template = makeTestTemplate(
        id: 'tpl-ver',
        agentId: 'tpl-ver',
        displayName: 'Versioned Template',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSettingsPage(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) async => [template],
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => makeTestTemplateVersion(
                agentId: templateId,
                version: 3,
              ),
            ),
            allAgentInstancesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSettingsPage));
      expect(
        find.text(context.messages.agentTemplateVersionLabel(3)),
        findsOneWidget,
      );
    });

    testWidgets('tapping template card navigates to template detail',
        (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final template = makeTestTemplate(
        id: 'tpl-nav',
        agentId: 'tpl-nav',
        displayName: 'Nav Template',
      );

      await tester.pumpWidget(buildSubject(templates: [template]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nav Template'));
      expect(navigatedPath, '/settings/agents/templates/tpl-nav');
    });
  });
}
