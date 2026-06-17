import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';

/// Recording fake of [HabitsController] for widget tests: serves a fixed
/// [HabitsState] and records which mutation methods were invoked, without
/// touching the database-backed production controller.
class FakeHabitsController extends HabitsController {
  FakeHabitsController(this._state);

  final HabitsState _state;

  final List<HabitDisplayFilter?> displayFilterCalls = [];
  final List<String> toggledCategoryIds = [];
  int toggleShowSearchCalls = 0;
  int toggleShowTimeSpanCalls = 0;
  int toggleZeroBasedCalls = 0;
  bool setTimeSpanCalled = false;
  int? lastTimeSpan;

  @override
  HabitsState build() => _state;

  /// Pushes a new state, so tests can exercise transitions (e.g. completing a
  /// habit) against a page that watches this controller.
  // ignore: use_setters_to_change_properties
  void emit(HabitsState next) => state = next;

  @override
  void setDisplayFilter(HabitDisplayFilter? displayFilter) {
    displayFilterCalls.add(displayFilter);
  }

  @override
  void toggleShowSearch() {
    toggleShowSearchCalls++;
  }

  @override
  void toggleShowTimeSpan() {
    toggleShowTimeSpanCalls++;
  }

  @override
  void toggleSelectedCategoryIds(String categoryId) {
    toggledCategoryIds.add(categoryId);
  }

  @override
  void toggleZeroBased() {
    toggleZeroBasedCalls++;
  }

  @override
  Future<void> setTimeSpan(int timeSpanDays) async {
    setTimeSpanCalled = true;
    lastTimeSpan = timeSpanDays;
  }
}
