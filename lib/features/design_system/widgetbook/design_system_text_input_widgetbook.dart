import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTextInputWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Text input',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TextInputOverviewPage(),
      ),
    ],
  );
}

class _TextInputOverviewPage extends StatelessWidget {
  const _TextInputOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _TextInputSection(
            title: context.messages.designSystemInputVariantsTitle,
            child: const _TextInputVariants(),
          ),
        ],
      ),
    );
  }
}

class _TextInputSection extends StatelessWidget {
  const _TextInputSection({
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

class _TextInputVariants extends StatelessWidget {
  const _TextInputVariants();

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
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemDefaultLabel,
          child: DesignSystemTextInput(
            label: messages.designSystemInputLabelSample,
            hintText: messages.designSystemInputHintSample,
          ),
        ),
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemInputWithHelperLabel,
          child: DesignSystemTextInput(
            label: messages.designSystemInputLabelSample,
            hintText: messages.designSystemInputHintSample,
            helperText: messages.designSystemInputHelperSample,
          ),
        ),
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemInputWithErrorLabel,
          child: DesignSystemTextInput(
            label: messages.designSystemInputLabelSample,
            hintText: messages.designSystemInputHintSample,
            errorText: messages.designSystemInputErrorSample,
          ),
        ),
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemInputWithIconsLabel,
          child: DesignSystemTextInput(
            label: messages.designSystemInputLabelSample,
            hintText: messages.designSystemInputHintSample,
            leadingIcon: Icons.search,
            trailingIcon: Icons.clear,
          ),
        ),
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemDisabledLabel,
          child: DesignSystemTextInput(
            label: messages.designSystemInputLabelSample,
            hintText: messages.designSystemInputHintSample,
            enabled: false,
          ),
        ),
        _variant(
          descriptionStyle: descriptionStyle,
          label: messages.designSystemSmallLabel,
          child: DesignSystemTextInput(
            label: messages.designSystemInputLabelSample,
            hintText: messages.designSystemInputHintSample,
            size: DesignSystemTextInputSize.small,
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
      width: 401,
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
