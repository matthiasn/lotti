import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';
import 'package:uuid/uuid.dart';

/// Create or edit an inference profile.
class InferenceProfileForm extends ConsumerStatefulWidget {
  const InferenceProfileForm({this.existingProfile, super.key});

  final AiConfigInferenceProfile? existingProfile;

  @override
  ConsumerState<InferenceProfileForm> createState() =>
      _InferenceProfileFormState();
}

class _InferenceProfileFormState extends ConsumerState<InferenceProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String? _thinkingModelId;
  String? _imageRecognitionModelId;
  String? _transcriptionModelId;
  String? _imageGenerationModelId;
  bool _desktopOnly = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existingProfile != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _thinkingModelId = p?.thinkingModelId;
    _imageRecognitionModelId = p?.imageRecognitionModelId;
    _transcriptionModelId = p?.transcriptionModelId;
    _imageGenerationModelId = p?.imageGenerationModelId;
    _desktopOnly = p?.desktopOnly ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? context.colorScheme.surfaceContainerLowest
          : context.colorScheme.scrim,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? context.messages.inferenceProfileEditTitle
              : context.messages.inferenceProfileCreateTitle,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(context.messages.inferenceProfileSaveButton),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.messages.inferenceProfileNameLabel,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.messages.inferenceProfileNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.messages.inferenceProfileDescriptionLabel,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Thinking model (required)
            _ModelSlotField(
              label: context.messages.inferenceProfileThinking,
              modelId: _thinkingModelId,
              required: true,
              filter: (m) => m.supportsFunctionCalling,
              onModelSelected: (id) => setState(() => _thinkingModelId = id),
            ),
            const SizedBox(height: 16),

            // Image recognition model (optional)
            _ModelSlotField(
              label: context.messages.inferenceProfileImageRecognition,
              modelId: _imageRecognitionModelId,
              filter: (m) => m.inputModalities.contains(Modality.image),
              onModelSelected: (id) =>
                  setState(() => _imageRecognitionModelId = id),
            ),
            const SizedBox(height: 16),

            // Transcription model (optional)
            _ModelSlotField(
              label: context.messages.inferenceProfileTranscription,
              modelId: _transcriptionModelId,
              filter: (m) => m.inputModalities.contains(Modality.audio),
              onModelSelected: (id) =>
                  setState(() => _transcriptionModelId = id),
            ),
            const SizedBox(height: 16),

            // Image generation model (optional)
            _ModelSlotField(
              label: context.messages.inferenceProfileImageGeneration,
              modelId: _imageGenerationModelId,
              filter: (m) => m.outputModalities.contains(Modality.image),
              onModelSelected: (id) =>
                  setState(() => _imageGenerationModelId = id),
            ),
            const SizedBox(height: 24),

            // Desktop only toggle
            SwitchListTile(
              title: Text(context.messages.inferenceProfileDesktopOnly),
              subtitle: Text(
                context.messages.inferenceProfileDesktopOnlyDescription,
              ),
              value: _desktopOnly,
              onChanged: (value) => setState(() => _desktopOnly = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_thinkingModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.inferenceProfileThinkingRequired),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final profile = AiConfig.inferenceProfile(
        id: widget.existingProfile?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        thinkingModelId: _thinkingModelId!,
        imageRecognitionModelId: _imageRecognitionModelId,
        transcriptionModelId: _transcriptionModelId,
        imageGenerationModelId: _imageGenerationModelId,
        desktopOnly: _desktopOnly,
        isDefault: widget.existingProfile?.isDefault ?? false,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        createdAt: widget.existingProfile?.createdAt ?? now,
        updatedAt: now,
      ) as AiConfigInferenceProfile;

      await ref
          .read(inferenceProfileControllerProvider.notifier)
          .saveProfile(profile);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.commonError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

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

    final selectedModel = modelId != null
        ? allModels.where((m) => m.providerModelId == modelId).firstOrNull
        : null;

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

class _SlotModelPickerContent extends StatelessWidget {
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

  String? _providerName(String providerId) {
    return providers
        .where((p) => p.id == providerId)
        .map((p) => p.name)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: models.map((model) {
          final providerLabel = _providerName(model.inferenceProviderId);
          final subtitle = [
            if (providerLabel != null) providerLabel,
            model.providerModelId,
          ].join(' — ');
          final isSelected = model.providerModelId == selectedModelId;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: isSelected
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelected(model.providerModelId),
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
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
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
        }).toList(),
      ),
    );
  }
}
