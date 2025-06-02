// Modal for selecting a preconfigured prompt template.
//
// This modal presents the user with a list of available preconfigured
// prompt templates (Task Summary, Action Item Suggestions, Image Analysis,
// Audio Transcription) and allows them to select one to populate the
// prompt form.

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

/// Shows a modal dialog for selecting a preconfigured prompt template.
/// Returns the selected [PreconfiguredPrompt] or null if cancelled.
Future<PreconfiguredPrompt?> showPreconfiguredPromptSelectionModal(
  BuildContext context,
) async {
  return showModalActionSheet<PreconfiguredPrompt>(
    context: context,
    title: 'Select Preconfigured Prompt',
    actions: preconfiguredPrompts
        .map(
          (prompt) => ModalSheetAction<PreconfiguredPrompt>(
            icon: _getIconForPromptType(prompt.type),
            label: prompt.name,
            key: prompt,
          ),
        )
        .toList(),
  );
}

/// Gets the appropriate icon for a prompt type
IconData _getIconForPromptType(String type) {
  switch (type) {
    case 'task_summary':
      return Icons.summarize_outlined;
    case 'action_item_suggestions':
      return Icons.checklist_outlined;
    case 'image_analysis':
      return Icons.image_outlined;
    case 'audio_transcription':
      return Icons.mic_outlined;
    default:
      return Icons.description_outlined;
  }
}

/// Widget that displays information about a preconfigured prompt
class PreconfiguredPromptTile extends StatelessWidget {
  const PreconfiguredPromptTile({
    required this.prompt,
    required this.onTap,
    super.key,
  });

  final PreconfiguredPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIconForPromptType(prompt.type),
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      prompt.name,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                prompt.description,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  // Display required input types
                  ...prompt.requiredInputData.map(
                    (inputType) => Chip(
                      label: Text(
                        _getInputTypeLabel(inputType),
                        style: context.textTheme.labelSmall,
                      ),
                      backgroundColor: context.colorScheme.secondaryContainer,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  // Display if reasoning is required
                  if (prompt.useReasoning)
                    Chip(
                      label: Text(
                        context.messages.aiConfigUseReasoningFieldLabel,
                        style: context.textTheme.labelSmall,
                      ),
                      backgroundColor: context.colorScheme.tertiaryContainer,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInputTypeLabel(InputDataType type) {
    switch (type) {
      case InputDataType.task:
        return 'Task';
      case InputDataType.tasksList:
        return 'Tasks List';
      case InputDataType.audioFiles:
        return 'Audio';
      case InputDataType.images:
        return 'Images';
    }
  }
}
