import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/sort.dart';

enum _GeneratedDashboardNameShape {
  alpha,
  banana,
  focus,
  health,
  retro,
}

enum _GeneratedDashboardNameCasing {
  lower,
  upper,
  title,
}

enum _GeneratedDashboardMatchKind {
  empty,
  lower,
  upper,
  missing,
}

class _GeneratedDashboardSpec {
  const _GeneratedDashboardSpec({
    required this.seed,
    required this.active,
    required this.nameShape,
    required this.nameCasing,
  });

  final int seed;
  final bool active;
  final _GeneratedDashboardNameShape nameShape;
  final _GeneratedDashboardNameCasing nameCasing;

  DashboardDefinition dashboard(int index) {
    final timestamp = DateTime(2025);
    return DashboardDefinition(
      id: 'dashboard-$index-$seed',
      name: _applyGeneratedDashboardCasing(
        '${_generatedDashboardBaseName(nameShape)} $seed $index',
        nameCasing,
      ),
      active: active,
      items: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastReviewed: timestamp,
      description: '',
      version: '1',
      vectorClock: const VectorClock({}),
      private: false,
    );
  }

  @override
  String toString() {
    return '_GeneratedDashboardSpec('
        'seed: $seed, '
        'active: $active, '
        'nameShape: $nameShape, '
        'nameCasing: $nameCasing)';
  }
}

class _GeneratedDashboardScenario {
  const _GeneratedDashboardScenario({
    required this.specs,
    required this.showAll,
    required this.matchKind,
    required this.matchSeed,
  });

  final List<_GeneratedDashboardSpec> specs;
  final bool showAll;
  final _GeneratedDashboardMatchKind matchKind;
  final int matchSeed;

  List<DashboardDefinition> get dashboards => List.generate(
    specs.length,
    (index) => specs[index].dashboard(index),
  );

  String matchFor(List<DashboardDefinition> dashboards) {
    return switch (matchKind) {
      _GeneratedDashboardMatchKind.empty => '',
      _GeneratedDashboardMatchKind.missing => 'missing-dashboard-$matchSeed',
      _ when dashboards.isEmpty => 'dashboard',
      _GeneratedDashboardMatchKind.lower => _matchingToken(
        dashboards,
      ).toLowerCase(),
      _GeneratedDashboardMatchKind.upper => _matchingToken(
        dashboards,
      ).toUpperCase(),
    };
  }

  List<String> expectedIdsFor(List<DashboardDefinition> dashboards) {
    final normalizedMatch = matchFor(dashboards).toLowerCase();
    final expected =
        dashboards
            .where(
              (dashboard) =>
                  dashboard.name.toLowerCase().contains(normalizedMatch) &&
                  (showAll || dashboard.active),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return expected.map((dashboard) => dashboard.id).toList();
  }

  String _matchingToken(List<DashboardDefinition> dashboards) {
    final dashboard = dashboards[matchSeed % dashboards.length];
    return dashboard.name.split(' ').first;
  }

  @override
  String toString() {
    return '_GeneratedDashboardScenario('
        'specs: $specs, '
        'showAll: $showAll, '
        'matchKind: $matchKind, '
        'matchSeed: $matchSeed)';
  }
}

String _generatedDashboardBaseName(_GeneratedDashboardNameShape shape) {
  return switch (shape) {
    _GeneratedDashboardNameShape.alpha => 'Alpha Board',
    _GeneratedDashboardNameShape.banana => 'Banana Metrics',
    _GeneratedDashboardNameShape.focus => 'Focus Review',
    _GeneratedDashboardNameShape.health => 'Health Signals',
    _GeneratedDashboardNameShape.retro => 'Retro Log',
  };
}

String _applyGeneratedDashboardCasing(
  String value,
  _GeneratedDashboardNameCasing casing,
) {
  return switch (casing) {
    _GeneratedDashboardNameCasing.lower => value.toLowerCase(),
    _GeneratedDashboardNameCasing.upper => value.toUpperCase(),
    _GeneratedDashboardNameCasing.title => value,
  };
}

extension _AnyDashboardScenario on glados.Any {
  glados.Generator<_GeneratedDashboardNameShape> get _dashboardNameShape =>
      glados.AnyUtils(this).choose(_GeneratedDashboardNameShape.values);

