import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/projects/model/projects_overview_models.dart';

/// Generators for [ProjectsQuery] and [applyProjectsFilter] property tests.
extension AnyProjectsModels on glados.Any {
  glados.Generator<String> get categoryId => glados.any.letterOrDigits;

  glados.Generator<Set<String>> get categoryIdSet => glados.ListAnys(this)
      .listWithLengthInRange(0, 4, categoryId)
      .map(
        Set<String>.from,
      );

  glados.Generator<String> get statusFilterId =>
      glados.AnyUtils(this).choose(<String>[
        ProjectStatusFilterIds.open,
        ProjectStatusFilterIds.active,
        ProjectStatusFilterIds.onHold,
        ProjectStatusFilterIds.completed,
        ProjectStatusFilterIds.archived,
      ]);

  glados.Generator<Set<String>> get statusFilterIdSet => glados.ListAnys(this)
      .listWithLengthInRange(0, 5, statusFilterId)
      .map(
        Set<String>.from,
      );

  glados.Generator<ProjectsFilter> get projectsFilter =>
      glados.CombinableAny(this).combine2(
        statusFilterIdSet,
        categoryIdSet,
        (statusIds, catIds) => ProjectsFilter(
          selectedStatusIds: statusIds,
          selectedCategoryIds: catIds,
        ),
      );
}
