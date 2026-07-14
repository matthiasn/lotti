import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Reusable Gemini thinking-mode picker.
///
/// Model settings use this as the saved default for a model row. Invocation
/// flows use the same content as a one-run override picker, preselected to the
/// row default.
abstract final class GeminiThinkingModePickerModal {
  static Future<GeminiThinkingMode?> show({
    required BuildContext context,
    required GeminiThinkingMode selectedMode,
    String? title,
  }) {
    return ModalUtils.showSinglePageModal<GeminiThinkingMode>(
      context: context,
      title: title ?? context.messages.modelEditGeminiThinkingModeLabel,
      padding: EdgeInsets.zero,
      builder: (modalContext) => GeminiThinkingModePickerContent(
        selectedMode: selectedMode,
        onChanged: (mode) => Navigator.of(modalContext).pop(mode),
      ),
    );
  }
}

class GeminiThinkingModePickerContent extends StatelessWidget {
  const GeminiThinkingModePickerContent({
    required this.selectedMode,
    required this.onChanged,
    super.key,
  });

  final GeminiThinkingMode selectedMode;
  final ValueChanged<GeminiThinkingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = GeminiThinkingMode.values;
    final tokens = context.designTokens;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in modes)
            DesignSystemSelectionRow(
              key: ValueKey('gemini-thinking-${mode.name}'),
              title: label(context, mode),
              subtitle: description(context, mode),
              type: DesignSystemSelectionRowType.singleSelect,
              selected: mode == selectedMode,
              leading: Icon(
                icon(mode),
                color: tokens.colors.text.mediumEmphasis,
                size: tokens.spacing.step6,
              ),
              onTap: () => onChanged(mode),
            ),
        ],
      ),
    );
  }

  static String label(BuildContext context, GeminiThinkingMode mode) {
    final messages = context.messages;
    return switch (mode) {
      GeminiThinkingMode.minimal => messages.geminiThinkingModeMinimalLabel,
      GeminiThinkingMode.low => messages.geminiThinkingModeLowLabel,
      GeminiThinkingMode.medium => messages.geminiThinkingModeMediumLabel,
      GeminiThinkingMode.high => messages.geminiThinkingModeHighLabel,
    };
  }

  static String description(BuildContext context, GeminiThinkingMode mode) {
    final messages = context.messages;
    return switch (mode) {
      GeminiThinkingMode.minimal =>
        messages.geminiThinkingModeMinimalDescription,
      GeminiThinkingMode.low => messages.geminiThinkingModeLowDescription,
      GeminiThinkingMode.medium => messages.geminiThinkingModeMediumDescription,
      GeminiThinkingMode.high => messages.geminiThinkingModeHighDescription,
    };
  }

  static IconData icon(GeminiThinkingMode mode) {
    return switch (mode) {
      GeminiThinkingMode.minimal => Icons.flash_on_rounded,
      GeminiThinkingMode.low => Icons.speed_rounded,
      GeminiThinkingMode.medium => Icons.psychology_alt_rounded,
      GeminiThinkingMode.high => Icons.auto_awesome_rounded,
    };
  }
}
