import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';

/// A widget for selecting allowed AI prompts for a category.
///
/// This widget displays a list of available prompts as checkboxes and allows
/// users to select which prompts are allowed for the category.
/// It's designed to be independent of Riverpod for better testability.
///
/// When [models] and [providers] are supplied, a provider filter row appears
/// above the prompt list so users can narrow down by AI provider.
class CategoryPromptSelection extends StatefulWidget {
  const CategoryPromptSelection({
    required this.prompts,
    required this.allowedPromptIds,
    required this.onPromptToggled,
    required this.isLoading,
    this.models = const [],
    this.providers = const [],
    this.error,
    super.key,
  });

  final List<AiConfigPrompt> prompts;
  final List<String> allowedPromptIds;
  final void Function(String promptId, {required bool isAllowed})
      onPromptToggled;
  final bool isLoading;
  final List<AiConfigModel> models;
  final List<AiConfigInferenceProvider> providers;
  final String? error;

  @override
  State<CategoryPromptSelection> createState() =>
      _CategoryPromptSelectionState();
}

class _CategoryPromptSelectionState extends State<CategoryPromptSelection> {
  String? _selectedProviderId;

  Map<String, AiConfigModel> _modelById = {};

  @override
  void initState() {
    super.initState();
    _rebuildModelIndex();
  }

  @override
  void didUpdateWidget(CategoryPromptSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.models != widget.models) {
      _rebuildModelIndex();
    }
    // Reset filter when the selected provider is no longer relevant.
    if (_selectedProviderId != null) {
      final relevantIds = _providerIdsWithPrompts();
      final stillExists =
          widget.providers.any((p) => p.id == _selectedProviderId);
      if (!relevantIds.contains(_selectedProviderId) || !stillExists) {
        setState(() => _selectedProviderId = null);
      }
    }
  }

  void _rebuildModelIndex() {
    _modelById = {for (final m in widget.models) m.id: m};
  }

  /// Resolves the provider ID for a prompt via its default model.
  String? _providerIdForPrompt(AiConfigPrompt prompt) {
    return _modelById[prompt.defaultModelId]?.inferenceProviderId;
  }

  /// Returns the set of provider IDs that are referenced by at least one
  /// prompt in the current list.
  Set<String> _providerIdsWithPrompts() {
    return {
      for (final prompt in widget.prompts)
        if (_providerIdForPrompt(prompt) case final pid?) pid,
    };
  }

  List<AiConfigPrompt> _filteredPrompts() {
    if (_selectedProviderId == null) {
      return widget.prompts;
    }
    return widget.prompts.where((prompt) {
      return _providerIdForPrompt(prompt) == _selectedProviderId;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (widget.prompts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.psychology_outlined,
        title: context.messages.noPromptsAvailable,
        description: context.messages.createPromptsFirst,
      );
    }

    final showFilter = widget.providers.length > 1;
    final filteredPrompts = _filteredPrompts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.selectAllowedPrompts,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (showFilter) ...[
          const SizedBox(height: 8),
          _buildProviderFilterRow(context),
        ],
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: filteredPrompts.map((prompt) {
              final isAllowed = widget.allowedPromptIds.contains(prompt.id);

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
                    widget.onPromptToggled(prompt.id, isAllowed: value);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderFilterRow(BuildContext context) {
    final relevantIds = _providerIdsWithPrompts();
    final relevantProviders = widget.providers
        .where((p) => relevantIds.contains(p.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(context.messages.categoryPromptFilterAll),
              selected: _selectedProviderId == null,
              onSelected: (_) => setState(() => _selectedProviderId = null),
            ),
          ),
          ...relevantProviders.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(provider.name),
                selected: _selectedProviderId == provider.id,
                onSelected: (_) =>
                    setState(() => _selectedProviderId = provider.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