  glados.Generator<_GeneratedDashboardNameCasing> get _dashboardNameCasing =>
      glados.AnyUtils(this).choose(_GeneratedDashboardNameCasing.values);

  glados.Generator<_GeneratedDashboardMatchKind> get _dashboardMatchKind =>
      glados.AnyUtils(this).choose(_GeneratedDashboardMatchKind.values);

  glados.Generator<_GeneratedDashboardSpec> get dashboardSpec =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 10000),
        glados.AnyUtils(this).choose([false, true]),
        _dashboardNameShape,
        _dashboardNameCasing,
        (
          int seed,
          bool active,
          _GeneratedDashboardNameShape nameShape,
          _GeneratedDashboardNameCasing nameCasing,
        ) => _GeneratedDashboardSpec(
          seed: seed,
          active: active,
          nameShape: nameShape,
          nameCasing: nameCasing,
        ),
      );

  glados.Generator<_GeneratedDashboardScenario> get dashboardScenario =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(0, 9, dashboardSpec),
        glados.AnyUtils(this).choose([false, true]),
        _dashboardMatchKind,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          List<_GeneratedDashboardSpec> specs,
          bool showAll,
          _GeneratedDashboardMatchKind matchKind,
          int matchSeed,
        ) => _GeneratedDashboardScenario(
          specs: specs,
          showAll: showAll,
          matchKind: matchKind,
          matchSeed: matchSeed,
        ),
      );
}

void main() {
  group('filteredSortedDashboards', () {
    final timestamp = DateTime(2025);
    final dashboard1 = DashboardDefinition(
      id: '1',
      name: 'Apple',
      active: true,
      items: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastReviewed: timestamp,
      description: '',
      version: '1',
      vectorClock: const VectorClock({}),
      private: false,
    );
    final dashboard2 = DashboardDefinition(
      id: '2',
      name: 'Banana',
      active: true,
      items: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastReviewed: timestamp,
      description: '',
      version: '1',
      vectorClock: const VectorClock({}),
      private: false,
    );
    final dashboard3 = DashboardDefinition(
      id: '3',
      name: 'apple pie',
      active: true,
      items: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastReviewed: timestamp,
      description: '',
      version: '1',
      vectorClock: const VectorClock({}),
      private: false,
    );
    final dashboard4 = DashboardDefinition(
      id: '4',
      name: 'inactive',
      active: false,
      items: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastReviewed: timestamp,
      description: '',
      version: '1',
      vectorClock: const VectorClock({}),
      private: false,
    );

    final dashboards = <DashboardDefinition>[
      dashboard1,
      dashboard2,
      dashboard3,
      dashboard4,
    ];

    test('should return all active dashboards sorted by name', () {
      final result = filteredSortedDashboards(dashboards);
      expect(result.map((e) => e.id).toList(), ['1', '3', '2']);
    });

    test('should filter by match string (case-insensitive)', () {
      final result = filteredSortedDashboards(dashboards, match: 'apple');
      expect(result.map((e) => e.id).toList(), ['1', '3']);
    });

    test('should return all dashboards when showAll is true', () {
      final result = filteredSortedDashboards(dashboards, showAll: true);
      expect(result.map((e) => e.id).toList(), ['1', '3', '2', '4']);
    });

    test('should filter by match and showAll', () {
      final result = filteredSortedDashboards(
        dashboards,
        match: 'a',
        showAll: true,
      );
      expect(result.map((e) => e.id).toList(), ['1', '3', '2', '4']);
    });

    glados.Glados(
      glados.any.dashboardScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated active, match, and ordering model',
      (scenario) {
        final dashboards = scenario.dashboards;
        final originalIds = dashboards
            .map((dashboard) => dashboard.id)
            .toList();

        final result = filteredSortedDashboards(
          dashboards,
          match: scenario.matchFor(dashboards),
          showAll: scenario.showAll,
        );

        expect(
          result.map((dashboard) => dashboard.id).toList(),
          scenario.expectedIdsFor(dashboards),
          reason: '$scenario',
        );
        expect(
          dashboards.map((dashboard) => dashboard.id).toList(),
          originalIds,
          reason: 'input list should not be mutated for $scenario',
        );
      },
      tags: 'glados',
    );
  });
}
