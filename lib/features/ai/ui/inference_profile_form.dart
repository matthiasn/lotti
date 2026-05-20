import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/features/ai/ui/widgets/profile_pinning_selector.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
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

/// URL-route entry point for the inference profile edit flow.
///
/// `InferenceProfileForm` takes a fully-resolved [AiConfigInferenceProfile]
/// because the legacy `Navigator.push` callers had the config in hand at
/// the call site. URL-based routing (the Settings V2 master/detail panel
/// + the Beamer mobile stack) only carries the profile id, so this
/// wrapper resolves the id via Riverpod and hands the loaded config
/// down. Mirrors how `InferenceModelEditPage` already supports id-only
/// construction; kept as a separate page class so the form's existing
/// `existingProfile`-taking constructor stays unchanged.
class InferenceProfileDetailPage extends ConsumerWidget {
  const InferenceProfileDetailPage({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(aiConfigByIdProvider(profileId));
    return configAsync.when(
      data: (config) {
        if (config is! AiConfigInferenceProfile) {
          return Scaffold(
            body: Center(
              child: Text(context.messages.inferenceProfileDetailNotFound),
            ),
          );
        }
        return InferenceProfileForm(existingProfile: config);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text(
            context.messages.inferenceProfileDetailLoadError(error.toString()),
          ),
        ),
      ),
    );
  }
}

