import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemToastWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Toast',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ToastOverviewPage(),
      ),
    ],
  );
}

class _ToastOverviewPage extends StatelessWidget {
  const _ToastOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _ToastSection(
            title: context.messages.designSystemVariantMatrixTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DesignSystemToast(
                  tone: DesignSystemToastTone.success,
                  title: context.messages.designSystemSuccessLabel,
                  description: context.messages.designSystemToastDetailsLabel,
                  onDismiss: _noop,
                ),
                const SizedBox(height: 16),
                DesignSystemToast(
                  tone: DesignSystemToastTone.warning,
                  title: context.messages.designSystemWarningLabel,
                  description: context.messages.designSystemToastDetailsLabel,
                  onDismiss: _noop,
                ),
                const SizedBox(height: 16),
                DesignSystemToast(
                  tone: DesignSystemToastTone.error,
                  title: context.messages.designSystemErrorLabel,
                  description: context.messages.designSystemToastDetailsLabel,
                  onDismiss: _noop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastSection extends StatelessWidget {
  const _ToastSection({
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

void _noop() {}
