import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/ui/widgets/inference_profile_picker_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    if (templates.isEmpty) return null;

    // If only one template, skip page 1.
    final singleTemplate = templates.length == 1 ? templates.first : null;

    final pageIndexNotifier = ValueNotifier<int>(
      singleTemplate != null ? 1 : 0,
    );
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
          padding: const EdgeInsets.symmetric(vertical: 20),
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
          title: modalContext.messages.inferenceProfileChooseTitle,
          padding: const EdgeInsets.symmetric(vertical: 20),
          onTapBack: singleTemplate != null
              ? null
              : () => pageIndexNotifier.value = 0,
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

class _TemplateSelectionPage extends StatefulWidget {
  const _TemplateSelectionPage({
    required this.templates,
    required this.onTemplateSelected,
  });

  final List<AgentTemplateEntity> templates;
  final ValueChanged<AgentTemplateEntity> onTemplateSelected;

  @override
  State<_TemplateSelectionPage> createState() => _TemplateSelectionPageState();
}

class _TemplateSelectionPageState extends State<_TemplateSelectionPage> {
  String? _hoveredId;

  @override
  void didUpdateWidget(covariant _TemplateSelectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hoveredId != null &&
        !widget.templates.any((t) => t.id == _hoveredId)) {
      _hoveredId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final templates = widget.templates;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, template) in templates.indexed)
            DesignSystemListItem(
              key: ValueKey(template.id),
              title: template.displayName,
              subtitle: _templateKindLabel(context, template.kind),
              leading: Icon(
                Icons.smart_toy_outlined,
                size: 20,
                color: tokens.colors.interactive.enabled,
              ),
              showDivider: index < templates.length - 1,
              dividerColor:
                  index < templates.length - 1 &&
                      (_hoveredId == template.id ||
                          _hoveredId == templates[index + 1].id)
                  ? Colors.transparent
                  : null,
              onTap: () => widget.onTemplateSelected(template),
              onHoverChanged: (hovered) {
                setState(() {
                  if (hovered) {
                    _hoveredId = template.id;
                  } else if (_hoveredId == template.id) {
                    _hoveredId = null;
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  String _templateKindLabel(BuildContext context, AgentTemplateKind kind) {
    return switch (kind) {
      AgentTemplateKind.taskAgent =>
        context.messages.agentTemplateKindTaskAgent,
      AgentTemplateKind.dayAgent => context.messages.agentTemplateKindDayAgent,
      AgentTemplateKind.templateImprover =>
        context.messages.agentTemplateKindImprover,
      AgentTemplateKind.projectAgent =>
        context.messages.agentTemplateKindProjectAgent,
      AgentTemplateKind.eventAgent =>
        context.messages.agentTemplateKindEventAgent,
    };
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
    final profiles = (profilesAsync.value ?? const <AiConfig>[])
        .whereType<AiConfigInferenceProfile>()
        .where((profile) => isDesktop || !profile.desktopOnly)
        .toList();

    if (profiles.isNotEmpty || profilesAsync.hasValue) {
      return InferenceProfilePickerList(
        profiles: profiles,
        selectedProfileId: null,
        onSelected: onProfileSelected,
      );
    }
    if (profilesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: Text(context.messages.commonError));
  }
}
