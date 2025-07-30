import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';

/// A widget for selecting allowed AI prompts for a category.
///
/// This widget displays a list of available prompts as checkboxes and allows
/// users to select which prompts are allowed for the category.
/// It's designed to be independent of Riverpod for better testability.
class CategoryPromptSelection extends StatelessWidget {
  const CategoryPromptSelection({
    required this.prompts,
    required this.allowedPromptIds,
    required this.onPromptToggled,
    required this.isLoading,
    this.error,
    super.key,
  });

  final List<AiConfigPrompt> prompts;
  final List<String> allowedPromptIds;
  final void Function(String promptId, {required bool isAllowed})
      onPromptToggled;
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

    if (prompts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.psychology_outlined,
        title: context.messages.noPromptsAvailable,
        description: context.messages.createPromptsFirst,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.selectAllowedPrompts,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: prompts.map((prompt) {
              final isAllowed = allowedPromptIds.contains(prompt.id);

              return CheckboxListTile(
                title: Text(prompt.name),
                subtitle: prompt.description != null
                    ? Text(
                        prompt.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                value: isAllowed,
                onChanged: (value) {
                  if (value != null) {
                    onPromptToggled(prompt.id, isAllowed: value);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
