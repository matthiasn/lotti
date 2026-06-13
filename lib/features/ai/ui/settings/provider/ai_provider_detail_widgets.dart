import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_connection_section.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_models_section.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

class DetailBody extends StatelessWidget {
  const DetailBody({
    required this.provider,
    required this.models,
    required this.allModels,
    required this.activeProfile,
    required this.onAddModel,
    required this.onEdit,
    required this.onModelTap,
    required this.onProfileTap,
    required this.onRemove,
    super.key,
  });

  final AiConfigInferenceProvider provider;
  final List<AiConfigModel> models;
  final List<AiConfigModel> allModels;
  final AiConfigInferenceProfile? activeProfile;
  final VoidCallback onAddModel;
  final VoidCallback onEdit;
  final ValueChanged<AiConfigModel> onModelTap;
  final ValueChanged<AiConfigInferenceProfile> onProfileTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Pad the bottom by the height the app's bottom nav bar occupies
    // (zero on desktop, ~88pt on mobile with the home indicator) plus
    // the page's normal step6 gap, so the danger-zone card always
    // clears the nav bar on mobile instead of slipping behind it.
    final bottomInset = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step6 + bottomInset,
      ),
      children: [
        _HeaderStrip(provider: provider, modelCount: models.length),
        SizedBox(height: tokens.spacing.step5),
        ConnectionSection(provider: provider, onEdit: onEdit),
        SizedBox(height: tokens.spacing.step6),
        ModelsSection(
          provider: provider,
          models: models,
          onAddModel: onAddModel,
          onModelTap: onModelTap,
        ),
        SizedBox(height: tokens.spacing.step6),
        if (activeProfile != null)
          ActiveProfileSection(
            profile: activeProfile!,
            providerType: provider.inferenceProviderType,
            models: allModels,
            onProfileTap: onProfileTap,
          ),
        if (activeProfile != null) SizedBox(height: tokens.spacing.step6),
        _DangerZoneSection(onRemove: onRemove),
      ],
    );
  }
}

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.provider, required this.modelCount});

  final AiConfigInferenceProvider provider;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: provider.inferenceProviderType,
      tokens: tokens,
      messages: messages,
    );
    final status = AiProviderCard.statusFor(
      provider: provider,
      modelCount: modelCount,
    );
    final displayName = provider.name.isNotEmpty
        ? provider.name
        : visual.displayName;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.surface,
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(
              aiProviderIcon(provider.inferenceProviderType),
              size: tokens.spacing.step6,
              color: visual.accent,
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                              fontWeight: tokens.typography.weight.semiBold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isProviderDraft(provider)) ...[
                      SizedBox(width: tokens.spacing.step3),
                      DesignSystemBadge.outlined(
                        label: messages.aiProviderCardDraftBadge,
                        tone: DesignSystemBadgeTone.secondary,
                      ),
                    ],
                  ],
                ),
                if (visual.tagline.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    visual.tagline,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step3),
                _StatusPill(status: status, modelCount: modelCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.modelCount});

  final AiProviderCardStatus status;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final (dotColor, label, textColor) = switch (status) {
      AiProviderCardStatus.connected => (
        tokens.colors.alert.success.defaultColor,
        messages.aiProviderCardModelCount(modelCount),
        tokens.colors.text.highEmphasis,
      ),
      AiProviderCardStatus.invalidKey => (
        tokens.colors.alert.error.defaultColor,
        messages.aiProviderCardStatusInvalidKey,
        tokens.colors.alert.error.defaultColor,
      ),
      AiProviderCardStatus.offline => (
        tokens.colors.text.lowEmphasis,
        messages.aiProviderCardOllamaHint,
        tokens.colors.text.highEmphasis,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: textColor,
              fontWeight: tokens.typography.weight.semiBold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DangerZoneSection extends StatelessWidget {
  const _DangerZoneSection({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Section(
      title: messages.aiProviderDetailDangerZoneTitle,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: tokens.colors.alert.error.defaultColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(
            color: tokens.colors.alert.error.defaultColor.withValues(
              alpha: 0.18,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messages.aiProviderDetailRemoveTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    messages.aiProviderDetailRemoveDescription,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step4),
            DesignSystemButton(
              label: messages.aiProviderDetailRemoveButton,
              variant: DesignSystemButtonVariant.dangerSecondary,
              leadingIcon: Icons.delete_outline_rounded,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class Section extends StatelessWidget {
  const Section({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        child,
      ],
    );
  }
}

class EmptySectionCard extends StatelessWidget {
  const EmptySectionCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step6,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
