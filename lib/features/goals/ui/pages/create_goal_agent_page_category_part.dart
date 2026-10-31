part of 'create_goal_agent_page.dart';

/// Where the goal is filed: the category the form shows and saves, read from
/// the goal row when editing and moved with everything the goal holds when
/// it changes. A mixin of its own, beside the form's state, because it keeps
/// state and rebuilds the form.
mixin _GoalFormCategory on ConsumerState<CreateGoalAgentPage> {
  /// The goal's category, and — when editing — the one it was filed in.
  String? _categoryId;
  String? _initialCategoryId;
  var _categoryInitialized = false;

  /// Whether the form edits an existing goal.
  bool get _editing => widget.agentId != null;

  /// Seeds the category from the goal's journal row, once it has read: the
  /// category lives on the row, not on the spec, so a revision never carries
  /// it.
  void _initializeCategory(String agentId) {
    if (_categoryInitialized) return;
    final category = ref.watch(goalCategoryIdProvider(agentId));
    if (!category.hasValue) return;
    _categoryInitialized = true;
    _categoryId = _initialCategoryId = category.value;
  }

  /// Takes the user's pick. Null while an edit has not read the goal row's
  /// own category yet, so the row cannot be changed until then and a late
  /// read never overwrites a pick.
  ValueChanged<String?>? get _categoryChanger =>
      _editing && !_categoryInitialized ? null : _changeCategory;

  void _changeCategory(String? id) => setState(() => _categoryId = id);

  /// Files the goal under the category the user picked, with everything it
  /// holds — its check-ins, recordings, notes and charter — across a crash,
  /// as a task's category move does (`EntryCategoryMove`).
  Future<void> _moveCategoryIfChanged(
    ProviderContainer container,
    String agentId,
  ) async {
    if (_categoryId == _initialCategoryId) return;
    final goalId = container.read(goalEntryIdProvider(agentId));
    // No row to move means the pick was not saved: the save must say so.
    if (goalId == null) throw StateError('the goal row is unavailable');
    if (!await container
        .read(entryCategoryMoveProvider)
        .move(goalId, _categoryId)) {
      throw StateError('the goal could not take its category');
    }
    container.invalidate(goalCategoryIdProvider(agentId));
  }
}
