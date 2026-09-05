import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_info_tab.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

const _soulId = 'soul-1';
const _noSessions = 'No soul evolution sessions yet';
const _noVersions = 'No versions';

/// Overrides every provider [InfoTabContent] reads, so a test only has to say
/// how the one it cares about behaves. [evolutionHistory] and [versionHistory]
/// replace the corresponding default when given.
List<Override> _overrides({
  Override? evolutionHistory,
  Override? versionHistory,
}) => [
  evolutionHistory ??
      soulEvolutionSessionHistoryProvider.overrideWith(
        (ref, soulId) async => const <RitualSessionHistoryEntry>[],
      ),
  versionHistory ??
      soulVersionHistoryProvider.overrideWith(
        (ref, soulId) async => const <AgentDomainEntity>[],
      ),
  activeSoulVersionProvider.overrideWith((ref, soulId) async => null),
  templatesUsingSoulProvider.overrideWith(
    (ref, soulId) async => const <String>[],
  ),
  agentTemplateProvider.overrideWith((ref, templateId) async => null),
];

Widget _subject() => InfoTabContent(soulId: _soulId, onDelete: () {});

void main() {
  // Both history sections sit in a scrolling detail page. Swapping settled
  // content for a centred spinner on a background refresh collapses the
  // section and shifts everything below it, so each has to render stale
  // content through the reload. An empty-but-resolved list proves it just as
  // well as a populated one: the empty-state text would be replaced by the
  // spinner all the same.
  group('InfoTabContent', () {
    testWidgets(
      'renders both settled empty states once the providers resolve',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(_subject(), overrides: _overrides()),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(_noSessions), findsOneWidget);
        expect(find.text(_noVersions), findsOneWidget);
      },
    );

    // A *reload* — a watched dependency changing — is the risky path. Both
    // history providers watch `agentUpdateStreamProvider`, so every agent
    // update re-runs them. (`invalidate` is a *refresh*, which AsyncValue.when
    // already skips loading for by default, so driving one proves nothing.)
    //
    // Each case wires one provider to a controllable stream and leaves the
    // other at its default, so a failure names the section that regressed.

    testWidgets('keeps the soul evolution history on screen while it reloads', (
      tester,
    ) async {
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final reload = Completer<List<RitualSessionHistoryEntry>>();
      addTearDown(() {
        if (!reload.isCompleted) reload.complete(const []);
      });
      var builds = 0;

      final testable = makeTestableWidgetWithContainer(
        _subject(),
        overrides: [
          // Mirrors agentUpdateStream's own filter, so a test that emits the
          // wrong shape fails instead of quietly passing.
          agentUpdateStreamProvider.overrideWith(
            (ref, id) => updates.stream.where((ids) => ids.contains(id)),
          ),
          ..._overrides(
            evolutionHistory: soulEvolutionSessionHistoryProvider.overrideWith((
              ref,
              soulId,
            ) {
              // Mirrors the real provider's dependency, which is what makes a
              // stream emission a reload rather than a refresh.
              ref.watch(agentUpdateStreamProvider(_soulId));
              builds++;
              if (builds == 1) {
                return Future.value(const <RitualSessionHistoryEntry>[]);
              }
              // Never resolves, so the widget stays in the loading state
              // rather than racing a resolution.
              return reload.future;
            }),
          ),
        ],
      );
      addTearDown(testable.container.dispose);

      await tester.pumpWidget(testable.widget);
      await tester.pump();
      expect(find.text(_noSessions), findsOneWidget);

      // Production shape. Soul entities carry `agentId: soulId`, so the sync
      // handler's `{resolvedEntity.agentId, agentNotification}` is exactly
      // this set.
      updates.add({_soulId, agentNotification});
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
      expect(find.text(_noSessions), findsOneWidget);
    });

    testWidgets('keeps the version history on screen while it reloads', (
      tester,
    ) async {
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final reload = Completer<List<AgentDomainEntity>>();
      addTearDown(() {
        if (!reload.isCompleted) reload.complete(const []);
      });
      var builds = 0;

      final testable = makeTestableWidgetWithContainer(
        _subject(),
        overrides: [
          // Mirrors agentUpdateStream's own filter, so a test that emits the
          // wrong shape fails instead of quietly passing.
          agentUpdateStreamProvider.overrideWith(
            (ref, id) => updates.stream.where((ids) => ids.contains(id)),
          ),
          ..._overrides(
            versionHistory: soulVersionHistoryProvider.overrideWith((
              ref,
              soulId,
            ) {
              ref.watch(agentUpdateStreamProvider(_soulId));
              builds++;
              if (builds == 1) return Future.value(const <AgentDomainEntity>[]);
              return reload.future;
            }),
          ),
        ],
      );
      addTearDown(testable.container.dispose);

      await tester.pumpWidget(testable.widget);
      await tester.pump();
      expect(find.text(_noVersions), findsOneWidget);

      // Production shape. Soul entities carry `agentId: soulId`, so the sync
      // handler's `{resolvedEntity.agentId, agentNotification}` is exactly
      // this set.
      updates.add({_soulId, agentNotification});
      await tester.pump();
      await tester.pump();

      expect(builds, 2, reason: 'the provider did not actually reload');
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a background reload replaced settled content with a spinner',
      );
      expect(find.text(_noVersions), findsOneWidget);
    });
  });
}
