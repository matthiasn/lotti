import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemConfirmationModalWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Confirmation Modal',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ConfirmationModalOverviewPage(),
      ),
    ],
  );
}

class _ConfirmationModalOverviewPage extends StatelessWidget {
  const _ConfirmationModalOverviewPage();

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    return Padding(
      padding: EdgeInsets.all(spacing.sectionGap),
      child: ListView(
        children: [
          WidgetbookSection(
            title: 'Destructive',
            child: DesignSystemButton(
              label: 'Open destructive confirmation',
              variant: DesignSystemButtonVariant.danger,
              onPressed: () => showConfirmationModal(
                context: context,
                title: 'Discard recording?',
                message:
                    'This recording will be deleted. No audio entry, transcript, or task summary will be created.',
                cancelLabel: 'Keep Recording',
                confirmLabel: 'Discard',
              ),
            ),
          ),
          SizedBox(height: spacing.step7),
          WidgetbookSection(
            title: 'Non-destructive',
            child: DesignSystemButton(
              label: 'Open standard confirmation',
              onPressed: () => showConfirmationModal(
                context: context,
                title: 'Run maintenance task?',
                message: 'This will start a background maintenance task.',
                cancelLabel: 'Cancel',
                confirmLabel: 'Run',
                isDestructive: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
