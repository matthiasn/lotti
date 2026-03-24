import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemContextMenuWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Context menu',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ContextMenuOverviewPage(),
      ),
    ],
  );
}

class _ContextMenuOverviewPage extends StatelessWidget {
  const _ContextMenuOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _ContextMenuSection(
            title: context.messages.designSystemContextMenuVariantsTitle,
            child: const _ContextMenuVariants(),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuSection extends StatelessWidget {
  const _ContextMenuSection({
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

class _ContextMenuVariants extends StatelessWidget {
  const _ContextMenuVariants();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final messages = context.messages;

    final sampleItems = List.generate(
      3,
      (i) => DesignSystemContextMenuItem(
        label: 'Item ${i + 1}',
        icon: Icons.file_copy_outlined,
        onTap: () {},
      ),
    );

    final manyItems = [
      ...List.generate(
        6,
        (i) => DesignSystemContextMenuItem(
          label: 'Item ${i + 1}',
          icon: Icons.file_copy_outlined,
          onTap: () {},
        ),
      ),
      DesignSystemContextMenuItem(
        label: messages.designSystemContextMenuDeleteLabel,
        icon: Icons.delete_outline,
        isDestructive: true,
        onTap: () {},
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(messages.designSystemMediumLabel, style: descriptionStyle),
              const SizedBox(height: 8),
              DesignSystemContextMenu(items: sampleItems),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(messages.designSystemSmallLabel, style: descriptionStyle),
              const SizedBox(height: 8),
              DesignSystemContextMenu(
                items: sampleItems,
                size: DesignSystemContextMenuSize.small,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scrollable', style: descriptionStyle),
              const SizedBox(height: 8),
              DesignSystemContextMenu(items: manyItems),
            ],
          ),
        ),
      ],
    );
  }
}
