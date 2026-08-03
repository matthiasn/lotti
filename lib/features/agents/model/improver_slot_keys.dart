/// Well-known defaults for improver agent configuration.
///
/// Actual slot fields live on `AgentSlots` (freezed). This class provides
/// default values and validation constants.
abstract final class ImproverSlotDefaults {
  /// Default number of days between one-on-one rituals.
  static const defaultFeedbackWindowDays = 7;

  /// Maximum number of template versions in a feedback window before
  /// flagging excessive directive churn.
  static const maxDirectiveChurnVersions = 3;
}
