import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/markdown_link_utils.dart';

/// Debounce before a key edit fires a live probe — long enough that
/// typing/pasting settles, short enough that an invalid key surfaces
/// almost immediately.
const _verifyDebounce = Duration(milliseconds: 600);

/// Screen 3 of the FTUE: the visually-matching, simple step that gathers just
/// the API key for the chosen provider, **verifies it live** against the
/// provider's "list models" endpoint, and only then creates the provider and
/// runs the existing per-provider FTUE setup natively (no detour to the plain
/// settings editor). Cloud providers show a key field + "get a key" link;
/// local providers (Ollama) show a no-key note and are verified for
/// reachability on open.
///
/// Verification reuses [ConnectionVerifierController] (same probes as the
/// settings connect form), so an invalid/typo'd key is rejected here — at the
/// activation cliff — instead of silently succeeding and failing later at
/// inference time.
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
  Timer? _debounce;
  bool _busy = false;
  String? _error;

  bool get _requiresKey => ProviderConfig.requiresApiKey(widget.type);

  String get _baseUrl => ProviderConfig.defaultBaseUrls[widget.type] ?? '';

  @override
  void initState() {
    super.initState();
    // Local providers (Ollama) have no key to type, so probe reachability as
    // soon as the step opens — a stopped local server should be caught here,
    // not at first inference.
    if (!_requiresKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyNow());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  ConnectionVerifierController get _verifier =>
      ref.read(connectionVerifierControllerProvider(widget.type).notifier);

  void _onKeyChanged(String value) {
    _debounce?.cancel();
    // Drop any in-flight probe so its late result can't overwrite the state
    // for the key the user is now typing.
    _verifier.invalidate();
    if (value.trim().isEmpty) {
      // Back to idle → the "get a key" link returns, no stale error lingers.
      _verifier.reset();
      return;
    }
    _debounce = Timer(_verifyDebounce, () {
      if (mounted) _verifyNow();
    });
  }

  void _verifyNow() {
    unawaited(_verifier.verify(baseUrl: _baseUrl, apiKey: _controller.text));
  }

  Future<void> _connect() async {
    final key = _controller.text.trim();
    if (_requiresKey && key.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Verify first (reusing any live result), so a bad key never creates a
    // half-working provider.
    _debounce?.cancel();
    var state = ref.read(connectionVerifierControllerProvider(widget.type));
    if (state is! ConnectionCheckVerified) {
      await _verifier.verify(baseUrl: _baseUrl, apiKey: key);
      if (!mounted) return;
      state = ref.read(connectionVerifierControllerProvider(widget.type));
    }
    if (state is! ConnectionCheckVerified) {
      // The inline status line already explains why; just re-enable the CTA.
      setState(() => _busy = false);
      return;
    }

    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final config =
          AiConfig.inferenceProvider(
                id: uuid.v1(),
                baseUrl: _baseUrl,
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
    final verifyState = ref.watch(
      connectionVerifierControllerProvider(widget.type),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          Positioned.fill(child: OnboardingBackdrop(accent: brand)),
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
                    onChanged: _onKeyChanged,
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
                  SizedBox(height: tokens.spacing.step3),
                  // Live verification status replaces the "get a key" link once
                  // a probe is in flight or has resolved.
                  if (verifyState is ConnectionCheckIdle && console != null)
                    _GetKeyLink(console: console, brand: brand)
                  else
                    _VerifyStatus(
                      state: verifyState,
                      providerName: onboardingProviderName(
                        messages,
                        widget.type,
                      ),
                    ),
                ] else ...[
                  Text(
                    messages.onboardingApiKeyLocalNote,
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: textMed,
                    ),
                  ),
                  if (verifyState is! ConnectionCheckIdle) ...[
                    SizedBox(height: tokens.spacing.step3),
                    _VerifyStatus(
                      state: verifyState,
                      providerName: onboardingProviderName(
                        messages,
                        widget.type,
                      ),
                    ),
                  ],
                ],
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

/// Tappable "Get a key at `<console>`" hint that launches the provider's API-key
/// console in the browser. The host is rendered in the provider's brand colour
/// with an underline + external-link glyph so it reads as a link on the dark
/// panel.
class _GetKeyLink extends StatelessWidget {
  const _GetKeyLink({required this.console, required this.brand});

  final String console;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textMed = dsTokensDark.colors.text.mediumEmphasis;
    final bodySmall = tokens.typography.styles.body.bodySmall;

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => unawaited(handleMarkdownLinkTap('https://$console', '')),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${messages.onboardingApiKeyGetKeyAt} ',
                        style: bodySmall.copyWith(color: textMed),
                      ),
                      TextSpan(
                        text: console,
                        style: bodySmall.copyWith(
                          color: brand,
                          decoration: TextDecoration.underline,
                          decorationColor: brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Icon(
                Icons.open_in_new_rounded,
                size: tokens.spacing.step4,
                color: brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact, dark-themed live verification line for the key step. Mirrors the
/// settings `ConnectionStatusStrip` semantics (checking / verified / failed)
/// but as a single inline row that fits the cinematic panel. Idle renders
/// nothing — the caller shows the "get a key" link in that slot instead.
class _VerifyStatus extends StatelessWidget {
  const _VerifyStatus({required this.state, required this.providerName});

  final ConnectionCheckState state;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textMed = dsTokensDark.colors.text.mediumEmphasis;
    final success = dsTokensDark.colors.alert.success.defaultColor;
    final danger = dsTokensDark.colors.alert.error.defaultColor;

    switch (state) {
      case ConnectionCheckIdle():
        return const SizedBox.shrink();
      case ConnectionCheckChecking():
        return _line(
          context,
          leading: SizedBox(
            width: tokens.spacing.step4,
            height: tokens.spacing.step4,
            child: CircularProgressIndicator(strokeWidth: 2, color: textMed),
          ),
          text: messages.aiProviderConnectionCheckingLabel,
          color: textMed,
        );
      case ConnectionCheckVerified():
        return _line(
          context,
          leading: Icon(
            Icons.check_circle_rounded,
            color: success,
            size: tokens.spacing.step5,
          ),
          text: messages.aiProviderConnectionVerifiedTitle,
          color: success,
        );
      case ConnectionCheckFailedHttp(:final message):
        return _line(
          context,
          leading: Icon(
            Icons.error_outline_rounded,
            color: danger,
            size: tokens.spacing.step5,
          ),
          // Prefer the provider's own message ("Invalid API key …") so the
          // user sees exactly why the key was rejected.
          text: message.isNotEmpty
              ? message
              : messages.aiProviderConnectionFailedTitle(providerName),
          color: danger,
        );
      case ConnectionCheckFailedNetwork():
        return _line(
          context,
          leading: Icon(
            Icons.error_outline_rounded,
            color: danger,
            size: tokens.spacing.step5,
          ),
          text: messages.aiProviderConnectionFailedTitle(providerName),
          color: danger,
        );
    }
  }

  Widget _line(
    BuildContext context, {
    required Widget leading,
    required String text,
    required Color color,
  }) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: tokens.spacing.step5,
          child: Center(child: leading),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            text,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: color,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
