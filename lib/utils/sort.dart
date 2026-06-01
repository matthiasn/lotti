import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';

/// Filters dashboards by active status and a case-insensitive name substring,
/// then returns them sorted by lowercased name.
List<DashboardDefinition> filteredSortedDashboards(
  List<DashboardDefinition> items, {
  String match = '',
  bool showAll = false,
}) {
  final normalizedMatch = match.toLowerCase();

  return items
      .where(
        (DashboardDefinition dashboard) =>
            dashboard.name.toLowerCase().contains(normalizedMatch) &&
            (showAll || dashboard.active),
      )
      .sorted(
        (DashboardDefinition a, DashboardDefinition b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      )
      .toList();
}
