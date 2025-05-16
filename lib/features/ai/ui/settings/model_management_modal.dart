import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ModelManagementModal extends ConsumerStatefulWidget {
  const ModelManagementModal({
    required this.currentSelectedIds,
    required this.currentDefaultId,
    required this.onSave,
    super.key,
  });

  final List<String> currentSelectedIds;
  final String currentDefaultId;
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
        aiConfigByTypeControllerProvider(configType: AiConfigType.model));

    return allModelsAsync.when(
        data: (allModels) {
          // --- DIAGNOSTIC PRINT START ---
          debugPrint(
              '[ModelManagementModal] Received ${allModels.length} AiConfig items from controller for AiConfigType.model.');
          for (int i = 0; i < allModels.length; i++) {
            final item = allModels[i];
            debugPrint(
                '  Item $i: id=${item.id}, name=${item.name}, runtimeType=${item.runtimeType}, is AiConfigModel: ${item is AiConfigModel}');
          }
          // --- DIAGNOSTIC PRINT END ---

          final modelConfigs = allModels.whereType<AiConfigModel>().toList();

          // --- DIAGNOSTIC PRINT START ---
          debugPrint(
              '[ModelManagementModal] Filtered to ${modelConfigs.length} AiConfigModel items.');
          // --- DIAGNOSTIC PRINT END ---

          if (modelConfigs.isEmpty) {
            String message = context.messages.aiConfigNoModelsAvailable;
            if (allModels.isNotEmpty && modelConfigs.isEmpty) {
              // This case means items were received, but none were of type AiConfigModel
              debugPrint(
                  '[ModelManagementModal] Warning: Received AiConfig items, but none were of AiConfigModel type.');
            } else if (allModels.isEmpty) {
              debugPrint(
                  '[ModelManagementModal] No AiConfig items received from controller for AiConfigType.model.');
            }
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
                  final bool isSelected = _selectedIds.contains(model.id);

                  return CheckboxListTile(
                    title: Text(model.name),
                    subtitle: Text(model.description ?? ''),
                    value: isSelected,
                    secondary: isSelected
                        ? Radio<String>(
                            value: model.id,
                            groupValue: _defaultId,
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  _defaultId = value;
                                });
                              }
                            },
                          )
                        : null,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(model.id);
                          if (_selectedIds.length == 1 || _defaultId.isEmpty) {
                            _defaultId = model.id;
                          }
                        } else {
                          _selectedIds.remove(model.id);
                          if (_defaultId == model.id) {
                            _defaultId = _selectedIds.isNotEmpty
                                ? _selectedIds.first
                                : '';
                          }
                        }
                      });
                    },
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
          // --- DIAGNOSTIC PRINT START ---
          debugPrint('[ModelManagementModal] Error loading models: $error');
          // --- DIAGNOSTIC PRINT END ---
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.messages.aiConfigFailedToLoadModels(error.toString()),
                textAlign: TextAlign.center,
              ),
            ),
          );
        });
  }
}
