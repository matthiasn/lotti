import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class DashboardsPageCubit extends Cubit<DashboardsPageState> {
  DashboardsPageCubit()
      : super(
          DashboardsPageState(
            showSearch: false,
            searchString: '',
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
  var _showSearch = false;
  var _searchString = '';

  void setSearchString(String searchString) {
    _searchString = searchString.toLowerCase();
    emitState();
  }

  void toggleShowSearch() {
    _showSearch = !_showSearch;
    emitState();
  }

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
            .where(
              (dashboard) =>
                  _selectedCategoryIds.contains(dashboard.categoryId),
            )
            .toList()
        : _dashboardDefinitions;
    emit(
      DashboardsPageState(
        showSearch: _showSearch,
        searchString: _searchString,
        selectedCategoryIds: <String>{..._selectedCategoryIds},
        allDashboards: _dashboardDefinitions,
        filteredSortedDashboards: filteredByCategory,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _definitionsSubscription.cancel();
    await super.close();
  }
}
