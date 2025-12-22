/// Constants for SharedPreferences keys used in the tasks feature.
///
/// Centralizing these keys prevents typos and makes it easier to:
/// - Find all preference usages
/// - Rename or migrate keys
/// - Document key purposes
abstract class TaskPreferenceKeys {
  /// Key for storing the checklist filter mode (open only vs all).
  ///
  /// Value: `bool` - `true` for open only, `false` for all.
  static String checklistFilterMode(String checklistId) =>
      'checklist_filter_mode_$checklistId';
}
