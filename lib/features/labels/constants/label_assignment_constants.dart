// Label assignment shared constants

/// Central config for label assignment behavior.
///
/// Prefer using the static members on this class to avoid scattering
/// magic numbers across the codebase. Top-level constants remain for
/// backward compatibility and will forward to this config.
class LabelAssignmentConfig {
  /// Max number of labels the AI can assign per tool call.
  static const int maxLabelsPerAssignment = 5;
}

/// Max number of labels the AI can assign per tool call.
const int kMaxLabelsPerAssignment =
    LabelAssignmentConfig.maxLabelsPerAssignment;
