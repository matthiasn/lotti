// Label assignment shared constants

/// Central config for label assignment behavior.
///
/// Prefer using the static members on this class to avoid scattering
/// magic numbers across the codebase. Top-level constants remain for
/// backward compatibility and will forward to this config.
class LabelAssignmentConfig {
  /// Max number of labels the AI can assign per tool call.
  static const int maxLabelsPerAssignment = 5;

  /// Number of labels to include in prompts by usage descending.
  static const int labelsPromptTopUsageCount = 50;

  /// Number of additional labels to include alphabetically after top-usage.
  static const int labelsPromptNextAlphaCount = 50;
}

/// Max number of labels the AI can assign per tool call.
const int kMaxLabelsPerAssignment =
    LabelAssignmentConfig.maxLabelsPerAssignment;

/// Number of labels to include in prompts by usage descending.
const int kLabelsPromptTopUsageCount =
    LabelAssignmentConfig.labelsPromptTopUsageCount;

/// Number of additional labels to include alphabetically after top-usage.
const int kLabelsPromptNextAlphaCount =
    LabelAssignmentConfig.labelsPromptNextAlphaCount;

// End of file
