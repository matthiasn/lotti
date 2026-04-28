import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';

void main() {
  group('kSettingsPanels — registered ids', () {
    /// Every panel id the registry is expected to carry. Each must
    /// resolve to a non-null spec AND the dispatcher must be able
    /// to find it via [panelSpecFor]. Keeping the expected set
    /// declared here locks the registry contents against accidental
    /// removal and surfaces additions that weren't deliberately
    /// signed off. Grouped by the plan step that introduced each id.
    const expectedIds = <String>{
      // Branches that carry their own landing page.
      'ai',
      'agents',
      // Step 7 — simple leaves.
      'flags',
      'theming',
      'advanced-about',
      'advanced-maintenance',
      'advanced-logging',
      'sync-backfill',
      'sync-stats',
      'sync-outbox',
      'sync-conflicts',
      'sync-matrix-maintenance',
      // Step 8 — dynamic lists.
      'categories',
      'labels',
      'habits',
      'dashboards',
      'measurables',
      // Step 9 — AI + agents.
      'ai-profiles',
      'agents-templates',
      'agents-souls',
      'agents-instances',
    };

    test('registers every expected panel id', () {
      expect(kSettingsPanels.keys.toSet(), containsAll(expectedIds));
    });

    test('every registered spec carries a non-null builder', () {
      for (final entry in kSettingsPanels.entries) {
        expect(
          entry.value.build,
          isNotNull,
          reason: 'spec for "${entry.key}" should carry a builder',
        );
      }
    });

    test('registry does not carry unexpected ids', () {
      // Additions should be deliberately added to [expectedIds]
      // rather than silently growing the registry.
      expect(kSettingsPanels.keys.toSet(), equals(expectedIds));
    });
  });

  group('panelSpecFor', () {
    test('returns null when given a null id', () {
      expect(panelSpecFor(null), isNull);
    });

    test('returns null for an id not in the registry', () {
      expect(panelSpecFor('no-such-panel'), isNull);
    });

    test('returns the same spec reference that kSettingsPanels holds', () {
      // Every step-7 id should round-trip through the dispatcher
      // helper exactly as it does through a direct map lookup.
      for (final id in kSettingsPanels.keys) {
        expect(
          identical(panelSpecFor(id), kSettingsPanels[id]),
          isTrue,
          reason: 'panelSpecFor("$id") should return the map entry',
        );
      }
    });
  });

  group('SettingsPanelSpec — scrollable flag', () {
    test(
      'defaults to false so bodies that own their scrolling opt-in '
      'rather than opt-out',
      () {
        // `ai-profiles` renders the full AiInferenceProfilesPage with
        // its own CustomScrollView — the scrollable flag must stay
        // false so the host does not wrap it in a
        // SingleChildScrollView.
        expect(panelSpecFor('ai-profiles')!.scrollable, isFalse);
      },
    );

    test('scrollable = true wraps flat-column bodies like FlagsBody', () {
      // FlagsBody is a plain Column; without the outer
      // SingleChildScrollView it would overflow the detail pane.
      expect(panelSpecFor('flags')!.scrollable, isTrue);
    });
  });

  group('SettingsPanelSpec — builders', () {
    // Invoking each registered builder is what proves every panel id
    // is wired to the right Body type — without this, the registry
    // can silently lose a wiring (e.g. `agents-souls` pointing at the
    // `templates` tab) and the structural tests above would still
    // pass. Building under a real BuildContext also exercises every
    // builder line directly, which is what `panel_registry.dart`
    // needs for coverage.
    //
    // We don't pump the returned widgets — most depend on `getIt` /
    // Riverpod setup we'd need to mock. The wiring assertion (right
    // Body class, right `initialTab` argument for the agent variants)
    // is what we actually care about here.
    testWidgets(
      'every registered builder returns the expected Body widget',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        Widget build(String id) => kSettingsPanels[id]!.build(capturedContext);

        // Step 7 — simple leaves.
        expect(build('flags'), isA<FlagsBody>());
        expect(build('theming'), isA<ThemingBody>());
        expect(build('advanced-about'), isA<AboutBody>());
        expect(build('advanced-maintenance'), isA<MaintenanceBody>());
        expect(build('advanced-logging'), isA<LoggingSettingsBody>());
        expect(build('sync-backfill'), isA<BackfillSettingsBody>());
        expect(build('sync-stats'), isA<SyncStatsBody>());
        expect(build('sync-outbox'), isA<OutboxMonitorBody>());
        expect(
          build('sync-matrix-maintenance'),
          isA<MatrixSyncMaintenanceBody>(),
        );

        // Step 8 — dynamic lists.
        expect(build('categories'), isA<CategoriesListBody>());
        expect(build('labels'), isA<LabelsListBody>());
        expect(build('habits'), isA<HabitsBody>());
        expect(build('dashboards'), isA<DashboardsBody>());
        expect(build('measurables'), isA<MeasurablesBody>());
        // sync-conflicts moved from `advanced-conflicts` so it could
        // sit next to the other Sync surfaces in the tree. The
        // builder still resolves to ConflictsBody.
        expect(build('sync-conflicts'), isA<ConflictsBody>());

        // Step 9 — AI + agents. The agent variants must each carry
        // the correct `initialTab` so the registry doesn't silently
        // collapse all three tabs onto the same default.
        expect(build('ai'), isA<AiSettingsBody>());
        expect(build('ai-profiles'), isA<InferenceProfilesBody>());

        final agentsRoot = build('agents');
        expect(agentsRoot, isA<AgentSettingsBody>());
        expect((agentsRoot as AgentSettingsBody).initialTab, isNull);

        final templates = build('agents-templates');
        expect(templates, isA<AgentSettingsBody>());
        expect(
          (templates as AgentSettingsBody).initialTab,
          AgentSettingsTab.templates,
        );

        final souls = build('agents-souls');
        expect(souls, isA<AgentSettingsBody>());
        expect(
          (souls as AgentSettingsBody).initialTab,
          AgentSettingsTab.souls,
        );

        final instances = build('agents-instances');
        expect(instances, isA<AgentSettingsBody>());
        expect(
          (instances as AgentSettingsBody).initialTab,
          AgentSettingsTab.instances,
        );
      },
    );
  });
}
