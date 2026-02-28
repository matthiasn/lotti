import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Record returned by the agent creation modal.
typedef AgentCreationResult = ({String templateId, String profileId});

/// Two-page modal for creating an agent:
/// Page 1 — select a template (auto-skips if only one).
/// Page 2 — select an inference profile.
class AgentCreationModal {
  /// Shows the modal and returns a [AgentCreationResult] or `null` if
  /// cancelled.
  static Future<AgentCreationResult?> show({
    required BuildContext context,
    required List<AgentTemplateEntity> templates,
  }) async {
    // If only one template, skip page 1.
    final singleTemplate = templates.length == 1 ? templates.first : null;

    final pageIndexNotifier =
        ValueNotifier<int>(singleTemplate != null ? 1 : 0);
    var selectedTemplate = singleTemplate;
    String? selectedProfileId;

    final result = await ModalUtils.showMultiPageModal<AgentCreationResult>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalContext) => [
        // Page 0: Template selection
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.agentTemplateSelectTitle,
          child: _TemplateSelectionPage(
            templates: templates,
            onTemplateSelected: (template) {
              selectedTemplate = template;
              pageIndexNotifier.value = 1;
            },
          ),
        ),
        // Page 1: Profile selection
        ModalUtils.modalSheetPage(
          context: modalContext,
          title: modalContext.messages.inferenceProfilesTitle,
          onTapBack:
              singleTemplate != null ? null : () => pageIndexNotifier.value = 0,
          child: _ProfileSelectionPage(
            onProfileSelected: (profileId) {
              selectedProfileId = profileId;
              if (selectedTemplate != null && selectedProfileId != null) {
                Navigator.of(modalContext).pop(
                  (
                    templateId: selectedTemplate!.id,
                    profileId: selectedProfileId!,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );

    return result;
  }
}

class _TemplateSelectionPage extends StatelessWidget {
  const _TemplateSelectionPage({
    required this.templates,
    required this.onTemplateSelected,
  });

  final List<AgentTemplateEntity> templates;
  final ValueChanged<AgentTemplateEntity> onTemplateSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: templates.map((template) {
        return ListTile(
          leading: Icon(
            Icons.smart_toy_outlined,
            color: context.colorScheme.primary,
          ),
          title: Text(template.displayName),
          subtitle: Text(template.modelId),
          onTap: () => onTemplateSelected(template),
        );
      }).toList(),
    );
  }
}

class _ProfileSelectionPage extends ConsumerWidget {
  const _ProfileSelectionPage({
    required this.onProfileSelected,
  });

  final ValueChanged<String> onProfileSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);

    return switch (profilesAsync) {
      AsyncData(:final value) => _buildProfileList(context, value),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError() => Center(child: Text(context.messages.commonError)),
    };
  }

  Widget _buildProfileList(BuildContext context, List<AiConfig> configs) {
    final profiles = configs.whereType<AiConfigInferenceProfile>().toList();
    // Filter desktop-only on mobile.
    final filtered =
        isDesktop ? profiles : profiles.where((p) => !p.desktopOnly).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          context.messages.inferenceProfilesEmpty,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: filtered.map((profile) {
        return ListTile(
          leading: Icon(
            Icons.tune,
            color: context.colorScheme.primary,
          ),
          title: Text(profile.name),
          subtitle: Text(profile.thinkingModelId),
          trailing: profile.desktopOnly
              ? Icon(
                  Icons.desktop_windows_outlined,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant,
                )
              : null,
          onTap: () => onProfileSelected(profile.id),
        );
      }).toList(),
    );
  }
}
