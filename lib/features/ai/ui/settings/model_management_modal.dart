import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class ModelManagementModal extends ConsumerStatefulWidget {
  const ModelManagementModal({
    required this.currentSelectedIds,
    required this.currentDefaultId,
    required this.onSave,
    this.promptConfig,
    super.key,
  });

  final List<String> currentSelectedIds;
  final String currentDefaultId;
  final AiConfigPrompt? promptConfig;
  final void Function(List<String> newSelectedIds, String newDefaultId) onSave;

  @override
  ConsumerState<ModelManagementModal> createState() =>
      _ModelManagementModalState();
}

class _ModelManagementModalState extends ConsumerState<ModelManagementModal> {
  late Set<String> _selectedIds;
  late String _defaultId;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.currentSelectedIds.toSet();
    _defaultId = widget.currentDefaultId;
  }

  @override
  Widget build(BuildContext context) {
    final allModelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );

    return allModelsAsync.when(
      data: (allModels) {
        final allModelConfigs = allModels.whereType<AiConfigModel>().toList();

        // Filter models based on prompt requirements if promptConfig is provided
        final modelConfigs = widget.promptConfig != null
            ? allModelConfigs
                .where(
                  (model) => isModelSuitableForPrompt(
                    model: model,
                    prompt: widget.promptConfig!,
                  ),
                )
                .toList()
            : allModelConfigs;

        if (modelConfigs.isEmpty) {
          final message = widget.promptConfig != null
              ? context.messages.aiConfigNoSuitableModelsAvailable
              : context.messages.aiConfigNoModelsAvailable;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(message, textAlign: TextAlign.center),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: modelConfigs.length,
              itemBuilder: (context, index) {
                final model = modelConfigs[index];
                final isSelected = _selectedIds.contains(model.id);
                final isDefault = _defaultId == model.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(model.id);
                        if (isDefault) {
                          _defaultId =
                              _selectedIds.isNotEmpty ? _selectedIds.first : '';
                        }
                      } else {
                        _selectedIds.add(model.id);
                        if (_selectedIds.length == 1 || _defaultId.isEmpty) {
                          _defaultId = model.id;
                        }
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedIds.add(model.id);
                                if (_selectedIds.length == 1 ||
                                    _defaultId.isEmpty) {
                                  _defaultId = model.id;
                                }
                              } else {
                                _selectedIds.remove(model.id);
                                if (isDefault) {
                                  _defaultId = _selectedIds.isNotEmpty
                                      ? _selectedIds.first
                                      : '';
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.name,
                                style: context.textTheme.titleMedium,
                              ),
                              if (model.description != null &&
                                  model.description!.isNotEmpty)
                                Text(
                                  model.description!,
                                  style: context.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: isSelected ? 1 : 0,
                          child: IconButton(
                            icon: Icon(
                              isDefault ? Icons.star : Icons.star_border,
                              color: isDefault
                                  ? context.colorScheme.primary
                                  : context.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: isSelected
                                ? () {
                                    setState(() {
                                      _defaultId = model.id;
                                    });
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: (_selectedIds.isNotEmpty &&
                        _defaultId.isNotEmpty &&
                        _selectedIds.contains(_defaultId))
                    ? () {
                        widget.onSave(_selectedIds.toList(), _defaultId);
                        Navigator.of(context).pop();
                      }
                    : null,
                child: Text(context.messages.saveButtonLabel),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.messages.aiConfigFailedToLoadModels(error.toString()),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
