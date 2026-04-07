import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';

/// Selector for assigning a soul document to a template.
///
/// Shows the currently assigned soul (or a placeholder) and opens a
/// [SelectionModalBase] picker when tapped.
class SoulSelector extends ConsumerWidget {
  const SoulSelector({
    required this.selectedSoulId,
    required this.onSoulSelected,
    super.key,
  });

  final String? selectedSoulId;
  final ValueChanged<String?> onSoulSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soulsAsync = ref.watch(allSoulDocumentsProvider);

    final isLoading = soulsAsync.isLoading && !soulsAsync.hasValue;

    final souls = switch (soulsAsync) {
      AsyncData(:final value) => value.whereType<SoulDocumentEntity>().toList(),
      _ => <SoulDocumentEntity>[],
    };

    final selected = selectedSoulId != null
        ? souls.where((s) => s.id == selectedSoulId).firstOrNull
        : null;

    // Resolve display text: show the soul name, a loading indicator, or the
    // "none assigned" placeholder depending on state.
    final Widget displayChild;
    if (isLoading) {
      displayChild = const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (selected != null) {
      displayChild = Text(
        selected.displayName,
        style: context.textTheme.bodyLarge,
      );
    } else {
      displayChild = Text(
        context.messages.agentSoulNoneAssigned,
        style: context.textTheme.bodyLarge?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    return InkWell(
      onTap: souls.isNotEmpty ? () => _showSoulPicker(context, souls) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.agentSoulAssignmentLabel,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedSoulId != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onSoulSelected(null),
                ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          enabled: !isLoading && souls.isNotEmpty,
        ),
        child: displayChild,
      ),
    );
  }

  void _showSoulPicker(
    BuildContext context,
    List<SoulDocumentEntity> souls,
  ) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.agentSoulSelectTitle,
      child: _SoulPickerContent(
        souls: souls,
        selectedSoulId: selectedSoulId,
        onSelected: (id) {
          onSoulSelected(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _SoulPickerContent extends StatelessWidget {
  const _SoulPickerContent({
    required this.souls,
    required this.selectedSoulId,
    required this.onSelected,
  });

  final List<SoulDocumentEntity> souls;
  final String? selectedSoulId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: souls.map((soul) {
          final isSelected = soul.id == selectedSoulId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: isSelected
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelected(soul.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        size: 20,
                        color: isSelected
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          soul.displayName,
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
