import 'package:flutter/material.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ConnectionSection extends StatelessWidget {
  const ConnectionSection({
    required this.provider,
    required this.onEdit,
    super.key,
  });

  final AiConfigInferenceProvider provider;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final requiresKey = !ProviderConfig.noApiKeyRequired.contains(
      provider.inferenceProviderType,
    );
    final usesBaseUrl = ProviderConfig.usesBaseUrl(
      provider.inferenceProviderType,
    );
    final rows = <_ConnectionRow>[
      if (requiresKey)
        _ConnectionRow(
          label: messages.aiProviderDetailApiKeyLabel,
          value: maskApiKey(provider.apiKey),
          isMissing: provider.apiKey.trim().isEmpty,
        ),
      if (usesBaseUrl)
        _ConnectionRow(
          label: messages.aiProviderDetailBaseUrlLabel,
          value: provider.baseUrl.isEmpty
              ? messages.aiProviderDetailValueUnset
              : provider.baseUrl,
          isMissing: provider.baseUrl.trim().isEmpty,
        ),
      _ConnectionRow(
        label: messages.aiProviderDetailDisplayNameLabel,
        value: provider.name.isEmpty
            ? messages.aiProviderDetailValueUnset
            : provider.name,
        isMissing: provider.name.trim().isEmpty,
      ),
    ];

    return Section(
      title: messages.aiProviderDetailConnectionTitle,
      trailing: DesignSystemButton(
        label: messages.aiProviderDetailEditButton,
        variant: DesignSystemButtonVariant.secondary,
        leadingIcon: Icons.edit_outlined,
        onPressed: onEdit,
      ),
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: tokens.spacing.step3),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Masks an API key down to its trailing four characters. Returns an
/// empty string when the trimmed key is empty — [_ConnectionRow] then
/// substitutes the localized "Not set" placeholder.
@visibleForTesting
String maskApiKey(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length <= 4) return '•' * trimmed.length;
  final visible = trimmed.substring(trimmed.length - 4);
  return '•••• $visible';
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.label,
    required this.value,
    required this.isMissing,
  });

  final String label;
  final String value;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final shown = value.isEmpty ? messages.aiProviderDetailValueUnset : value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            shown,
            // "Not set" placeholders stay in the regular bodySmall sans
            // style (warning-tinted); resolved values route through the
            // DS mono helper so the surface stops re-inventing the
            // `fontFamily: 'Inconsolata'` override at the call site.
            style: isMissing
                ? tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.warning.defaultColor,
                  )
                : monoMetaStyle(
                    tokens,
                    tokens.colors,
                    base: tokens.typography.styles.body.bodySmall,
                    color: tokens.colors.text.highEmphasis,
                  ),
          ),
        ),
      ],
    );
  }
}
