import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/journal/state/journal_page_state.dart';

// Candidate values kept small and bounded so the generated sets exercise
// membership/ordering variety without exploding the search space.
const hCategoryPool = ['cat-a', 'cat-b', 'cat-c'];
const hProjectPool = ['proj-1', 'proj-2'];
const hStatusPool = ['OPEN', 'IN_PROGRESS', 'DONE'];
const hLabelPool = ['label-x', 'label-y'];
const hPriorityPool = ['P0', 'P1', 'P2', 'P3'];

extension AnyTasksFilter on glados.Any {
  glados.Generator<Set<String>> hSetFrom(List<String> pool) =>
      glados.SetAyns(this).set(glados.AnyUtils(this).choose(pool));

  glados.Generator<TasksFilter> get tasksFilter =>
      glados.CombinableAny(this).combine8(
        hSetFrom(hCategoryPool),
        hSetFrom(hProjectPool),
        hSetFrom(hStatusPool),
        hSetFrom(hLabelPool),
        hSetFrom(hPriorityPool),
        glados.AnyUtils(this).choose(TaskSortOption.values),
        glados.AnyUtils(this).choose(AgentAssignmentFilter.values),
        // Pack the five boolean fields into a 0..31 bitmask.
        glados.IntAnys(this).intInRange(0, 32),
        (
          Set<String> categories,
          Set<String> projects,
          Set<String> statuses,
          Set<String> labels,
          Set<String> priorities,
          TaskSortOption sortOption,
          AgentAssignmentFilter agentFilter,
          int boolBits,
        ) => TasksFilter(
          selectedCategoryIds: categories,
          selectedProjectIds: projects,
          selectedTaskStatuses: statuses,
          selectedLabelIds: labels,
          selectedPriorities: priorities,
          sortOption: sortOption,
          agentAssignmentFilter: agentFilter,
          showCreationDate: boolBits & 1 != 0,
          showDueDate: boolBits & 2 != 0,
          showCoverArt: boolBits & 4 != 0,
          showProjectsHeader: boolBits & 8 != 0,
          showDistances: boolBits & 16 != 0,
        ),
      );
}
