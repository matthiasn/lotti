// SettingsDb keys of the companion's customization: how a person made her
// their own. The wire values are frozen and must not be renamed without a
// migration. Kept here rather than in the companion feature because sync
// writes them too, applying `SyncMessage.companionCustomization` under
// last-write-wins.

/// Her customization, as JSON.
const companionCustomizationKey = 'COMPANION_CUSTOMIZATION';

/// Epoch-millis stamp of the last write of [companionCustomizationKey], local
/// or synced: which device wins when two changed her.
const companionCustomizationUpdatedAtKey = 'COMPANION_CUSTOMIZATION_UPDATED_AT';

/// The stamp last published to sync, or received from it. While it lags
/// [companionCustomizationUpdatedAtKey] (or is missing), a customization made
/// on this device has not reached the others yet, and is published on the
/// next load.
const companionCustomizationSyncedAtKey = 'COMPANION_CUSTOMIZATION_SYNCED_AT';
