import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Data class for automatic prompt configuration for a response type
class AutomaticPromptConfig {
  const AutomaticPromptConfig({
    required this.responseType,
    required this.title,
    required this.icon,
    required this.availablePrompts,
    required this.selectedPromptIds,
  });

  final AiResponseType responseType;
  final String title;
  final IconData icon;
  final List<AiConfigPrompt> availablePrompts;
  final List<String> selectedPromptIds;
}

/// Callback type for automatic prompt selection changes
typedef AutomaticPromptChanged = void Function(
  AiResponseType responseType,
  List<String> selectedPromptIds,
);

/// A widget for configuring automatic prompts for different response types.
///
/// This widget displays sections for each response type (audio, image, task summary)
/// and allows users to select which prompts should run automatically.
/// It's designed to be independent of Riverpod for better testability.
///
/// Note: Currently limited to single prompt selection per response type for v1.
/// The data model supports multiple prompts (`List<String>`) to allow future
/// expansion for running multiple prompts in sequence.
class CategoryAutomaticPrompts extends StatelessWidget {
  const CategoryAutomaticPrompts({
    required this.configs,
    required this.onPromptChanged,
    required this.isLoading,
    this.error,
    super.key,
  });

  final List<AutomaticPromptConfig> configs;
  final AutomaticPromptChanged onPromptChanged;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return Column(
      children: configs
          .map((config) => Padding(
                padding: EdgeInsets.only(
                  bottom: config != configs.last ? 16.0 : 0,
                ),
                child: _buildPromptSection(context, config),
              ))
          .toList(),
    );
  }

  Widget _buildPromptSection(
    BuildContext context,
    AutomaticPromptConfig config,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, size: 20),
              const SizedBox(width: 8),
              Text(
                config.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (config.availablePrompts.isEmpty)
            Text(
              context.messages.noPromptsForType,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: config.availablePrompts.map((prompt) {
                final isSelected = config.selectedPromptIds.contains(prompt.id);

                return FilterChip(
                  label: Text(prompt.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      // Currently only allow one selection per response type
                      // This is intentional for v1 - we replace any existing selection
                      // The data model supports multiple prompts (List<String>) for future flexibility
                      // when we may want to run multiple prompts in sequence
                      onPromptChanged(config.responseType, [prompt.id]);
                    } else {
                      // Deselecting - clear the selection
                      onPromptChanged(config.responseType, []);
                    }
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
