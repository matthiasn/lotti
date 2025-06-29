import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/sort.dart';

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
      dashboard4
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
      final result =
          filteredSortedDashboards(dashboards, match: 'a', showAll: true);
      expect(result.map((e) => e.id).toList(), ['1', '3', '2', '4']);
    });
  });
}
