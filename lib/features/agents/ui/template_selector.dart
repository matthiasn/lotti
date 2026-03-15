import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';

/// Lists task-agent templates for selection in category default contexts.
///
/// Filters to only [AgentTemplateKind.taskAgent] templates.
/// Pre-selects the given [selectedTemplateId] if provided.
class TemplateSelector extends ConsumerWidget {
  const TemplateSelector({
    required this.selectedTemplateId,
    required this.onTemplateSelected,
    super.key,
  });

  final String? selectedTemplateId;
  final ValueChanged<String?> onTemplateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(agentTemplatesProvider);

    final templates = switch (templatesAsync) {
      AsyncData(:final value) =>
        value
            .whereType<AgentTemplateEntity>()
            .where((t) => t.kind == AgentTemplateKind.taskAgent)
            .toList(),
      _ => <AgentTemplateEntity>[],
    };

    final selected = selectedTemplateId != null
        ? templates.where((t) => t.id == selectedTemplateId).firstOrNull
        : null;

    return InkWell(
      onTap: templates.isNotEmpty
          ? () => _showTemplatePicker(context, templates)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.categoryDefaultTemplateLabel,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedTemplateId != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onTemplateSelected(null),
                ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          enabled: templates.isNotEmpty,
        ),
        child: selected != null
            ? Text(
                selected.displayName,
                style: context.textTheme.bodyLarge,
              )
            : Text(
                context.messages.categoryDefaultTemplateHint,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }

  void _showTemplatePicker(
    BuildContext context,
    List<AgentTemplateEntity> templates,
  ) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.categoryDefaultTemplateLabel,
      child: _TemplatePickerContent(
        templates: templates,
        selectedTemplateId: selectedTemplateId,
        onSelected: (id) {
          onTemplateSelected(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _TemplatePickerContent extends StatelessWidget {
  const _TemplatePickerContent({
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final List<AgentTemplateEntity> templates;
  final String? selectedTemplateId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: templates.map((template) {
          final isSelected = template.id == selectedTemplateId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: isSelected
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelected(template.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 20,
                        color: isSelected
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          template.displayName,
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurface,
                          ),
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
