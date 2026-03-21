import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemDividerWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Divider',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _DividerOverviewPage(),
      ),
    ],
  );
}

class _DividerOverviewPage extends StatelessWidget {
  const _DividerOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _DividerSection(
            title: context.messages.designSystemVariantMatrixTitle,
            child: Wrap(
              spacing: 32,
              runSpacing: 24,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: _DividerTile(
                    label: context.messages.designSystemHorizontalLabel,
                    child: const DesignSystemDivider(),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _DividerTile(
                    label: context.messages.designSystemWithLabelLabel,
                    child: DesignSystemDivider(
                      label: context.messages.designSystemDividerLabelText,
                    ),
                  ),
                ),
                _DividerTile(
                  label: context.messages.designSystemVerticalLabel,
                  child: const DesignSystemDivider(
                    orientation: DesignSystemDividerOrientation.vertical,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerSection extends StatelessWidget {
  const _DividerSection({
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

class _DividerTile extends StatelessWidget {
  const _DividerTile({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
