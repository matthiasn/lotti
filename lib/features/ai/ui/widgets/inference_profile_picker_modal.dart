import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Shared inference-profile picker used by settings forms and agent flows.
///
/// The modal returns the selected profile id. Callers decide whether that
/// selection updates a draft, advances a wizard, or persists immediately.
abstract final class InferenceProfilePickerModal {
  static Future<String?> show({
    required BuildContext context,
    required List<AiConfigInferenceProfile> profiles,
    required String? selectedProfileId,
    String? title,
  }) {
    if (profiles.isEmpty) return Future<String?>.value();

    return ModalUtils.showSinglePageModal<String>(
      context: context,
      title: title ?? context.messages.inferenceProfileChooseTitle,
      padding: EdgeInsets.zero,
      builder: (modalContext) => InferenceProfilePickerList(
        profiles: profiles,
        selectedProfileId: selectedProfileId,
        onSelected: (id) => Navigator.of(modalContext).pop(id),
      ),
    );
  }
}

/// Full-bleed profile list shared by standalone pickers and wizard pages.
class InferenceProfilePickerList extends StatelessWidget {
  const InferenceProfilePickerList({
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
    this.emptyLabel,
    super.key,
  });

  final List<AiConfigInferenceProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (profiles.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Center(
          child: Text(
            emptyLabel ?? context.messages.inferenceProfilesEmpty,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final profile in profiles)
            _InferenceProfileRow(
              profile: profile,
              selected: profile.id == selectedProfileId,
              onTap: () => onSelected(profile.id),
            ),
        ],
      ),
    );
  }
}

class _InferenceProfileRow extends StatelessWidget {
  const _InferenceProfileRow({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final AiConfigInferenceProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final description = profile.description?.trim();
    final desktopOnlyLabel = context.messages.inferenceProfileDesktopOnly;
    final selectedLabel = context.messages.designSystemSelectedLabel;
    final semanticsParts = <String>[
      profile.name,
      if (description != null && description.isNotEmpty) description,
      if (profile.desktopOnly) desktopOnlyLabel,
    ];

    return DesignSystemSelectionRow(
      key: ValueKey(profile.id),
      title: profile.name,
      subtitle: description == null || description.isEmpty ? null : description,
      type: DesignSystemSelectionRowType.singleSelect,
      selected: selected,
      selectedLabel: selectedLabel,
      leading: Icon(
        Icons.account_tree_outlined,
        color: tokens.colors.text.mediumEmphasis,
        size: tokens.spacing.step6,
      ),
      trailing: profile.desktopOnly
          ? Tooltip(
              message: desktopOnlyLabel,
              child: Icon(
                Icons.desktop_windows_outlined,
                color: tokens.colors.text.mediumEmphasis,
                size: tokens.spacing.step5,
              ),
            )
          : null,
      semanticLabel: semanticsParts.join(', '),
      onTap: onTap,
    );
  }
}
