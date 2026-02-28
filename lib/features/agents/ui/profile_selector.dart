import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';

/// Lists inference profiles for selection in agent/template contexts.
///
/// Filters out `desktopOnly` profiles on non-desktop platforms.
/// Pre-selects the given [selectedProfileId] if provided.
class ProfileSelector extends ConsumerWidget {
  const ProfileSelector({
    required this.selectedProfileId,
    required this.onProfileSelected,
    super.key,
  });

  final String? selectedProfileId;
  final ValueChanged<String?> onProfileSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);

    final profiles = switch (profilesAsync) {
      AsyncData(:final value) =>
        value.whereType<AiConfigInferenceProfile>().toList(),
      _ => <AiConfigInferenceProfile>[],
    };

    // Filter desktop-only on mobile.
    final filtered =
        isDesktop ? profiles : profiles.where((p) => !p.desktopOnly).toList();

    final selected = selectedProfileId != null
        ? filtered.where((p) => p.id == selectedProfileId).firstOrNull
        : null;

    return InkWell(
      onTap: filtered.isNotEmpty
          ? () => _showProfilePicker(context, filtered)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.inferenceProfilesTitle,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedProfileId != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onProfileSelected(null),
                ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          enabled: filtered.isNotEmpty,
        ),
        child: selected != null
            ? Text(
                selected.name,
                style: context.textTheme.bodyLarge,
              )
            : Text(
                context.messages.inferenceProfileSelectModel,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }

  void _showProfilePicker(
    BuildContext context,
    List<AiConfigInferenceProfile> profiles,
  ) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.inferenceProfilesTitle,
      child: _ProfilePickerContent(
        profiles: profiles,
        selectedProfileId: selectedProfileId,
        onSelected: (id) {
          onProfileSelected(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _ProfilePickerContent extends StatelessWidget {
  const _ProfilePickerContent({
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
  });

  final List<AiConfigInferenceProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: profiles.map((profile) {
          final isSelected = profile.id == selectedProfileId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: isSelected
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelected(profile.id),
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
                              profile.name,
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
                              profile.thinkingModelId,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (profile.desktopOnly)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.desktop_windows_outlined,
                            size: 16,
                            color: context.colorScheme.onSurfaceVariant,
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
