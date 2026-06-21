import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';

/// Screen 3 of the FTUE: the visually-matching, simple step that gathers just
/// the API key for the chosen provider, then creates the provider and runs the
/// existing per-provider FTUE setup natively (no detour to the plain settings
/// editor). Cloud providers show a key field + "get a key" hint; local
/// providers (Ollama) show a no-key note.
class OnboardingApiKeyPanel extends ConsumerStatefulWidget {
  const OnboardingApiKeyPanel({
    required this.type,
    required this.onBack,
    required this.onConnected,
    super.key,
  });

  final InferenceProviderType type;
  final VoidCallback onBack;
  final VoidCallback onConnected;

  @override
  ConsumerState<OnboardingApiKeyPanel> createState() =>
      _OnboardingApiKeyPanelState();
}

class _OnboardingApiKeyPanelState extends ConsumerState<OnboardingApiKeyPanel> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _requiresKey => ProviderConfig.requiresApiKey(widget.type);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final key = _controller.text.trim();
    if (_requiresKey && key.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final config =
          AiConfig.inferenceProvider(
                id: uuid.v1(),
                baseUrl: ProviderConfig.defaultBaseUrls[widget.type] ?? '',
                apiKey: key,
                name: onboardingProviderName(context.messages, widget.type),
                createdAt: DateTime.now(),
                inferenceProviderType: widget.type,
              )
              as AiConfigInferenceProvider;
      await repository.saveConfig(config);
      if (!mounted) return;
      await runFtueSetupForType(
        context: context,
        ref: ref,
        providerType: widget.type,
        config: config,
        setupService: ref.read(providerPromptSetupServiceProvider),
      );
      if (!mounted) return;
      widget.onConnected();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.messages.onboardingApiKeyError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final brand = onboardingProviderBrandColor(widget.type);
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMed = dsTokensDark.colors.text.mediumEmphasis;
    final panelBg = dsTokensDark.colors.background.level01;
    final console = aiProviderKeyConsoleUrl(widget.type);

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          const Positioned.fill(child: OnboardingBackdrop()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0),
                    panelBg.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: _busy ? null : widget.onBack,
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: textHigh,
                        size: tokens.spacing.step5,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(tokens.spacing.step3),
                      decoration: BoxDecoration(
                        color: textHigh.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(tokens.radii.m),
                      ),
                      child: Icon(aiProviderIcon(widget.type), color: brand),
                    ),
                    SizedBox(width: tokens.spacing.step4),
                    Expanded(
                      child: Text(
                        onboardingProviderName(messages, widget.type),
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(color: textHigh),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.step5),
                if (_requiresKey) ...[
                  Text(
                    messages.onboardingApiKeyTitle,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: textHigh,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_busy,
                    onSubmitted: (_) => _connect(),
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: textHigh,
                    ),
                    cursorColor: brand,
                    decoration: InputDecoration(
                      hintText: messages.onboardingApiKeyField,
                      hintStyle: tokens.typography.styles.body.bodyLarge
                          .copyWith(color: textMed),
                      filled: true,
                      fillColor: textHigh.withValues(alpha: 0.08),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.step4,
                        vertical: tokens.spacing.step3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radii.m),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (console != null)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step2),
                      child: Text(
                        '${messages.onboardingApiKeyGetKeyAt} $console',
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: textMed,
                        ),
                      ),
                    ),
                ] else
                  Text(
                    messages.onboardingApiKeyLocalNote,
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: textMed,
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step4),
                    child: Text(
                      _error!,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: dsTokensDark.colors.alert.error.defaultColor,
                      ),
                    ),
                  ),
                SizedBox(height: tokens.spacing.step6),
                DesignSystemButton(
                  onPressed: _busy ? null : _connect,
                  label: _busy
                      ? messages.onboardingApiKeyConnecting
                      : messages.onboardingApiKeyConnect,
                  leadingIcon: Icons.arrow_forward_rounded,
                  size: DesignSystemButtonSize.large,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
