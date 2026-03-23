import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemListItemWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'List',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ListItemOverviewPage(),
      ),
    ],
  );
}

class _ListItemOverviewPage extends StatelessWidget {
  const _ListItemOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _ListItemSection(
            title: context.messages.designSystemListItemVariantsTitle,
            child: const _ListItemVariants(),
          ),
        ],
      ),
    );
  }
}

class _ListItemSection extends StatelessWidget {
  const _ListItemSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _ListItemVariants extends StatelessWidget {
  const _ListItemVariants();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final messages = context.messages;
    final title = messages.designSystemListItemTitleSample;
    final subtitle = messages.designSystemListItemSubtitleSample;

    return SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One line, medium, with leading and trailing
          Text(
            messages.designSystemListItemOneLineLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemListItem(
            title: title,
            leading: const Icon(Icons.person, size: 24),
            trailing: const Icon(Icons.chevron_right),
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Two lines, medium, with leading + badge + chevron
          Text(
            messages.designSystemListItemTwoLinesLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemListItem(
            title: title,
            subtitle: subtitle,
            leading: const Icon(Icons.person, size: 24),
            leadingExtra: Icon(
              Icons.circle,
              size: 8,
              color: tokens.colors.interactive.enabled,
            ),
            trailing: const DesignSystemBadge.number(value: '10'),
            trailingExtra: const Icon(Icons.chevron_right),
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Hover state
          Text(messages.designSystemHoverLabel, style: descriptionStyle),
          const SizedBox(height: 8),
          DesignSystemListItem(
            title: title,
            leading: const Icon(Icons.person, size: 24),
            forcedState: DesignSystemListItemVisualState.hover,
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Pressed state
          Text(messages.designSystemPressedLabel, style: descriptionStyle),
          const SizedBox(height: 8),
          DesignSystemListItem(
            title: title,
            leading: const Icon(Icons.person, size: 24),
            forcedState: DesignSystemListItemVisualState.pressed,
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Activated state
          Text(
            messages.designSystemListItemActivatedLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemListItem(
            title: title,
            leading: const Icon(Icons.person, size: 24),
            activated: true,
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Disabled
          Text(messages.designSystemDisabledLabel, style: descriptionStyle),
          const SizedBox(height: 8),
          const DesignSystemListItem(
            title: 'Title',
            leading: Icon(Icons.person, size: 24),
            showDivider: true,
          ),

          const SizedBox(height: 16),

          // Small size
          Text(messages.designSystemSmallLabel, style: descriptionStyle),
          const SizedBox(height: 8),
          DesignSystemListItem(
            title: title,
            subtitle: subtitle,
            size: DesignSystemListItemSize.small,
            leading: const Icon(Icons.person, size: 20),
            trailing: const Icon(Icons.chevron_right, size: 16),
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // With divider
          Text(
            messages.designSystemListItemWithDividerLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          ...List.generate(
            3,
            (i) => DesignSystemListItem(
              title: '$title ${i + 1}',
              leading: const Icon(Icons.person, size: 24),
              showDivider: i < 2,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
