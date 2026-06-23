import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_slot_field.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/features/ai/ui/widgets/profile_pinning_selector.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/ai/ui/inference_profile_detail_page.dart';

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
  String? _thinkingHighEndModelId;
  String? _imageRecognitionModelId;
  String? _transcriptionModelId;
  String? _imageGenerationModelId;
  bool _desktopOnly = false;
  String? _pinnedHostId;
  late List<SkillAssignment> _skillAssignments;
  bool _isSaving = false;

  bool get _isEditing => widget.existingProfile != null;

  // Rebuild so the Save button re-evaluates its dirty state as the user types.
  // (Model-slot / toggle changes already setState through their own callbacks.)
  void _onFieldChanged() => setState(() {});

  /// Whether the form differs from the profile it loaded — or, when creating,
  /// whether the user has entered anything worth saving. Drives the Save
  /// button's quiet→active state, mirroring the note editor's toolbar Save
  /// ("non-active is not primary, on when dirty").
  bool get _isDirty {
    final p = widget.existingProfile;
    if (p == null) {
      return _nameController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty ||
          _thinkingModelId != null;
    }
    return _nameController.text != p.name ||
        _descriptionController.text != (p.description ?? '') ||
        _thinkingModelId != p.thinkingModelId ||
        _thinkingHighEndModelId != p.thinkingHighEndModelId ||
        _imageRecognitionModelId != p.imageRecognitionModelId ||
        _transcriptionModelId != p.transcriptionModelId ||
        _imageGenerationModelId != p.imageGenerationModelId ||
        _desktopOnly != p.desktopOnly ||
        _pinnedHostId != p.pinnedHostId ||
        !listEquals(_skillAssignments, p.skillAssignments);
  }

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
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
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
          // Save mirrors the note editor's toolbar Save: a primary
          // design-system button that stays quiet/disabled until the form is
          // dirty, then wakes to the teal accent. `_save` still validates
          // (name + thinking model) and surfaces inline / toast errors on tap.
          DesignSystemButton(
            label: messages.inferenceProfileSaveButton,
            leadingIcon: Icons.save_rounded,
            onPressed: _isDirty && !_isSaving ? _save : null,
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
            ModelSlotField(
              label: context.messages.inferenceProfileThinking,
              modelId: _thinkingModelId,
              required: true,
              filter: (m) => m.supportsFunctionCalling,
              onModelSelected: (id) => setState(() => _thinkingModelId = id),
            ),
            const SizedBox(height: 16),

            // High-end thinking model (optional)
            ModelSlotField(
              label: context.messages.inferenceProfileThinkingHighEnd,
              modelId: _thinkingHighEndModelId,
              filter: (m) => m.inputModalities.contains(Modality.text),
              onModelSelected: (id) =>
                  setState(() => _thinkingHighEndModelId = id),
            ),
            const SizedBox(height: 16),

            // Image recognition model (optional)
            ModelSlotField(
              label: context.messages.inferenceProfileImageRecognition,
              modelId: _imageRecognitionModelId,
              filter: (m) => m.inputModalities.contains(Modality.image),
              onModelSelected: (id) =>
                  setState(() => _imageRecognitionModelId = id),
            ),
            const SizedBox(height: 16),

            // Transcription model (optional)
            ModelSlotField(
              label: context.messages.inferenceProfileTranscription,
              modelId: _transcriptionModelId,
              filter: (m) => m.inputModalities.contains(Modality.audio),
              onModelSelected: (id) =>
                  setState(() => _transcriptionModelId = id),
            ),
            const SizedBox(height: 16),

            // Image generation model (optional)
            ModelSlotField(
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
  /// Takes the *normalized* slot values being persisted (not the raw form
  /// state) so a slot cleared during save — e.g. an ambiguous legacy id —
  /// also disables its dependent skill automation.
  ///
  /// Note: only checks built-in skills — custom/future skills pass through
  /// unchanged. Extend this when custom skill editing is added.
  List<SkillAssignment> _sanitizedSkillAssignments({
    required String? transcriptionModelId,
    required String? imageRecognitionModelId,
  }) {
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
      final hasModel = switch (skill.skillType) {
        SkillType.transcription => transcriptionModelId != null,
        SkillType.imageAnalysis => imageRecognitionModelId != null,
        _ => false,
      };
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
      final repository = ref.read(aiConfigRepositoryProvider);
      final modelConfigs = await repository.getConfigsByType(
        AiConfigType.model,
      );
      final models = modelConfigs.whereType<AiConfigModel>().toList(
        growable: false,
      );
      final thinkingModelId = _normalizeModelSlotId(
        _thinkingModelId,
        models,
      );
      final thinkingHighEndModelId = _normalizeModelSlotId(
        _thinkingHighEndModelId,
        models,
      );
      final imageRecognitionModelId = _normalizeModelSlotId(
        _imageRecognitionModelId,
        models,
      );
      final transcriptionModelId = _normalizeModelSlotId(
        _transcriptionModelId,
        models,
      );
      final imageGenerationModelId = _normalizeModelSlotId(
        _imageGenerationModelId,
        models,
      );
      // An ambiguous legacy id normalizes to null; the thinking slot is
      // required, so force an explicit re-selection instead of persisting
      // an arbitrary or unresolved value.
      if (thinkingModelId == null) {
        if (mounted) {
          setState(() => _thinkingModelId = null);
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.inferenceProfileThinkingRequired,
          );
        }
        return;
      }
      final profile =
          AiConfig.inferenceProfile(
                id: widget.existingProfile?.id ?? const Uuid().v4(),
                name: _nameController.text.trim(),
                thinkingModelId: thinkingModelId,
                thinkingHighEndModelId: thinkingHighEndModelId,
                imageRecognitionModelId: imageRecognitionModelId,
                transcriptionModelId: transcriptionModelId,
                imageGenerationModelId: imageGenerationModelId,
                desktopOnly: _desktopOnly,
                skillAssignments: _sanitizedSkillAssignments(
                  transcriptionModelId: transcriptionModelId,
                  imageRecognitionModelId: imageRecognitionModelId,
                ),
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

/// Resolves a slot value to the model row it identifies: an exact
/// [AiConfigModel.id] match first, then a unique legacy `providerModelId`
/// fallback. Ambiguous (2+ rows sharing the legacy id) or unknown values
/// return `null` so the UI never shows an arbitrary row as selected.
AiConfigModel? resolveModelSlot(
  String? slotValue,
  List<AiConfigModel> models,
) {
  if (slotValue == null) return null;
  final exact = models.where((model) => model.id == slotValue).firstOrNull;
  if (exact != null) return exact;

  final matches = models
      .where((model) => model.providerModelId == slotValue)
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

/// Maps a slot value to the canonical [AiConfigModel.id] for persistence,
/// using the same resolution rule as [resolveModelSlot]:
///
/// - exact model-row id match → kept as-is
/// - unique legacy `providerModelId` match → normalized to that row's id
/// - ambiguous legacy id (2+ rows) → `null`, forcing re-selection so an
///   arbitrary row is never silently persisted
/// - no match → kept as-is (the model row may not have synced yet)
String? _normalizeModelSlotId(String? slotValue, List<AiConfigModel> models) {
  if (slotValue == null) return null;
  final resolved = resolveModelSlot(slotValue, models);
  if (resolved != null) return resolved.id;

  final isAmbiguous =
      models.where((model) => model.providerModelId == slotValue).length > 1;
  return isAmbiguous ? null : slotValue;
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
