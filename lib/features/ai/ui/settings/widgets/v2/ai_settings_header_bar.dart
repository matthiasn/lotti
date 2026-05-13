import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Page-header search row shown directly below the page's
/// `SettingsPageHeader` title. Just a single `AiSettingsSearchBar`
/// (the same widget the pre-v3 page used, which itself wraps
/// `LottiSearchBar`) so the search styling and placeholder match
/// every other search field in the app. The previous v3 prototype
/// shipped a subtitle paragraph and a custom design-system text
/// input here — both removed: the subtitle is duplicative of the
/// page title + sidebar leaf, and the custom input had a different
/// hint than what users see across the rest of the app.
///
/// The "Add" affordance moved to a per-tab
/// `DesignSystemFloatingActionButton` on the page's
/// `Scaffold.floatingActionButton` slot — same FAB pattern the
/// inference profile / habit / measurable list pages already use.
class AiSettingsHeaderBar extends StatelessWidget {
  const AiSettingsHeaderBar({
    required this.searchController,
    required this.onSearchClear,
    super.key,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        0,
        tokens.spacing.step5,
        tokens.spacing.step4,
      ),
      child: AiSettingsSearchBar(
        controller: searchController,
        onClear: onSearchClear,
      ),
    );
  }
}
