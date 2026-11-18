import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Debounce before a key edit fires a live probe. Deliberately on the slower
/// side so a partial key mid-typing never churns through checking → invalid;
/// the probe runs only once the user actually pauses.
const _verifyDebounce = Duration(milliseconds: 800);

/// Minimum time the "Checking…" status stays on screen once a probe starts, so
/// a fast provider response doesn't flash past before it can be read. A result
/// that arrives sooner is held until this elapses.
const _minCheckingVisible = Duration(seconds: 1);

/// The key step, on the shared [OnboardingStage]: it gathers just the API key
/// for the chosen provider, **verifies it live** against the
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
    this.onClose,
    this.companion,
    this.progress,
    super.key,
  });

  final InferenceProviderType type;
  final VoidCallback onBack;
  final VoidCallback onConnected;

  /// Leaves the flow; null where there is none to leave (the demo's AI
  /// setup). Not offered while the provider is being set up.
  final VoidCallback? onClose;

  /// Builds the companion for the key check's [ConnectionCheckState] as the
  /// user sees it — thinking while it runs, pleased or let down by the
  /// answer — standing on the stage; while the provider is being set up
  /// after Connect, she is built as still checking. Null leaves her out.
  final Widget Function(ConnectionCheckState status)? companion;

  /// Where this step is in onboarding; null where it is borrowed (the demo's
  /// AI setup).
  final OnboardingProgress? progress;

  @override
  ConsumerState<OnboardingApiKeyPanel> createState() =>
      _OnboardingApiKeyPanelState();
}

