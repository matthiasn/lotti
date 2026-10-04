// SettingsDb keys for the onboarding welcome's auto-show bookkeeping. The
// wire values are frozen; renaming one needs a migration. Kept in a
// standalone file so the demo seeder can mark the welcome done without
// importing the onboarding feature.

/// Prefix for every private `SettingsDb` key backing the onboarding welcome's
/// auto-show cadence. Deliberately *not* a `ConfigFlags` row -- `ConfigFlags`
/// is for public, user-toggleable flags (Settings > Advanced > Flags); this
/// is per-install bookkeeping the user never edits directly.
const _welcomeKeyPrefix = 'welcome_';

/// Set once the user completes the essential setup (a provider is connected)
/// via `OnboardingWelcomeCadence.markCompleted` -- permanently retires the
/// auto-show gate regardless of the shown-count/window budget below. This is
/// what stops the welcome from re-appearing after a user finishes the flow
/// but before any structured task has landed (so `reachedRealAha` is still
/// false); without it such a user would keep seeing the welcome until the
/// shown-count/window cap ran out.
const onboardingWelcomeCompletedKey = '${_welcomeKeyPrefix}completed';

/// How many times the welcome has auto-shown so far.
const onboardingWelcomeShownCountKey = '${_welcomeKeyPrefix}shown_count';

/// ISO-8601 UTC timestamp of the first time the welcome auto-showed --
/// the anchor `isOnboardingWelcomeEligible` measures `onboardingWelcomeWindow`
/// from.
const onboardingWelcomeFirstShownAtKey = '${_welcomeKeyPrefix}first_shown_at';
