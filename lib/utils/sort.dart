import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';

List<DashboardDefinition> filteredSortedDashboards(
  List<DashboardDefinition> items,
  String match,
) {
  return items
      .where(
        (DashboardDefinition dashboard) =>
            dashboard.name.toLowerCase().contains(match) && dashboard.active,
      )
      .sorted(
        (DashboardDefinition a, DashboardDefinition b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      )
      .toList();
}
