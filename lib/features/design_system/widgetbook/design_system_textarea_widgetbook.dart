import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTextareaWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Textarea',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TextareaOverviewPage(),
      ),
    ],
  );
}

class _TextareaOverviewPage extends StatelessWidget {
  const _TextareaOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _TextareaSection(
            title: context.messages.designSystemTextareaVariantsTitle,
            child: const _TextareaVariants(),
          ),
        ],
      ),
    );
  }
}

class _TextareaSection extends StatelessWidget {
  const _TextareaSection({
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

class _TextareaVariants extends StatelessWidget {
  const _TextareaVariants();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final descriptionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final messages = context.messages;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        // Default empty
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemDefaultLabel,
          child: DesignSystemTextarea(
            label: messages.designSystemTextareaLabelSample,
            hintText: messages.designSystemTextareaHintSample,
          ),
        ),

        // With helper text
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemTextareaWithHelperLabel,
          child: DesignSystemTextarea(
            label: messages.designSystemTextareaLabelSample,
            hintText: messages.designSystemTextareaHintSample,
            helperText: messages.designSystemTextareaHelperSample,
          ),
        ),

        // With error
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemTextareaWithErrorLabel,
          child: DesignSystemTextarea(
            label: messages.designSystemTextareaLabelSample,
            hintText: messages.designSystemTextareaHintSample,
            errorText: messages.designSystemTextareaErrorSample,
          ),
        ),

        // With counter
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemTextareaWithCounterLabel,
          child: DesignSystemTextarea(
            label: messages.designSystemTextareaLabelSample,
            hintText: messages.designSystemTextareaHintSample,
            helperText: messages.designSystemTextareaHelperSample,
            maxLength: 200,
            showCounter: true,
          ),
        ),

        // Disabled
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemDisabledLabel,
          child: DesignSystemTextarea(
            label: messages.designSystemTextareaLabelSample,
            hintText: messages.designSystemTextareaHintSample,
            enabled: false,
          ),
        ),

        // Small size
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemSmallLabel,
          child: DesignSystemTextarea(
            label: messages.designSystemTextareaLabelSample,
            hintText: messages.designSystemTextareaHintSample,
            size: DesignSystemTextareaSize.small,
          ),
        ),
      ],
    );
  }

  Widget _variant({
    required TextStyle descriptionStyle,
    required String label,
    required Widget child,
  }) {
    return SizedBox(
      width: 405,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: descriptionStyle),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
