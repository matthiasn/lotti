import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';

/// Widget providing provider-then-model selection for agent templates.
///
/// Only models that are reasoning-capable AND support function calling
/// are shown. An optional provider filter narrows the model list.
class AgentModelSelector extends ConsumerStatefulWidget {
  const AgentModelSelector({
    required this.currentModelId,
    required this.onModelSelected,
    super.key,
  });

  /// Current `providerModelId` to show as selected, or null if none selected.
  final String? currentModelId;

  /// Called when the user selects or clears a model.
  ///
  /// Passes the `providerModelId` on selection, or `null` when cleared
  /// (e.g. when the provider filter changes and the current model no longer
  /// matches).
  final ValueChanged<String?> onModelSelected;

  @override
  ConsumerState<AgentModelSelector> createState() => _AgentModelSelectorState();
}

class _AgentModelSelectorState extends ConsumerState<AgentModelSelector> {
  String? _selectedProviderId;

  @override
  Widget build(BuildContext context) {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.model,
      ),
    );

    final providers = switch (providersAsync) {
      AsyncData(:final value) =>
        value.whereType<AiConfigInferenceProvider>().toList(),
      _ => <AiConfigInferenceProvider>[],
    };
    final allModels = switch (modelsAsync) {
      AsyncData(:final value) => value.whereType<AiConfigModel>().toList(),
      _ => <AiConfigModel>[],
    };

    // Filter to only reasoning models with function calling support.
    final suitableModels = allModels
        .where((m) => m.isReasoningModel && m.supportsFunctionCalling)
        .toList();

    // Further filter by selected provider if one is chosen.
    final filteredModels = _selectedProviderId != null
        ? suitableModels
            .where((m) => m.inferenceProviderId == _selectedProviderId)
            .toList()
        : suitableModels;

    // Resolve names for display.
    final selectedProviderName = _selectedProviderId != null
        ? providers
            .where((p) => p.id == _selectedProviderId)
            .map((p) => p.name)
            .firstOrNull
        : null;

    final selectedModel = widget.currentModelId != null
        ? allModels
            .where((m) => m.providerModelId == widget.currentModelId)
            .firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Provider filter field
        _SelectorField(
          label: context.messages.aiConfigSelectProviderModalTitle,
          value: selectedProviderName,
          placeholder: context.messages.agentTemplateAllProviders,
          onTap: () => _showProviderPicker(context, providers),
        ),
        const SizedBox(height: 16),
        // Model selection field
        _SelectorField(
          label: context.messages.agentTemplateModelLabel,
          value: selectedModel?.name ?? widget.currentModelId,
          subtitle: selectedModel != null ? widget.currentModelId : null,
          placeholder: context.messages.agentTemplateModelRequirements,
          onTap: filteredModels.isNotEmpty
              ? () => _showModelPicker(context, filteredModels, providers)
              : null,
        ),
      ],
    );
  }

  void _showProviderPicker(
    BuildContext context,
    List<AiConfigInferenceProvider> providers,
  ) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.aiConfigSelectProviderModalTitle,
      child: _ProviderPickerContent(
        providers: providers,
        selectedProviderId: _selectedProviderId,
        onSelected: (id) {
          setState(() {
            _selectedProviderId = id;
            // Clear model selection — the previous model may not belong
            // to the newly selected provider.
            widget.onModelSelected(null);
          });
        },
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
      title: context.messages.agentTemplateModelLabel,
      child: _ModelPickerContent(
        models: models,
        providers: providers,
        selectedModelId: widget.currentModelId,
        showProviderName: _selectedProviderId == null,
        onSelected: widget.onModelSelected,
      ),
    );
  }
}

/// Tappable field that looks like a form field, showing a label + selected value.
class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.onTap,
    this.value,
    this.subtitle,
    this.placeholder,
  });

  final String label;
  final String? value;
  final String? subtitle;
  final String? placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: onTap != null,
        ),
        child: value != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value!,
                    style: context.textTheme.bodyLarge,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              )
            : Text(
                placeholder ?? '',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }
}

/// Modal content for picking a provider (or "All Providers").
class _ProviderPickerContent extends StatelessWidget {
  const _ProviderPickerContent({
    required this.providers,
    required this.selectedProviderId,
    required this.onSelected,
  });

  final List<AiConfigInferenceProvider> providers;
  final String? selectedProviderId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "All providers" option
          _PickerTile(
            title: context.messages.agentTemplateAllProviders,
            isSelected: selectedProviderId == null,
            onTap: () {
              onSelected(null);
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
          ...providers.map(
            (p) => _PickerTile(
              title: p.name,
              subtitle: p.description,
              isSelected: p.id == selectedProviderId,
              onTap: () {
                onSelected(p.id);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal content for picking a model.
class _ModelPickerContent extends StatelessWidget {
  const _ModelPickerContent({
    required this.models,
    required this.providers,
    required this.selectedModelId,
    required this.showProviderName,
    required this.onSelected,
  });

  final List<AiConfigModel> models;
  final List<AiConfigInferenceProvider> providers;
  final String? selectedModelId;
  final bool showProviderName;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final providerNameById = showProviderName
        ? {for (final p in providers) p.id: p.name}
        : const <String, String>{};

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: models.map((model) {
          final providerLabel = providerNameById[model.inferenceProviderId];
          final subtitle = [
            if (providerLabel != null) providerLabel,
            model.providerModelId,
          ].join(' — ');

          return _PickerTile(
            title: model.name,
            subtitle: subtitle,
            isSelected: model.providerModelId == selectedModelId,
            onTap: () {
              onSelected(model.providerModelId);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }
}

/// Reusable tile for picker modals.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
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
                        title,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
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
