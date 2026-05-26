part of 'inference_profile_form.dart';

/// A slot picker field that shows the selected model and opens a picker modal.
class _ModelSlotField extends ConsumerWidget {
  const _ModelSlotField({
    required this.label,
    required this.modelId,
    required this.onModelSelected,
    required this.filter,
    this.required = false,
  });

  final String label;
  final String? modelId;
  final ValueChanged<String?> onModelSelected;
  final bool Function(AiConfigModel) filter;
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    final allModels = switch (modelsAsync) {
      AsyncData(:final value) => value.whereType<AiConfigModel>().toList(),
      _ => <AiConfigModel>[],
    };
    final providers = switch (providersAsync) {
      AsyncData(:final value) =>
        value.whereType<AiConfigInferenceProvider>().toList(),
      _ => <AiConfigInferenceProvider>[],
    };

    final filteredModels = allModels.where(filter).toList();

    final selectedModel = _resolveModelSlot(modelId, allModels);

    return InkWell(
      onTap: filteredModels.isNotEmpty
          ? () => _showModelPicker(
              context,
              filteredModels,
              providers,
            )
          : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label${required ? ' *' : ''}',
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (modelId != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onModelSelected(null),
                ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          enabled: filteredModels.isNotEmpty,
        ),
        child: selectedModel != null
            ? Text(
                selectedModel.name,
                style: context.textTheme.bodyLarge,
              )
            : Text(
                modelId ?? context.messages.inferenceProfileSelectModel,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontFamily: modelId != null ? 'monospace' : null,
                ),
              ),
      ),
    );
  }

  void _showModelPicker(
    BuildContext context,
    List<AiConfigModel> models,
    List<AiConfigInferenceProvider> providers,
  ) {
    SelectionModalBase.show(
      context: context,
      title: label,
      child: _SlotModelPickerContent(
        models: models,
        providers: providers,
        selectedModelId: modelId,
        onSelected: (id) {
          onModelSelected(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// Body of the slot-picker modal. Stateful so the search field can
/// filter the list reactively without rebuilding the surrounding
/// `SelectionModalBase` chrome on every keystroke. The substring
/// match runs against the model display name, the wire-level
/// `providerModelId`, and the resolved provider name — so a query
/// like "gemini" finds every Gemini-owned row even when the model's
/// display name doesn't start with the provider's name.
class _SlotModelPickerContent extends StatefulWidget {
  const _SlotModelPickerContent({
    required this.models,
    required this.providers,
    required this.selectedModelId,
    required this.onSelected,
  });

  final List<AiConfigModel> models;
  final List<AiConfigInferenceProvider> providers;
  final String? selectedModelId;
  final ValueChanged<String> onSelected;

  @override
  State<_SlotModelPickerContent> createState() =>
      _SlotModelPickerContentState();
}

class _SlotModelPickerContentState extends State<_SlotModelPickerContent> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final queryLower = _query.trim().toLowerCase();
    // Build the id→name lookup once per build instead of doing a
    // linear scan of `widget.providers` for every model during the
    // filter pass and again when rendering each row. Filter runs on
    // every keystroke, so the prior O(N·M) shape became visible on
    // longer model lists.
    final providerNamesById = <String, String>{
      for (final p in widget.providers) p.id: p.name,
    };

    final filteredModels = widget.models.where((m) {
      if (queryLower.isEmpty) return true;
      if (m.name.toLowerCase().contains(queryLower)) return true;
      if (m.providerModelId.toLowerCase().contains(queryLower)) return true;
      final providerLabel = providerNamesById[m.inferenceProviderId];
      return providerLabel != null &&
          providerLabel.toLowerCase().contains(queryLower);
    }).toList();

    // Resolve the slot value with the shared exact-id/unique-provider-id
    // rule so an ambiguous legacy id never marks multiple rows selected.
    final resolvedSelectedId = _resolveModelSlot(
      widget.selectedModelId,
      widget.models,
    )?.id;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignSystemSearch(
            hintText: messages.aiProfileModelPickerSearchHint,
            onChanged: (value) => setState(() => _query = value),
            onClear: () => setState(() => _query = ''),
          ),
          SizedBox(height: tokens.spacing.step5),
          if (filteredModels.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
              child: Text(
                messages.filterSelectionNoMatches,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            )
          else
            for (final model in filteredModels)
              _SlotModelPickerRow(
                model: model,
                providerLabel: providerNamesById[model.inferenceProviderId],
                selected: model.id == resolvedSelectedId,
                onTap: () => widget.onSelected(model.id),
              ),
        ],
      ),
    );
  }
}

/// Single row inside the slot picker. Extracted so the search filter
/// can rebuild the parent's row list without churning each row's
/// internal layout — the row only rebuilds when its own props
/// (selection, provider label) change.
class _SlotModelPickerRow extends StatelessWidget {
  const _SlotModelPickerRow({
    required this.model,
    required this.providerLabel,
    required this.selected,
    required this.onTap,
  });

  final AiConfigModel model;
  final String? providerLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      ?providerLabel,
      model.providerModelId,
    ].join(' — ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    color: context.colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
