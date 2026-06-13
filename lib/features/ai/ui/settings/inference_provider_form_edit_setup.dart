import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_result_modal.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/themes/theme.dart';

/// Section for manually triggering AI setup (models, prompts, category).
class AiSetupSection extends ConsumerStatefulWidget {
  const AiSetupSection({
    required this.providerId,
    required this.providerType,
    super.key,
  });

  final String providerId;
  final InferenceProviderType providerType;

  @override
  ConsumerState<AiSetupSection> createState() => _AiSetupSectionState();
}

class _AiSetupSectionState extends ConsumerState<AiSetupSection> {
  bool _isRunning = false;

  /// Resolves the user-facing provider name through `aiProviderDisplayName`
  /// so the FTUE workflow surfaces use the localised brand name (e.g.
  /// "Google Gemini") and not the English-only `ftueDisplayName` constant.
  String _providerName(BuildContext context) => aiProviderDisplayName(
    type: widget.providerType,
    messages: context.messages,
  );

  Future<void> _runFtueSetup() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final setupService = ref.read(providerPromptSetupServiceProvider);

      // Get the provider config
      final config = await repository.getConfigById(widget.providerId);
      if (config == null || config is! AiConfigInferenceProvider) {
        return;
      }

      if (!mounted) return;

      final action = await performFtueSetupWorkflow(
        context: context,
        ref: ref,
        // Drive the wizard from the persisted config's provider type (not the
        // editable form state) so a type/config mismatch can't seed the wrong
        // setup artifacts when the form was changed without saving.
        providerType: config.inferenceProviderType,
        config: config,
        setupService: setupService,
        providerName: aiProviderDisplayName(
          type: config.inferenceProviderType,
          messages: context.messages,
        ),
        isMounted: () => mounted,
      );

      // "Start using AI" exits the setup flow — pop the edit page so the
      // user lands back at the settings list instead of staring at the
      // provider form they just re-ran the wizard from.
      if (action == AiProviderSetupResultAction.startUsingAi && mounted) {
        await popAiSettingsDetail(context);
      }
    } catch (error, stackTrace) {
      // Mirror the save path (see handleSave in inference_provider_edit_page):
      // forward the failure to the logging service and surface a toast instead
      // of letting repository/workflow exceptions escape the button callback.
      try {
        getIt<DomainLogger>().error(
          LogDomain.ai,
          error,
          stackTrace: stackTrace,
          subDomain: 'INFERENCE_PROVIDER_EDIT_PAGE.runFtueSetup',
        );
      } catch (_) {
        // LoggingService not available (e.g., in tests) — ignore.
      }
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: tokens.spacing.step7),
        AiFormSection(
          title: messages.aiSetupWizardTitle,
          icon: Icons.auto_awesome_rounded,
          description: messages.aiSetupWizardDescription(
            _providerName(context),
          ),
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacing.step5),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(tokens.radii.m),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(tokens.spacing.step3),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(tokens.radii.s),
                        ),
                        child: Icon(
                          Icons.settings_suggest_rounded,
                          color: context.colorScheme.primary,
                          size: tokens.spacing.step6,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              messages.aiSetupWizardRunLabel,
                              style: tokens.typography.styles.subtitle.subtitle2
                                  .copyWith(
                                    color: context.colorScheme.onSurface,
                                    fontWeight:
                                        tokens.typography.weight.semiBold,
                                  ),
                            ),
                            SizedBox(height: tokens.spacing.step1),
                            Text(
                              messages.aiSetupWizardCreatesOptimized,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  // Info about idempotency
                  Container(
                    padding: EdgeInsets.all(tokens.spacing.step4),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(tokens.radii.s),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: tokens.spacing.step5,
                          color: context.colorScheme.primary,
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(
                          child: Text(
                            messages.aiSetupWizardSafeToRunMultiple,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: context.colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  // Run button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isRunning ? null : _runFtueSetup,
                      icon: _isRunning
                          ? SizedBox(
                              width: tokens.spacing.step5,
                              height: tokens.spacing.step5,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              size: tokens.spacing.step5,
                            ),
                      label: Text(
                        _isRunning
                            ? messages.aiSetupWizardRunningButton
                            : messages.aiSetupWizardRunButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small chip showing modality info.
class ModalityChip extends StatelessWidget {
  const ModalityChip({
    required this.label,
    required this.icon,
    super.key,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tokens.spacing.step4,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
