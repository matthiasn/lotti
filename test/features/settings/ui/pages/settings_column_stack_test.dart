import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart'
    as new_categories;
import 'package:lotti/features/categories/ui/pages/category_details_page.dart'
    as new_category_details;
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/projects/ui/pages/project_create_page.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_stack.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

DesktopSettingsRoute _route(
  String path, {
  Map<String, String> params = const {},
  Map<String, String> query = const {},
}) {
  return (path: path, pathParameters: params, queryParameters: query);
}

List<Type> _types(List<SettingsColumn> columns) =>
    columns.map((c) => c.child.runtimeType).toList();

List<Key> _keys(List<SettingsColumn> columns) =>
    columns.map((c) => c.key).toList();

void main() {
  // Some settings pages (e.g. EditDashboardPage, EditMeasurablePage) resolve
  // services from GetIt eagerly in their field initialisers, so even just
  // constructing them during the resolver walk requires a populated GetIt.
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('resolveSettingsColumnStack', () {
    test('null route returns only the root SettingsPage column', () {
      final columns = resolveSettingsColumnStack(null);
      expect(_types(columns), [SettingsPage]);
      expect(_keys(columns), [const ValueKey('/settings')]);
    });

    test('/settings root returns only the root SettingsPage column', () {
      final columns = resolveSettingsColumnStack(_route('/settings'));
      expect(_types(columns), [SettingsPage]);
    });

    test('unknown settings path falls back to the root menu only', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/not_a_section'),
      );
      expect(_types(columns), [SettingsPage]);
    });

    // ── AI ────────────────────────────────────────────────────────────────

    test('/settings/ai stacks AiSettingsPage on top of the root', () {
      final columns = resolveSettingsColumnStack(_route('/settings/ai'));
      expect(_types(columns), [SettingsPage, AiSettingsPage]);
      expect(
        _keys(columns),
        [const ValueKey('/settings'), const ValueKey('/settings/ai')],
      );
    });

    test('/settings/ai/profiles adds InferenceProfilePage as a 3rd column', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/ai/profiles'),
      );
      expect(
        _types(columns),
        [SettingsPage, AiSettingsPage, InferenceProfilePage],
      );
      expect(columns.last.key, const ValueKey('/settings/ai/profiles'));
    });

    // ── Sync ──────────────────────────────────────────────────────────────

    test('/settings/sync stacks SyncSettingsPage', () {
      final columns = resolveSettingsColumnStack(_route('/settings/sync'));
      expect(_types(columns), [SettingsPage, SyncSettingsPage]);
    });

    test('/settings/sync/backfill adds BackfillSettingsPage as 3rd column', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/sync/backfill'),
      );
      expect(
        _types(columns),
        [SettingsPage, SyncSettingsPage, BackfillSettingsPage],
      );
    });

    test('/settings/sync/matrix/maintenance stacks the maintenance page', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/sync/matrix/maintenance'),
      );
      expect(
        _types(columns),
        [SettingsPage, SyncSettingsPage, MatrixSyncMaintenancePage],
      );
    });

    test('/settings/sync/stats stacks SyncStatsPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/sync/stats'),
      );
      expect(_types(columns), [SettingsPage, SyncSettingsPage, SyncStatsPage]);
    });

    test('/settings/sync/outbox stacks OutboxMonitorPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/sync/outbox'),
      );
      expect(
        _types(columns),
        [SettingsPage, SyncSettingsPage, OutboxMonitorPage],
      );
    });

    test('unknown /settings/sync/ suffix falls back to SyncSettingsPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/sync/something-else'),
      );
      expect(_types(columns), [SettingsPage, SyncSettingsPage]);
    });

    // ── Labels ────────────────────────────────────────────────────────────

    test('/settings/labels stacks LabelsListPage', () {
      final columns = resolveSettingsColumnStack(_route('/settings/labels'));
      expect(_types(columns), [SettingsPage, LabelsListPage]);
    });

    test('/settings/labels/create adds a LabelDetailsPage create column', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/labels/create', query: {'name': 'Focus'}),
      );
      expect(
        _types(columns),
        [SettingsPage, LabelsListPage, LabelDetailsPage],
      );
    });

    test(
      '/settings/labels/create keys the create column by the `name` query '
      'seed so switching presets forces initState() to re-seed the text '
      'controller',
      () {
        final focus = resolveSettingsColumnStack(
          _route('/settings/labels/create', query: {'name': 'Focus'}),
        );
        final rest = resolveSettingsColumnStack(
          _route('/settings/labels/create', query: {'name': 'Rest'}),
        );
        expect(focus.last.key, isNot(equals(rest.last.key)));
        expect(
          focus.last.key,
          const ValueKey('/settings/labels/create?name=Focus'),
        );
      },
    );

    test(
      '/settings/labels/create with no `name` query uses an empty-seed key',
      () {
        final columns = resolveSettingsColumnStack(
          _route('/settings/labels/create'),
        );
        expect(
          columns.last.key,
          const ValueKey('/settings/labels/create?name='),
        );
      },
    );

    test('/settings/labels/<id> adds a LabelDetailsPage detail column', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/labels/abc', params: {'labelId': 'abc'}),
      );
      expect(
        _types(columns),
        [SettingsPage, LabelsListPage, LabelDetailsPage],
      );
      expect(columns.last.key, const ValueKey('/settings/labels/abc'));
    });

    // ── Categories ────────────────────────────────────────────────────────

    test('/settings/categories stacks CategoriesListPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/categories'),
      );
      expect(
        _types(columns),
        [SettingsPage, new_categories.CategoriesListPage],
      );
    });

    test('/settings/categories/create adds a CategoryDetailsPage column', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/categories/create'),
      );
      expect(_types(columns), [
        SettingsPage,
        new_categories.CategoriesListPage,
        new_category_details.CategoryDetailsPage,
      ]);
    });

    test('/settings/categories/<id> adds a CategoryDetailsPage detail', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/categories/cat-1', params: {'categoryId': 'cat-1'}),
      );
      expect(_types(columns), [
        SettingsPage,
        new_categories.CategoriesListPage,
        new_category_details.CategoryDetailsPage,
      ]);
    });

    test(
      'categoryId literally equal to "create" does not add a second detail '
      'column',
      () {
        final columns = resolveSettingsColumnStack(
          _route(
            '/settings/categories',
            params: {'categoryId': 'create'},
          ),
        );
        expect(_types(columns), [
          SettingsPage,
          new_categories.CategoriesListPage,
        ]);
      },
    );

    // ── Projects (no intermediate list) ──────────────────────────────────

    test('/settings/projects/create appends only the create column', () {
      final columns = resolveSettingsColumnStack(
        _route(
          '/settings/projects/create',
          query: {'categoryId': 'cat-1'},
        ),
      );
      expect(_types(columns), [SettingsPage, ProjectCreatePage]);
    });

    test(
      '/settings/projects/create keys the create column by the `categoryId` '
      'query seed so opening create for a different category rebuilds the '
      'form state',
      () {
        final cat1 = resolveSettingsColumnStack(
          _route('/settings/projects/create', query: {'categoryId': 'cat-1'}),
        );
        final cat2 = resolveSettingsColumnStack(
          _route('/settings/projects/create', query: {'categoryId': 'cat-2'}),
        );
        expect(cat1.last.key, isNot(equals(cat2.last.key)));
        expect(
          cat1.last.key,
          const ValueKey('/settings/projects/create?categoryId=cat-1'),
        );
      },
    );

    test('/settings/projects/<id> appends the detail column directly', () {
      final columns = resolveSettingsColumnStack(
        _route(
          '/settings/projects/p-1',
          params: {'projectId': 'p-1'},
          query: {'categoryId': 'cat-1'},
        ),
      );
      expect(_types(columns), [SettingsPage, ProjectDetailPage]);
    });

    test('/settings/projects root without params returns only root', () {
      final columns = resolveSettingsColumnStack(_route('/settings/projects'));
      expect(_types(columns), [SettingsPage]);
    });

    // ── Dashboards ────────────────────────────────────────────────────────

    test('/settings/dashboards stacks DashboardSettingsPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/dashboards'),
      );
      expect(_types(columns), [SettingsPage, DashboardSettingsPage]);
    });

    test('/settings/dashboards/create adds the CreateDashboardPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/dashboards/create'),
      );
      expect(
        _types(columns),
        [SettingsPage, DashboardSettingsPage, CreateDashboardPage],
      );
    });

    test('/settings/dashboards/<id> adds an EditDashboardPage', () {
      final columns = resolveSettingsColumnStack(
        _route(
          '/settings/dashboards/d-1',
          params: {'dashboardId': 'd-1'},
        ),
      );
      expect(
        _types(columns),
        [SettingsPage, DashboardSettingsPage, EditDashboardPage],
      );
    });

    // ── Measurables ───────────────────────────────────────────────────────

    test('/settings/measurables stacks MeasurablesPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/measurables'),
      );
      expect(_types(columns), [SettingsPage, MeasurablesPage]);
    });

    test('/settings/measurables/create adds CreateMeasurablePage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/measurables/create'),
      );
      expect(
        _types(columns),
        [SettingsPage, MeasurablesPage, CreateMeasurablePage],
      );
    });

    test('/settings/measurables/<id> adds EditMeasurablePage', () {
      final columns = resolveSettingsColumnStack(
        _route(
          '/settings/measurables/m-1',
          params: {'measurableId': 'm-1'},
        ),
      );
      expect(
        _types(columns),
        [SettingsPage, MeasurablesPage, EditMeasurablePage],
      );
    });

    // ── Habits ────────────────────────────────────────────────────────────

    test('/settings/habits stacks HabitsPage', () {
      final columns = resolveSettingsColumnStack(_route('/settings/habits'));
      expect(_types(columns), [SettingsPage, HabitsPage]);
    });

    test('/settings/habits/create adds CreateHabitPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/habits/create'),
      );
      expect(_types(columns), [SettingsPage, HabitsPage, CreateHabitPage]);
    });

    test('/settings/habits/by_id/<id> adds EditHabitPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/habits/by_id/h-1', params: {'habitId': 'h-1'}),
      );
      expect(_types(columns), [SettingsPage, HabitsPage, EditHabitPage]);
    });

    test(
      '/settings/habits/search swaps the habits list for its searched '
      'variant without adding a new column',
      () {
        final columns = resolveSettingsColumnStack(
          _route(
            '/settings/habits/search/focus',
            params: {'searchTerm': 'focus'},
          ),
        );
        expect(_types(columns), [SettingsPage, HabitsPage]);
        expect(
          columns.last.key,
          const ValueKey('/settings/habits/search/focus'),
        );
      },
    );

    // ── Agents ────────────────────────────────────────────────────────────

    test('/settings/agents stacks AgentSettingsPage', () {
      final columns = resolveSettingsColumnStack(_route('/settings/agents'));
      expect(_types(columns), [SettingsPage, AgentSettingsPage]);
    });

    test('/settings/agents/templates/create adds AgentTemplateDetailPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/agents/templates/create'),
      );
      expect(
        _types(columns),
        [SettingsPage, AgentSettingsPage, AgentTemplateDetailPage],
      );
    });

    test('/settings/agents/templates/<id> adds AgentTemplateDetailPage', () {
      final columns = resolveSettingsColumnStack(
        _route(
          '/settings/agents/templates/t-1',
          params: {'templateId': 't-1'},
        ),
      );
      expect(
        _types(columns),
        [SettingsPage, AgentSettingsPage, AgentTemplateDetailPage],
      );
    });

    test(
      '/settings/agents/templates/<id>/review pushes EvolutionReviewPage '
      'as a 4th column',
      () {
        final columns = resolveSettingsColumnStack(
          _route(
            '/settings/agents/templates/t-1/review',
            params: {'templateId': 't-1'},
          ),
        );
        expect(_types(columns), [
          SettingsPage,
          AgentSettingsPage,
          AgentTemplateDetailPage,
          EvolutionReviewPage,
        ]);
      },
    );

    test('/settings/agents/souls/create adds AgentSoulDetailPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/agents/souls/create'),
      );
      expect(
        _types(columns),
        [SettingsPage, AgentSettingsPage, AgentSoulDetailPage],
      );
    });

    test('/settings/agents/souls/<id> adds AgentSoulDetailPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/agents/souls/s-1', params: {'soulId': 's-1'}),
      );
      expect(
        _types(columns),
        [SettingsPage, AgentSettingsPage, AgentSoulDetailPage],
      );
    });

    test(
      '/settings/agents/souls/<id>/review pushes SoulEvolutionReviewPage',
      () {
        final columns = resolveSettingsColumnStack(
          _route(
            '/settings/agents/souls/s-1/review',
            params: {'soulId': 's-1'},
          ),
        );
        expect(_types(columns), [
          SettingsPage,
          AgentSettingsPage,
          AgentSoulDetailPage,
          SoulEvolutionReviewPage,
        ]);
      },
    );

    test('/settings/agents/instances/<id> adds AgentDetailPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/agents/instances/a-1', params: {'agentId': 'a-1'}),
      );
      expect(
        _types(columns),
        [SettingsPage, AgentSettingsPage, AgentDetailPage],
      );
    });

    test(
      'unknown /settings/agents/ leaf falls back to AgentSettingsPage only',
      () {
        final columns = resolveSettingsColumnStack(
          _route('/settings/agents/not_a_known_subpage'),
        );
        expect(_types(columns), [SettingsPage, AgentSettingsPage]);
      },
    );

    // ── Leaf-only features ────────────────────────────────────────────────

    test('/settings/flags stacks FlagsPage', () {
      final columns = resolveSettingsColumnStack(_route('/settings/flags'));
      expect(_types(columns), [SettingsPage, FlagsPage]);
    });

    test('/settings/theming stacks ThemingPage', () {
      final columns = resolveSettingsColumnStack(_route('/settings/theming'));
      expect(_types(columns), [SettingsPage, ThemingPage]);
    });

    test('/settings/health_import stacks HealthImportPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/health_import'),
      );
      expect(_types(columns), [SettingsPage, HealthImportPage]);
    });

    // ── Advanced ──────────────────────────────────────────────────────────

    test('/settings/advanced stacks AdvancedSettingsPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/advanced'),
      );
      expect(_types(columns), [SettingsPage, AdvancedSettingsPage]);
    });

    test(
      '/settings/advanced/logging_domains adds LoggingSettingsPage as 3rd',
      () {
        final columns = resolveSettingsColumnStack(
          _route('/settings/advanced/logging_domains'),
        );
        expect(
          _types(columns),
          [SettingsPage, AdvancedSettingsPage, LoggingSettingsPage],
        );
      },
    );

    test('/settings/advanced/about adds AboutPage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/advanced/about'),
      );
      expect(
        _types(columns),
        [SettingsPage, AdvancedSettingsPage, AboutPage],
      );
    });

    test('/settings/advanced/maintenance adds MaintenancePage', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/advanced/maintenance'),
      );
      expect(
        _types(columns),
        [SettingsPage, AdvancedSettingsPage, MaintenancePage],
      );
    });

    test('/settings/advanced/conflicts adds ConflictsPage as 3rd column', () {
      final columns = resolveSettingsColumnStack(
        _route('/settings/advanced/conflicts'),
      );
      expect(
        _types(columns),
        [SettingsPage, AdvancedSettingsPage, ConflictsPage],
      );
    });

    test(
      '/settings/advanced/conflicts/<id> adds ConflictDetailRoute as a '
      '4th column',
      () {
        final columns = resolveSettingsColumnStack(
          _route(
            '/settings/advanced/conflicts/c-1',
            params: {'conflictId': 'c-1'},
          ),
        );
        expect(_types(columns), [
          SettingsPage,
          AdvancedSettingsPage,
          ConflictsPage,
          ConflictDetailRoute,
        ]);
      },
    );

    test(
      '/settings/advanced/conflicts/<id>/edit pushes EntryDetailsPage as '
      'a 5th column on top of the conflict detail',
      () {
        final columns = resolveSettingsColumnStack(
          _route(
            '/settings/advanced/conflicts/c-1/edit',
            params: {'conflictId': 'c-1'},
          ),
        );
        expect(_types(columns), [
          SettingsPage,
          AdvancedSettingsPage,
          ConflictsPage,
          ConflictDetailRoute,
          EntryDetailsPage,
        ]);
      },
    );

    test(
      'SettingsColumn instances carry unique keys across the stack so '
      'Flutter preserves widget state as the stack grows',
      () {
        final columns = resolveSettingsColumnStack(
          _route('/settings/sync/backfill'),
        );
        expect(columns.length, 3);
        final keys = _keys(columns);
        expect(keys.toSet().length, 3, reason: 'All keys must be unique');
      },
    );
  });
}
