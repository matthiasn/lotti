/// Well-known defaults for improver agent configuration.
///
/// Actual slot fields live on `AgentSlots` (freezed). This class provides
/// default values and validation constants.
abstract final class ImproverSlotDefaults {
  /// Default number of days between one-on-one rituals.
  static const defaultFeedbackWindowDays = 7;

  /// Maximum allowed recursion depth for meta-improvers.
  static const maxRecursionDepth = 2;
}
