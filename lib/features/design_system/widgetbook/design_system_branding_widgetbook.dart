import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
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
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(minWidth: 360, minHeight: 180),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: brightness == Brightness.dark
                ? const Color(0xFF1F1F1F)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: const DesignSystemBrandLogo(height: 74),
        ),
      ),
    );
  }
}
