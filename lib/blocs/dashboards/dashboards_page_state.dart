import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';

part 'dashboards_page_state.freezed.dart';

@freezed
abstract class DashboardsPageState with _$DashboardsPageState {
  factory DashboardsPageState({
    required List<DashboardDefinition> allDashboards,
    required List<DashboardDefinition> filteredSortedDashboards,
    required Set<String> selectedCategoryIds,
  }) = _DashboardsPageState;
}
