// SettingsDb keys for persisted Daily OS preferences. The wire values are
// frozen for backward compatibility and must not be renamed without a
// migration. Kept in a standalone file so the sync layer can reference the
// keys without importing the Riverpod controller.

/// Key for the Daily OS greeting name. Synced across a user's devices via
/// `SyncMessage.dailyOsUserName` under last-write-wins.
const dailyOsUserNameSettingsKey = 'DAILY_OS_USER_NAME';

/// Key for the last-write timestamp (epoch millis) of
/// [dailyOsUserNameSettingsKey], used to resolve which device wins when the
/// greeting name is synced across devices.
const dailyOsUserNameUpdatedAtSettingsKey = 'DAILY_OS_USER_NAME_UPDATED_AT';

/// Key for the JSON-encoded set of category ids excluded from the day flow.
const dailyOsExcludedCategoryIdsSettingsKey = 'DAILY_OS_EXCLUDED_CATEGORY_IDS';

/// One-shot coachmark flag: the timeline gesture hint has been retired.
const dailyOsTimelineGesturesLearnedSettingsKey =
    'DAILY_OS_TIMELINE_GESTURES_LEARNED';

/// One-shot coachmark flag: the day footer coaching line has been retired.
const dailyOsDayFooterHintRetiredSettingsKey =
    'DAILY_OS_DAY_FOOTER_HINT_RETIRED';