class _OnboardingApiKeyPanelState extends ConsumerState<OnboardingApiKeyPanel> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Timer? _dwellTimer;
  bool _dwellElapsed = false;
  bool _obscure = true;
  ConnectionCheckState? _pendingResult;

  /// The status the slot renders. Mirrors the verifier but holds the "checking"
  /// state visible for at least [_minCheckingVisible]; see [_onVerifierChanged].
  ConnectionCheckState _display = const ConnectionCheckIdle();

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
    _dwellTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  ConnectionVerifierController get _verifier =>
      ref.read(connectionVerifierControllerProvider(widget.type).notifier);

  void _onKeyChanged(String value) {
    _debounce?.cancel();
    // Clear any prior result and drop the in-flight probe. The verifier emits
    // Idle, which resets the display via [_onVerifierChanged], so while the
    // user is still typing the slot stays neutral — never a stale "invalid"
    // churning on each keystroke — and the probe re-runs only once typing
    // pauses.
    _verifier.reset();
    if (value.trim().isEmpty) return;
    _debounce = Timer(_verifyDebounce, () {
      if (mounted) _verifyNow();
    });
  }

  void _verifyNow() {
    // Trim so a pasted key with stray whitespace verifies the same value that
    // _connect() persists — no false rejection blocking Connect.
    final apiKey = _controller.text.trim();
    unawaited(_verifier.verify(baseUrl: _baseUrl, apiKey: apiKey));
  }

  /// Drives the displayed status from verifier changes, enforcing the minimum
  /// "checking" dwell: a result that resolves before [_minCheckingVisible] has
  /// elapsed is parked in [_pendingResult] and applied when the dwell timer
  /// fires, so the "Checking…" line is always readable.
  void _onVerifierChanged(ConnectionCheckState next) {
    switch (next) {
      case ConnectionCheckChecking():
        _dwellTimer?.cancel();
        _pendingResult = null;
        _dwellElapsed = false;
        _dwellTimer = Timer(_minCheckingVisible, () {
          _dwellElapsed = true;
          final pending = _pendingResult;
          if (pending != null && mounted) {
            setState(() {
              _display = pending;
              _pendingResult = null;
            });
          }
        });
        setState(() => _display = next);
      case ConnectionCheckIdle():
        _dwellTimer?.cancel();
        _pendingResult = null;
        _dwellElapsed = false;
        setState(() => _display = next);
      case ConnectionCheckVerified():
      case ConnectionCheckFailedHttp():
      case ConnectionCheckFailedNetwork():
        if (_display is ConnectionCheckChecking && !_dwellElapsed) {
          _pendingResult = next; // hold until the dwell elapses
        } else {
          setState(() => _display = next);
        }
    }
  }

  Future<void> _connect() async {
    // The CTA is only enabled once the probe has verified the key, so a bad
    // key can't reach here; guard defensively anyway.
    if (_display is! ConnectionCheckVerified) return;

    final key = _controller.text.trim();
    _debounce?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });

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
      // Un-delete this provider's bundled profile *before* the FTUE setup
      // seeds. Onboarding binds `defaultProfileId` unconditionally, so a user
      // who once deleted that profile would otherwise get a category pointing
      // at a soft-deleted row that seeding deliberately will not recreate, and
      // the first task degrades to title-only. Deliberately setting this
      // provider up again is the "bring it back" signal; every other path
      // still honors the deletion.
      final revivedProfileId = onboardingSeededProfileId(widget.type);
      if (revivedProfileId != null) {
        await repository.restoreConfig(revivedProfileId);
      }
      if (!mounted) return;
      await runFtueSetupForType(
        context: context,
        ref: ref,
        providerType: widget.type,
        config: config,
        setupService: ref.read(providerPromptSetupServiceProvider),
        createDefaultCategory: false,
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
    final accent = tokens.colors.interactive.enabled;
    final textHigh = tokens.colors.text.highEmphasis;
    final textMed = tokens.colors.text.mediumEmphasis;
    final errorColor = tokens.colors.alert.error.ink;
    final console = aiProviderKeyConsoleUrl(widget.type);
    // Listen (not watch) keeps the verifier alive and feeds the local display
    // state machine, which holds "checking" visible for [_minCheckingVisible].
    // The rendered status is [_display], not the raw verifier state.
    ref.listen(connectionVerifierControllerProvider(widget.type), (_, next) {
      _onVerifierChanged(next);
    });
    final verifyState = _display;

    // One fixed-height slot crossfades between the at-rest hint and the live
    // verification status, so nothing moves as the user types / verifies / is
    // rejected (the "jumpy when validating" complaint). The "how to get a
    // key" guidance is the step's own line, above.
    final Widget statusChild;
    if (verifyState is ConnectionCheckIdle) {
      statusChild = _requiresKey
          ? Text(
              key: const ValueKey('hint'),
              messages.onboardingApiKeyEnterKeyHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: textMed,
              ),
            )
          : const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      statusChild = _VerifyStatus(
        key: ValueKey('status-${verifyState.runtimeType}'),
        state: verifyState,
        providerName: onboardingProviderName(messages, widget.type),
      );
    }

    final providerName = onboardingProviderName(messages, widget.type);
    final verified = !_busy && verifyState is ConnectionCheckVerified;
    return OnboardingStage(
      // She says nothing here: the status line carries the words.
      companion: widget.companion?.call(
        _busy ? const ConnectionCheckChecking() : verifyState,
      ),
      // A local provider has no key to ask for: she says what she is doing
      // instead, and the provider is named in the tray.
      // Once the check has passed she says so, and what the button does.
      title: verified
          ? messages.onboardingApiKeyVerifiedTitle
          : _requiresKey
          ? messages.onboardingApiKeyTitle
          : messages.onboardingApiKeyLocalTitle,
      // Plain-language guidance, so getting a key isn't a dead-end "link
      // and leave".
      text: verified
          ? messages.onboardingApiKeyVerifiedText
          : !_requiresKey
          ? messages.onboardingApiKeyLocalNote
          : console != null
          ? messages.onboardingApiKeyNoKeyHelp
          : null,
      progress: widget.progress,
      // Both stay in the bar, only disabled while the provider is set up.
      onBack: _busy ? null : widget.onBack,
      showBack: true,
      onClose: _busy ? null : widget.onClose,
      showClose: widget.onClose != null,
      caption: messages.onboardingApiKeyProviderCaption,
      primary: !_requiresKey && !_busy && _isRejected(verifyState)
          // Nothing to retype for a local provider that did not answer:
          // once it is running, the check is run again from here.
          ? OnboardingStageAction(
              label: messages.agentKnowledgeRetry,
              onPressed: _verifyNow,
            )
          : OnboardingStageAction(
              // The label narrates the gate: Verifying… while a probe runs,
              // Connecting… while creating the provider (power-user review).
              label: _busy
                  ? messages.onboardingApiKeyConnecting
                  : verifyState is ConnectionCheckChecking
                  ? messages.onboardingApiKeyVerifying
                  : messages.onboardingConnectContinueWith(providerName),
              // Disabled until the key is verified, so the user can only
              // proceed with a key the provider actually accepted.
              onPressed: (_busy || verifyState is! ConnectionCheckVerified)
                  ? null
                  : _connect,
              icon: LottiIcons.forward,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The provider chosen on the step before, the same card in the
          // same place, now saying how its connection stands. A fixed slot,
          // tall enough for a two-line rejection, so nothing moves as it
          // crosses from the hint to "Checking…" to the answer.
          // No check of its own: the status line under its name carries the
          // one, once the key has passed.
          OnboardingProviderCard(
            type: widget.type,
            chosen: null,
            onTap: null,
            status: SizedBox(
              height: tokens.spacing.step8,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: AnimatedSwitcher(
                  duration: MotionDurations.short3,
                  child: statusChild,
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          if (_requiresKey) ...[
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              // A secret like a password: obscured by default with an
              // eye toggle to reveal for paste verification.
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: _onKeyChanged,
              // Enter connects when already verified, otherwise forces an
              // immediate check instead of waiting out the debounce.
              onSubmitted: (_) {
                if (verifyState is ConnectionCheckVerified) {
                  _connect();
                } else {
                  _debounce?.cancel();
                  _verifyNow();
                }
              },
              style: tokens.typography.styles.body.bodyLarge.copyWith(
                color: textHigh,
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: messages.onboardingApiKeyField,
                hintStyle: tokens.typography.styles.body.bodyLarge.copyWith(
                  color: textMed,
                ),
                filled: true,
                fillColor: tokens.colors.background.level01,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step3,
                ),
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? LottiIcons.visible : LottiIcons.hidden,
                    color: textMed,
                    size: tokens.spacing.step5,
                  ),
                  tooltip: _obscure
                      ? messages.onboardingApiKeyReveal
                      : messages.onboardingApiKeyHide,
                ),
                // A visible resting border so the field reads as a
                // discrete control at rest (low-vision review), in the
                // outline every onboarding control wears, brightening to
                // the accent on focus.
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  borderSide: BorderSide(
                    color: tokens.colors.decorative.level03,
                    width: tokens.spacing.step1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  borderSide: BorderSide(
                    color: accent,
                    width: tokens.spacing.step1,
                  ),
                ),
              ),
            ),
            if (console != null) ...[
              SizedBox(height: tokens.spacing.step3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _GetKeyLink(console: console),
              ),
            ],
          ],
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step4),
              child: Text(
                _error!,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Whether the check ended in a rejection or no answer: a local provider is
/// then offered the check again.
bool _isRejected(ConnectionCheckState state) =>
    state is ConnectionCheckFailedHttp || state is ConnectionCheckFailedNetwork;

/// Tappable "Get a key at `<console>`" hint that launches the provider's API-key
/// console in the browser. The host is rendered in the provider's brand colour
/// with an underline + external-link glyph so it reads as a link on the dark
/// panel.
class _GetKeyLink extends StatelessWidget {
  const _GetKeyLink({required this.console});

  final String console;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textMed = tokens.colors.text.mediumEmphasis;
    final bodySmall = tokens.typography.styles.body.bodySmall;
    // Teal (the app's single structural accent), not the provider brand: a
    // "open this URL" link is an app action, so it matches the Connect CTA and
    // "More options" rather than the provider-identity surfaces.
    final accent = tokens.colors.interactive.enabled;

    return InkWell(
      onTap: () => unawaited(handleMarkdownLinkTap('https://$console', '')),
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${messages.onboardingApiKeyGetKeyAt} ',
                      style: bodySmall.copyWith(color: textMed),
                    ),
                    TextSpan(
                      text: console,
                      style: bodySmall.copyWith(
                        color: accent,
                        decoration: TextDecoration.underline,
                        decorationColor: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
            Icon(
              LottiIcons.openExternal,
              size: tokens.spacing.step4,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact, theme-aware live verification line for the key step. Mirrors the
/// settings `ConnectionStatusStrip` semantics (checking / verified / failed)
/// but as a single inline row that fits the cinematic panel. Idle renders
/// nothing — the caller shows the "get a key" link in that slot instead.
class _VerifyStatus extends StatelessWidget {
  const _VerifyStatus({
    required this.state,
    required this.providerName,
    super.key,
  });

  final ConnectionCheckState state;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textMed = tokens.colors.text.mediumEmphasis;
    // Both paint status lines in `bodySmall`, so both owe AA — `ink` is the
    // step that carries it in either brightness. The failure line is the most
    // anxious moment, so it must be the most readable; picking the ramp step
    // by hand for that is now the token's job.
    final success = tokens.colors.alert.success.ink;
    final danger = tokens.colors.alert.error.ink;

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
            LottiIcons.confirmCircled,
            color: success,
            size: tokens.spacing.step5,
          ),
          text: messages.aiProviderConnectionVerifiedTitle,
          color: success,
        );
      case ConnectionCheckFailedHttp(:final status):
        // Show our own clean, localized message rather than the provider's raw
        // body — which varies wildly (raw JSON, echoes the pasted key back,
        // etc.). 401/403 means the key was rejected; anything else is treated
        // as "couldn't reach the provider".
        final rejected = status == 401 || status == 403;
        return _line(
          context,
          leading: Icon(
            LottiIcons.error,
            color: danger,
            size: tokens.spacing.step5,
          ),
          text: rejected
              ? messages.onboardingApiKeyInvalid
              : messages.onboardingApiKeyUnreachable(providerName),
          color: danger,
          emphasize: true,
        );
      case ConnectionCheckFailedNetwork():
        return _line(
          context,
          leading: Icon(
            LottiIcons.error,
            color: danger,
            size: tokens.spacing.step5,
          ),
          text: messages.onboardingApiKeyUnreachable(providerName),
          color: danger,
          emphasize: true,
        );
    }
  }

  Widget _line(
    BuildContext context, {
    required Widget leading,
    required String text,
    required Color color,
    bool emphasize = false,
  }) {
    final tokens = context.designTokens;
    return Row(
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
              // Errors carry extra weight so the most anxious line is the
              // clearest, per the low-vision review.
              fontWeight: emphasize ? tokens.typography.weight.semiBold : null,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
