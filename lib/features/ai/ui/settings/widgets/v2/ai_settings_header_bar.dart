import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/breakpoints.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Subtitle paragraph + search field + green "+ Add provider" CTA
/// shown directly below the page's `SettingsPageHeader` title.
///
/// Layout from the redesigned AI Settings PNGs:
///
/// ```text
/// AI Settings
/// Configure AI providers, the models Lotti can call, and the
/// inference profiles that decide which model handles which task.
///
/// ┌──────────────────────────┐  ┌────────────────────────────┐
/// │ 🔍 Search                 │  │ +  Add provider             │
/// └──────────────────────────┘  └────────────────────────────┘
/// ```
///
/// The search field is wired to the page's `searchController` so the
/// existing debounce + filter logic carries over from v1 unchanged.
/// The Add provider CTA replaces the v1 floating action button.
class AiSettingsHeaderBar extends StatelessWidget {
  const AiSettingsHeaderBar({
    required this.searchController,
    required this.onSearchClear,
    required this.onAddProvider,
    super.key,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchClear;
  final VoidCallback onAddProvider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        0,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.aiSettingsPageLead,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          LayoutBuilder(
            builder: (context, constraints) {
              // Mobile: stack search + Add provider vertically so each
              // gets full width on a narrow viewport. Desktop /
              // tablet pane: side-by-side row with search expanded.
              final stacked =
                  constraints.maxWidth < aiSettingsHeaderStackBreakpoint;
              final searchField = AiSettingsSearchField(
                controller: searchController,
                onClear: onSearchClear,
              );
              final addButton = DesignSystemButton(
                label: messages.aiSettingsAddProviderButton,
                leadingIcon: Icons.add_rounded,
                onPressed: onAddProvider,
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    SizedBox(height: tokens.spacing.step3),
                    addButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  SizedBox(width: tokens.spacing.step3),
                  addButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Self-contained search field for the redesigned AI Settings header.
/// Lives next to the Add provider CTA. Drives the page's existing
/// `_filterState.searchQuery` via the [TextEditingController] the
/// page constructs.
///
/// Uses `ValueListenableBuilder` rather than a `StatefulWidget` +
/// `setState` so only the trailing-icon affordance rebuilds on each
/// keystroke — the rest of the field (and the header bar around it)
/// doesn't churn.
class AiSettingsSearchField extends StatelessWidget {
  const AiSettingsSearchField({
    required this.controller,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return DesignSystemTextInput(
          controller: controller,
          hintText: messages.aiSettingsSearchHintShort,
          leadingIcon: Icons.search_rounded,
          trailingIcon: hasText ? Icons.close_rounded : null,
          onTrailingIconTap: hasText ? onClear : null,
        );
      },
    );
  }
}
