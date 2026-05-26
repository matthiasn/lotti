import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';
import 'package:lotti/widgets/selection/selection_option.dart';

/// Reusable Gemini thinking-mode picker.
///
/// Model settings use this as the saved default for a model row. Invocation
/// flows use the same content as a one-run override picker, preselected to the
/// row default.
class GeminiThinkingModePickerModal {
  const GeminiThinkingModePickerModal._();

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
    return SelectionModalContent(
      children: [
        SelectionOptionsList(
          itemCount: modes.length,
          itemBuilder: (context, index) {
            final mode = modes[index];
            return SelectionOption(
              title: label(context, mode),
              description: description(context, mode),
              icon: icon(mode),
              isSelected: mode == selectedMode,
              onTap: () => onChanged(mode),
            );
          },
        ),
      ],
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
