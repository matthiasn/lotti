import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemBrandingWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Branding',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _BrandingOverviewPage(),
      ),
    ],
  );
}

class _BrandingOverviewPage extends StatelessWidget {
  const _BrandingOverviewPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, minHeight: 180),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(tokens.spacing.step7),
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            ),
            alignment: Alignment.center,
            child: const DesignSystemBrandLogo(height: 74),
          ),
        ),
      ),
    );
  }
}
