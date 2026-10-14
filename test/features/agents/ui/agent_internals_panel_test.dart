import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_helper.dart';
import '../test_data/entity_factories.dart';

/// The `AgentInternalsPanel` is a thin re-housing of `AgentInternalsBody`
/// inside the shared side sheet. The body itself is exercised by the
/// existing `AgentDetailPage` test suite — these tests focus on the
/// panel's chrome and lifecycle:
///
/// * a tap on the scrim and the close icon both dismiss it
/// * the body switches in once the identity provider resolves
/// * width is clamped between `minPanelWidth` and `maxPanelWidth`.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(
    WidgetTester tester, {
    required List<Override> overrides,
    Size screenSize = const Size(900, 800),
    bool passAgentName = true,
  }) async {
    final identity = makeTestIdentity();
    tester.view
      ..physicalSize = screenSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        mediaQueryData: MediaQueryData(size: screenSize),
        overrides: [
          ...overrides,
          agentIdentityProvider.overrideWith(
            (ref, agentId) async => identity,
          ),
        ],
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => AgentInternalsPanel.show(
                context: context,
                agentId: identity.agentId,
                agentName: passAgentName ? identity.displayName : null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('AgentInternalsPanel', () {
    testWidgets('conversation threads expand on the panel material surface', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
          agentMessagesByThreadProvider.overrideWith(
            (ref, agentId) async => {
              'habitat-thread': [
                makeTestMessage(
                  threadId: 'habitat-thread',
                  contentEntryId: 'habitat-thought',
                ),
              ],
            },
          ),
          agentReportHistoryProvider.overrideWith((ref, agentId) async => []),
          agentMessagePayloadTextProvider.overrideWith(
            (ref, id) async => 'The habitat pressure remains stable.',
          ),
        ],
      );
      await tester.tap(find.text('Conversations'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final thread = find.textContaining('1 messages');
      final content = find.textContaining(
        'The habitat pressure remains stable.',
      );
      await tester.tap(find.text('Thought'));
      await tester.pumpAndSettle();
      expect(content, findsOneWidget);
      await tester.tap(thread);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(content, findsNothing);
      await tester.tap(thread);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Thought'));
      await tester.pumpAndSettle();
      expect(content, findsOneWidget);
    });

    testWidgets('renders the localized title and the agent display name', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );

      expect(find.text('Agent internals'), findsOneWidget);
      expect(find.text('Test Agent'), findsOneWidget);
    });

    testWidgets('hosts the AgentInternalsBody once identity resolves', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );

      // The body itself owns the tab strip.
      expect(find.byType(AgentInternalsBody), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('close icon button pops the route', (tester) async {
      await pumpPanel(
        tester,
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );
      expect(find.text('Agent internals'), findsOneWidget);

      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pumpAndSettle();

      expect(find.text('Agent internals'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a tap on the scrim beside the panel dismisses it', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        screenSize: const Size(1600, 900),
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );
      expect(find.text('Agent internals'), findsOneWidget);

      // Left of the panel: the dimmed page.
      await tester.tapAt(const Offset(40, 450));
      await tester.pumpAndSettle();

      expect(find.text('Agent internals'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('without a passed name the header shows the resolved agent '
        'name', (tester) async {
      await pumpPanel(
        tester,
        passAgentName: false,
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );

      expect(find.text('Test Agent'), findsOneWidget);
    });

    testWidgets('panel width is clamped to the configured range', (
      tester,
    ) async {
      // Half of a very wide window is more than the panel needs.
      await pumpPanel(
        tester,
        screenSize: const Size(2000, 900),
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );
      final panel = tester.getRect(find.byType(AgentInternalsPanel));
      expect(panel.width, AgentInternalsPanel.maxPanelWidth);
      expect(panel.right, 2000);
    });

    testWidgets('a narrow desktop window still gets the minimum width', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        screenSize: const Size(1000, 800),
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );
      expect(
        tester.getSize(find.byType(AgentInternalsPanel)).width,
        AgentInternalsPanel.minPanelWidth,
      );
    });

    testWidgets('a phone gets the panel as a full-width bottom sheet', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        screenSize: const Size(390, 844),
        overrides: [
          agentStateProvider.overrideWith((ref, agentId) async => null),
        ],
      );
      expect(tester.getSize(find.byType(AgentInternalsPanel)).width, 390);
    });
  });

  group('AgentInternalsPanel – identity fallbacks', () {
    testWidgets('shows the not-found message once identity resolves to null', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: const MediaQueryData(size: Size(900, 800)),
          overrides: [
            agentIdentityProvider.overrideWith((ref, agentId) async => null),
            agentStateProvider.overrideWith((ref, agentId) async => null),
          ],
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AgentInternalsPanel.show(
                  context: context,
                  agentId: 'agent-001',
                  agentName: null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The localized "not found" copy comes from the same key the
      // standalone detail page uses.
      expect(find.text('Agent not found.'), findsOneWidget);
      // The body should not be present in the not-found case.
      expect(find.byType(AgentInternalsBody), findsNothing);
    });

    testWidgets('shows the error message when identity provider throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: const MediaQueryData(size: Size(900, 800)),
          overrides: [
            agentIdentityProvider.overrideWith(
              (ref, agentId) async => Future.error(Exception('nope')),
            ),
            agentStateProvider.overrideWith((ref, agentId) async => null),
          ],
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AgentInternalsPanel.show(
                  context: context,
                  agentId: 'agent-001',
                  agentName: 'Task Laura',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading agent'), findsOneWidget);
      expect(find.byType(AgentInternalsBody), findsNothing);
      // The provided agentName is still surfaced in the header subtitle
      // even when identity resolution fails.
      expect(find.text('Task Laura'), findsOneWidget);
    });
  });
}
