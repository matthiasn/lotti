import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Redesigned tab bar for the AI Settings page.
///
/// Layout from the populated D1 PNGs: each tab label carries its
/// counter inline ("Providers 2", "Models 5", "Profiles 2"). The
/// active tab gets the brand-teal underline. Plays the role of the
/// v1 `AiSettingsFixedHeader`'s `TabBar` row — but without the
/// search field or capability filters, which the redesigned page
/// either lifts into the page header or drops entirely.
class AiSettingsTabBar extends StatelessWidget {
  const AiSettingsTabBar({
    required this.tabController,
    required this.providerCount,
    required this.modelCount,
    required this.profileCount,
    required this.onTabChanged,
    super.key,
  });

  final TabController tabController;
  final int providerCount;
  final int modelCount;
  final int profileCount;
  final ValueChanged<AiSettingsTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: tokens.colors.decorative.level01.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: TabBar(
        controller: tabController,
        onTap: (index) => onTabChanged(AiSettingsTab.values[index]),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: tokens.colors.interactive.enabled,
        labelPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
        ),
        labelColor: tokens.colors.text.highEmphasis,
        unselectedLabelColor: tokens.colors.text.mediumEmphasis,
        labelStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
          fontWeight: tokens.typography.weight.semiBold,
        ),
        unselectedLabelStyle: tokens.typography.styles.subtitle.subtitle2,
        dividerColor: Colors.transparent,
        tabs: [
          _CounterTab(
            label: messages.aiSettingsTabProviders,
            count: providerCount,
          ),
          _CounterTab(
            label: messages.aiSettingsTabModels,
            count: modelCount,
          ),
          _CounterTab(
            label: messages.aiSettingsTabProfiles,
            count: profileCount,
          ),
        ],
      ),
    );
  }
}

class _CounterTab extends StatelessWidget {
  const _CounterTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tab(
      height: tokens.spacing.step8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label),
          SizedBox(width: tokens.spacing.step2),
          Text(
            '$count',
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
              fontWeight: tokens.typography.weight.regular,
            ),
          ),
        ],
      ),
    );
  }
}
