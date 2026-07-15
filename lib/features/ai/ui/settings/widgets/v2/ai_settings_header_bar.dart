import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Page-header controls shown directly below the page's `SettingsPageHeader`.
///
/// The search field uses the same design-system search widget as the rest of
/// the app. The concurrency dropdown edits the device-local bounded agent-wake
/// capacity and applies to newly dispatched wakes immediately.
///
/// The "Add" affordance lives in a per-tab
/// `DesignSystemFloatingActionButton` on the page's
/// `Scaffold.floatingActionButton` slot — same FAB pattern the
/// inference profile / habit / measurable list pages already use.
class AiSettingsHeaderBar extends StatelessWidget {
  const AiSettingsHeaderBar({
    required this.searchController,
    required this.onSearchClear,
    required this.agentWakeConcurrency,
    required this.onAgentWakeConcurrencyChanged,
    super.key,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchClear;
  final int agentWakeConcurrency;
  final ValueChanged<int> onAgentWakeConcurrencyChanged;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiSettingsSearchBar(
            controller: searchController,
            hintText: context.messages.aiSettingsSearchHint,
            onClear: onSearchClear,
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemDropdown(
            label: context.messages.aiSettingsAgentWakeConcurrencyLabel,
            inputLabel: agentWakeConcurrency.toString(),
            items: [
              for (
                var value = minAgentWakeConcurrency;
                value <= maxAgentWakeConcurrency;
                value++
              )
                DesignSystemDropdownItem(
                  id: value.toString(),
                  label: value.toString(),
                  selected: value == agentWakeConcurrency,
                ),
            ],
            onItemPressed: (item) {
              final value = int.tryParse(item.id);
              if (value != null) onAgentWakeConcurrencyChanged(value);
            },
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            context.messages.aiSettingsAgentWakeConcurrencyDescription,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
