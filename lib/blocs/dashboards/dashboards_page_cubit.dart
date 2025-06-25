import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class DashboardsPageCubit extends Cubit<DashboardsPageState> {
  DashboardsPageCubit()
      : super(
          DashboardsPageState(
            selectedCategoryIds: <String>{},
            allDashboards: [],
            filteredSortedDashboards: [],
          ),
        ) {
    _definitionsStream = getIt<JournalDb>().watchDashboards();

    _definitionsSubscription =
        _definitionsStream.listen((dashboardDefinitions) {
      _dashboardDefinitions =
          dashboardDefinitions.where((dashboard) => dashboard.active).toList();

      emitState();
    });
  }

  late final Stream<List<DashboardDefinition>> _definitionsStream;
  late final StreamSubscription<List<DashboardDefinition>>
      _definitionsSubscription;

  List<DashboardDefinition> _dashboardDefinitions = [];
  final _selectedCategoryIds = <String>{};

  void toggleSelectedCategoryIds(String categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    emitState();
  }

  void emitState() {
    final filteredByCategory = _selectedCategoryIds.isNotEmpty
        ? _dashboardDefinitions
            .where((item) => _selectedCategoryIds.contains(item.categoryId))
            .toList()
        : _dashboardDefinitions;
    emit(
      DashboardsPageState(
        selectedCategoryIds: <String>{..._selectedCategoryIds},
        allDashboards: _dashboardDefinitions,
        filteredSortedDashboards:
            filteredByCategory.sortedBy((item) => item.name),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _definitionsSubscription.cancel();
    await super.close();
  }
}
