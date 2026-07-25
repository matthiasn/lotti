import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_sections.dart';

import '../../../widget_test_utils.dart';

const _templateId = 'template-1';
const _reportsEmpty = 'No reports yet.';

void main() {
  // These sections render inside a scrolling detail page, so replacing settled
  // content with a centred spinner on a background refresh collapses the
  // section's height and jumps everything below it. The provider refetches
  // whenever a report lands — exactly when the user is likely to be reading.
  group('ReportsTabContent', () {
    testWidgets('renders the settled empty state once the reports resolve', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const ReportsTabContent(templateId: _templateId),
          overrides: [
            templateRecentReportsProvider.overrideWith(
              (ref, templateId) async => const <AgentDomainEntity>[],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(_reportsEmpty), findsOneWidget);
    });

    testWidgets('keeps the settled content on screen while reports refresh', (
      tester,
    ) async {
      // A *reload* — a watched dependency changing — is the risky path.
      // `templateRecentReports` watches `agentUpdateStreamProvider`, so every
      // agent update re-runs it. (`invalidate` is a *refresh*, which
      // AsyncValue.when already skips loading for by default, so driving one
      // here would prove nothing.)
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      // The reload never resolves, so the widget stays in the loading state
      // rather than racing a resolution.
      final reload = Completer<List<AgentDomainEntity>>();
      addTearDown(() {
        if (!reload.isCompleted) reload.complete(const []);
      });
      var builds = 0;

      final testable = makeTestableWidgetWithContainer(
        const ReportsTabContent(templateId: _templateId),
        overrides: [
          agentUpdateStreamProvider.overrideWith(
            (ref, id) => updates.stream,
          ),
          templateRecentReportsProvider.overrideWith((ref, templateId) {
            // Mirrors the real provider's dependency, which is what makes a
            // stream emission a reload rather than a refresh.
            ref.watch(agentUpdateStreamProvider(templateId));
            builds++;
            if (builds == 1) return Future.value(const <AgentDomainEntity>[]);
            return reload.future;
          }),
        ],
      );
      addTearDown(testable.container.dispose);

      await tester.pumpWidget(testable.widget);
      await tester.pump();
      expect(find.text(_reportsEmpty), findsOneWidget);

      updates.add({_templateId});
      // Two pumps: the first lets the reload propagate, the second lets the
      // widget rebuild with the resulting state. Asserting after only one
      // reads the previous frame and passes whatever the widget would do.
      await tester.pump();
      await tester.pump();

      expect(builds, 2, reason: 'the provider did not actually reload');
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a background reload replaced settled content with a spinner',
      );
      expect(find.text(_reportsEmpty), findsOneWidget);
    });
  });
}
