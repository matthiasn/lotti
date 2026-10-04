/// Settings URLs that code outside the settings routing layer has to name.
///
/// Every other settings URL is declared once, on its entry in `settingsRoutes`
/// (`lib/features/settings/routing/settings_routes.dart`). These two live in a
/// UI-free module because features the registry itself imports — the AI
/// settings pages — need them too, and reaching for the registry from there
/// would close an import cycle.
library;

/// The Settings landing, where nothing is selected.
const String settingsRootUrl = '/settings';

/// The AI Settings list — where the tree's `ai` node lands, and where every
/// AI detail surface returns to.
///
/// The `ai` route entry, the pop target of each AI detail page and the AI
/// pages' own back affordance (`popAiSettingsDetail`) all read this one
/// constant, so the back gesture and the header chevron cannot drift onto
/// different destinations.
const String aiSettingsParentRoute = '/settings/ai';