class _InferenceProfileFormState extends ConsumerState<InferenceProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String? _thinkingModelId;
  String? _thinkingHighEndModelId;
  String? _imageRecognitionModelId;
  String? _transcriptionModelId;
  String? _imageGenerationModelId;
  bool _desktopOnly = false;
  String? _pinnedHostId;
  late List<SkillAssignment> _skillAssignments;
  bool _isSaving = false;

  bool get _isEditing => widget.existingProfile != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _thinkingModelId = p?.thinkingModelId;
    _thinkingHighEndModelId = p?.thinkingHighEndModelId;
    _imageRecognitionModelId = p?.imageRecognitionModelId;
    _transcriptionModelId = p?.transcriptionModelId;
    _imageGenerationModelId = p?.imageGenerationModelId;
    _pinnedHostId = p?.pinnedHostId;
    _desktopOnly = p?.desktopOnly ?? false;
    _skillAssignments = List.of(p?.skillAssignments ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Explicit `leading` so the back arrow routes through
        // `popAiSettingsDetail` instead of Material's default
        // `Navigator.maybePop()`. On the desktop master/detail
        // surface this page lives inside the panel slot and isn't on
        // the Navigator stack, so the default arrow would silently
        // no-op — the helper falls back to beaming `/settings/ai`.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // Overriding `leading` drops the AppBar's default
          // Material-localized tooltip; re-supply it so screen
          // readers and long-press hover hints stay parity-clean
          // with the other AI-settings detail pages.
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => popAiSettingsDetail(context),
        ),
        title: Text(
          _isEditing
              ? messages.inferenceProfileEditTitle
              : messages.inferenceProfileCreateTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(messages.inferenceProfileSaveButton),
          ),
          SizedBox(width: tokens.spacing.step2),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Pad the bottom by the height the app's bottom nav bar
          // occupies (zero on desktop, ~88pt on mobile with the home
          // indicator) plus the page's normal padding so the last
          // form section always clears the nav bar on mobile instead
          // of slipping behind it.
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5 +
                DesignSystemBottomNavigationBar.occupiedHeight(context),
          ),
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

            // High-end thinking model (optional)
            _ModelSlotField(
              label: context.messages.inferenceProfileThinkingHighEnd,
              modelId: _thinkingHighEndModelId,
              filter: (m) => m.inputModalities.contains(Modality.text),
              onModelSelected: (id) =>
                  setState(() => _thinkingHighEndModelId = id),
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
            const SizedBox(height: 24),

            // Pinning: which device should auto-trigger this profile on
            // inbound synced audio?
            ProfilePinningSelector(
              pinnedHostId: _pinnedHostId,
              referencedModelIds: <String>{
                ?_thinkingModelId,
                ?_thinkingHighEndModelId,
                ?_imageRecognitionModelId,
                ?_transcriptionModelId,
                ?_imageGenerationModelId,
              },
              onChanged: (value) => setState(() => _pinnedHostId = value),
            ),
            const SizedBox(height: 24),

            // Automated skills section
            Text(
              context.messages.inferenceProfileSkillsSection,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...builtInSkills
                .where(
                  (s) =>
                      s.skillType == SkillType.transcription ||
                      s.skillType == SkillType.imageAnalysis,
                )
                .map(
                  (skill) => _SkillAssignmentTile(
                    skill: skill,
                    modelId: _modelIdForSkillType(skill.skillType),
                    slotName: _slotNameForSkillType(skill.skillType, context),
                    isAutomated: _skillAssignments.any(
                      (a) => a.skillId == skill.id && a.automate,
                    ),
                    onChanged: (value) => _toggleSkillAssignment(
                      skill.id,
                      automate: value,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String? _modelIdForSkillType(SkillType? skillType) {
    return switch (skillType) {
      SkillType.transcription => _transcriptionModelId,
      SkillType.imageAnalysis => _imageRecognitionModelId,
      _ => null,
    };
  }

  String _slotNameForSkillType(SkillType? skillType, BuildContext context) {
    return switch (skillType) {
      SkillType.transcription => context.messages.inferenceProfileTranscription,
      SkillType.imageAnalysis =>
        context.messages.inferenceProfileImageRecognition,
      _ => '',
    };
  }

  /// Returns skill assignments with `automate` forced to `false` for any
  /// skill whose required model slot is currently empty. This prevents
  /// persisting an inconsistent state where a skill claims to be automated
  /// but the profile has no model to execute it.
  ///
  /// Note: only checks built-in skills — custom/future skills pass through
  /// unchanged. Extend this when custom skill editing is added.
  List<SkillAssignment> _sanitizedSkillAssignments() {
    // First, deduplicate legacy same-SkillType entries: keep only the last
    // assignment per SkillType so profiles migrated from older formats
    // don't persist conflicting duplicates.
    final deduped = <SkillType, SkillAssignment>{};
    final unknown = <SkillAssignment>[];
    for (final a in _skillAssignments) {
      final skill = builtInSkills.where((s) => s.id == a.skillId).firstOrNull;
      if (skill == null) {
        unknown.add(a);
      } else {
        deduped[skill.skillType] = a;
      }
    }
    final normalized = [...deduped.values, ...unknown];

    // Then, force `automate: false` for any skill whose required model slot
    // is currently empty.
    return normalized.map((a) {
      if (!a.automate) return a;
      final skill = builtInSkills.where((s) => s.id == a.skillId).firstOrNull;
      if (skill == null) return a;
      final hasModel = _modelIdForSkillType(skill.skillType) != null;
      if (hasModel) return a;
      return SkillAssignment(skillId: a.skillId);
    }).toList();
  }

  void _toggleSkillAssignment(String skillId, {required bool automate}) {
    setState(() {
      // Find the skill type for mutual exclusion.
      final toggledSkill = builtInSkills
          .where((s) => s.id == skillId)
          .firstOrNull;

      if (automate && toggledSkill != null) {
        // Remove all assignments of the same SkillType so only one
        // automated skill per capability is active at a time.
        final sameTypeIds = builtInSkills
            .where((s) => s.skillType == toggledSkill.skillType)
            .map((s) => s.id)
            .toSet();
        _skillAssignments.removeWhere(
          (a) => sameTypeIds.contains(a.skillId),
        );
      } else {
        _skillAssignments.removeWhere((a) => a.skillId == skillId);
      }

      _skillAssignments.add(
        SkillAssignment(skillId: skillId, automate: automate),
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_thinkingModelId == null) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.inferenceProfileThinkingRequired,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final profile =
          AiConfig.inferenceProfile(
                id: widget.existingProfile?.id ?? const Uuid().v4(),
                name: _nameController.text.trim(),
                thinkingModelId: _thinkingModelId!,
                thinkingHighEndModelId: _thinkingHighEndModelId,
                imageRecognitionModelId: _imageRecognitionModelId,
                transcriptionModelId: _transcriptionModelId,
                imageGenerationModelId: _imageGenerationModelId,
                desktopOnly: _desktopOnly,
                skillAssignments: _sanitizedSkillAssignments(),
                isDefault: widget.existingProfile?.isDefault ?? false,
                // The selector mutates `_pinnedHostId`; on a brand-new
                // profile this is null and the auto-trigger stays inert
                // until the user picks a device.
                pinnedHostId: _pinnedHostId,
                description: _descriptionController.text.trim().isNotEmpty
                    ? _descriptionController.text.trim()
                    : null,
                createdAt: widget.existingProfile?.createdAt ?? now,
                updatedAt: now,
              )
              as AiConfigInferenceProfile;

      await ref
          .read(inferenceProfileControllerProvider.notifier)
          .saveProfile(profile);

      if (mounted) {
        await popAiSettingsDetail(context);
      }
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

/// A toggle tile for a single skill assignment.
class _SkillAssignmentTile extends StatelessWidget {
  const _SkillAssignmentTile({
    required this.skill,
    required this.modelId,
    required this.slotName,
    required this.isAutomated,
    required this.onChanged,
  });

  final AiConfigSkill skill;
  final String? modelId;
  final String slotName;
  final bool isAutomated;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasModel = modelId != null;
    final subtitle = hasModel
        ? context.messages.inferenceProfileSkillUsesModel(slotName)
        : context.messages.inferenceProfileSkillModelRequired(slotName);

    return SwitchListTile(
      title: Text(skill.name),
      subtitle: Text(subtitle),
      value: isAutomated && hasModel,
      onChanged: hasModel ? onChanged : null,
    );
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
                selected: model.providerModelId == widget.selectedModelId,
                onTap: () => widget.onSelected(model.providerModelId),
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
