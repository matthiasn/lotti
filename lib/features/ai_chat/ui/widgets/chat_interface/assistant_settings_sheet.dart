import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

// Simple model selector sheet reused from header behavior
class AssistantSettingsSheet extends ConsumerWidget {
  const AssistantSettingsSheet({required this.categoryId, super.key});
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eligibleAsync =
        ref.watch(eligibleChatModelsForCategoryProvider(categoryId));
    final sessionController =
        ref.read(chatSessionControllerProvider(categoryId).notifier);
    final sessionState = ref.watch(chatSessionControllerProvider(categoryId));
    final isStreaming = sessionState.isStreaming;
    final includeThoughts = ref.watch(geminiIncludeThoughtsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.tune, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assistant Settings',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              eligibleAsync.when(
                data: (models) {
                  if (models.isEmpty) {
                    return const Text('No eligible models');
                  }
                  // Use a safe selected value to avoid assertion if the
                  // previously selected model is not in the eligible list.
                  final safeSelectedId = models
                          .any((m) => m.id == sessionState.selectedModelId)
                      ? sessionState.selectedModelId
                      : null;
                  return DropdownButtonFormField<String>(
                    initialValue: safeSelectedId,
                    decoration: InputDecoration(
                      labelText: 'Model',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.92),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    hint: const Text('Select model'),
                    isExpanded: true,
                    onChanged: isStreaming
                        ? null
                        : (v) async {
                            if (v != null) await sessionController.setModel(v);
                          },
                    items: [
                      for (final m in models)
                        DropdownMenuItem<String>(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 48,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (err, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Failed to load models'),
                    const SizedBox(height: 8),
                    Text('$err',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              UnifiedToggleField(
                title: 'Show reasoning',
                value: includeThoughts,
                onChanged: isStreaming
                    ? null
                    : (v) => ref
                        .read(geminiIncludeThoughtsProvider.notifier)
                        .state = v,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
