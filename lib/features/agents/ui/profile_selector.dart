import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/ui/widgets/inference_profile_picker_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Inference profiles usable on this platform: `desktopOnly` profiles are
/// filtered out on non-desktop platforms.
List<AiConfigInferenceProfile> _platformProfiles(
  AsyncValue<List<AiConfig>> profilesAsync,
) {
  // Keep the last loaded profiles during background reloads (valueOrNull
  // retains data across loading/error) so the pickers don't flash empty.
  final profiles = (profilesAsync.value ?? const <AiConfig>[])
      .whereType<AiConfigInferenceProfile>()
      .toList();
  return isDesktop ? profiles : profiles.where((p) => !p.desktopOnly).toList();
}

/// Opens the shared profile-selection modal; selecting a profile invokes
/// [onProfileSelected] and pops the modal.
Future<void> _showProfilePicker({
  required BuildContext context,
  required List<AiConfigInferenceProfile> profiles,
  required String? selectedProfileId,
  required ValueChanged<String?> onProfileSelected,
}) async {
  final selectedId = await InferenceProfilePickerModal.show(
    context: context,
    profiles: profiles,
    selectedProfileId: selectedProfileId,
  );
  if (selectedId != null && context.mounted) {
    onProfileSelected(selectedId);
  }
}

/// Lists inference profiles for selection in agent/template contexts.
///
/// Filters out `desktopOnly` profiles on non-desktop platforms.
/// Pre-selects the given [selectedProfileId] if provided.
class ProfileSelector extends StatelessWidget {
  const ProfileSelector({
    required this.selectedProfileId,
    required this.onProfileSelected,
    this.hintText,
    super.key,
  });

  final String? selectedProfileId;
  final ValueChanged<String?> onProfileSelected;

  /// Optional hint text shown when no profile is selected. Defaults to
  /// `context.messages.inferenceProfileSelectProfile`.
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return SettingsProfilePickerField(
      selectedProfileId: selectedProfileId,
      onProfileSelected: onProfileSelected,
      hintText: hintText,
    );
  }
}

/// Settings-styled variant of [ProfileSelector] for definition editors
/// (category details): the same provider-backed selection modal, rendered
/// as a [SettingsPickerField] so it matches the design-system fields
/// around it. With no profiles available the field stays inert (tapping
/// does nothing).
class SettingsProfilePickerField extends ConsumerWidget {
  const SettingsProfilePickerField({
    required this.selectedProfileId,
    required this.onProfileSelected,
    this.hintText,
    super.key,
  });

  final String? selectedProfileId;
  final ValueChanged<String?> onProfileSelected;

  /// Optional hint text shown when no profile is selected. Defaults to
  /// `context.messages.inferenceProfileSelectProfile`.
  final String? hintText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = _platformProfiles(
      ref.watch(inferenceProfileControllerProvider),
    );

    final selected = selectedProfileId != null
        ? filtered.where((p) => p.id == selectedProfileId).firstOrNull
        : null;

    return SettingsPickerField(
      label: context.messages.agentDefaultProfileLabel,
      valueText:
          selected?.name ??
          (selectedProfileId != null
              ? context.messages.inferenceProfileUnavailable
              : null),
      hintText: hintText ?? context.messages.inferenceProfileSelectProfile,
      enabled: filtered.isNotEmpty || selectedProfileId != null,
      onClear: selectedProfileId != null ? () => onProfileSelected(null) : null,
      onTap: () {
        unawaited(
          _showProfilePicker(
            context: context,
            profiles: filtered,
            selectedProfileId: selectedProfileId,
            onProfileSelected: onProfileSelected,
          ),
        );
      },
    );
  }
}
