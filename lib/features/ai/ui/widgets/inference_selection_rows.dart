import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shared provider drill-down row used by standalone and embedded AI pickers.
class InferenceProviderSelectionRow extends StatelessWidget {
  const InferenceProviderSelectionRow({
    required this.provider,
    required this.modelCount,
    required this.onTap,
    super.key,
  });

  final AiConfigInferenceProvider? provider;
  final int modelCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = provider?.inferenceProviderType;
    return DesignSystemSelectionRow(
      title: aiProviderDisplayName(type: type, messages: context.messages),
      subtitle: context.messages.aiModelPickerProviderModelCount(modelCount),
      type: DesignSystemSelectionRowType.navigation,
      leading: _ProviderTile(type: type),
      onTap: onTap,
    );
  }
}

/// Shared terminal model row used by standalone and embedded AI pickers.
class InferenceModelSelectionRow extends StatelessWidget {
  const InferenceModelSelectionRow({
    required this.model,
    required this.providerType,
    required this.isDefault,
    required this.isSelected,
    required this.defaultBadgeLabel,
    required this.onTap,
    super.key,
  });

  final AiConfigModel model;
  final InferenceProviderType? providerType;
  final bool isDefault;
  final bool isSelected;
  final String defaultBadgeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSelectionRow(
      title: model.name,
      subtitle: model.providerModelId.isNotEmpty ? model.providerModelId : null,
      type: DesignSystemSelectionRowType.singleSelect,
      selected: isSelected,
      selectedLabel: isDefault
          ? defaultBadgeLabel
          : context.messages.designSystemSelectedLabel,
      leading: _LeadingDot(
        color: isSelected
            ? tokens.colors.interactive.enabled
            : aiProviderAccent(type: providerType, tokens: tokens),
      ),
      trailing: isDefault && !isSelected
          ? _ModelStatusMarker(label: defaultBadgeLabel)
          : null,
      onTap: onTap,
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.type});

  final InferenceProviderType? type;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: tokens.spacing.step8,
      height: tokens.spacing.step8,
      decoration: BoxDecoration(
        color: aiProviderSurface(type: type, tokens: tokens),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Icon(
        aiProviderIcon(type),
        color: aiProviderAccent(type: type, tokens: tokens),
        size: tokens.spacing.step6,
      ),
    );
  }
}

class _LeadingDot extends StatelessWidget {
  const _LeadingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: tokens.spacing.step5,
      height: tokens.spacing.step5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ModelStatusMarker extends StatelessWidget {
  const _ModelStatusMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      label,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.interactive.enabled,
        fontWeight: tokens.typography.weight.semiBold,
      ),
    );
  }
}
