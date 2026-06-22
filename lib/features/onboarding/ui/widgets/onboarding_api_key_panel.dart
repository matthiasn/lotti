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

/// Debounce before a key edit fires a live probe. Deliberately on the slower
/// side so a partial key mid-typing never churns through checking → invalid;
/// the probe runs only once the user actually pauses.
const _verifyDebounce = Duration(milliseconds: 800);

/// Minimum time the "Checking…" status stays on screen once a probe starts, so
/// a fast provider response doesn't flash past before it can be read. A result
/// that arrives sooner is held until this elapses.
const _minCheckingVisible = Duration(seconds: 1);

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
  Timer? _dwellTimer;
  bool _dwellElapsed = false;
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
    // Listen (not watch) keeps the verifier alive and feeds the local display
    // state machine, which holds "checking" visible for [_minCheckingVisible].
    // The rendered status is [_display], not the raw verifier state.
    ref.listen(connectionVerifierControllerProvider(widget.type), (_, next) {
      _onVerifierChanged(next);
    });
    final verifyState = _display;

    // The fixed-height status slot only ever carries the LIVE verification
    // state now (idle → empty). The "how to get a key" guidance lives in a
    // persistent block above the slot so it never disappears the moment the
    // user starts typing — the activation cliff the novice reviewer flagged.
    final Widget statusChild;
    if (verifyState is ConnectionCheckIdle) {
      statusChild = const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      statusChild = _VerifyStatus(
        key: ValueKey('status-${verifyState.runtimeType}'),
        state: verifyState,
        providerName: onboardingProviderName(messages, widget.type),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          Positioned.fill(
            // Bleak fade: the brand-lit backdrop desaturates to greyscale when
            // the key is rejected, then recovers to full brand colour once the
            // user fixes it (or while still typing/verifying).
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _isRejected(verifyState) ? 0 : 1),
              duration: MotionDurations.long2,
              curve: MotionCurves.standard,
              child: OnboardingBackdrop(accent: brand),
              builder: (context, saturation, child) => ColorFiltered(
                colorFilter: _saturationColorFilter(saturation),
                child: child,
              ),
            ),
          ),
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
                  if (console != null) ...[
                    SizedBox(height: tokens.spacing.step3),
                    _GetKeyHelp(console: console, brand: brand),
                  ],
                ] else
                  Text(
                    messages.onboardingApiKeyLocalNote,
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: textMed,
                    ),
                  ),
                SizedBox(height: tokens.spacing.step3),
                // Status slot: a stable one-line minimum height so the common
                // states (link → checking → verified) crossfade in place
                // without shoving the panel, and an AnimatedSize so a longer
                // (multi-line) error message eases the slot taller rather than
                // snapping.
                AnimatedSize(
                  duration: MotionDurations.short4,
                  curve: MotionCurves.standard,
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: tokens.spacing.step7,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: MotionDurations.short3,
                        child: statusChild,
                      ),
                    ),
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
                  // Disabled until the key is verified, so the user can only
                  // proceed with a key the provider actually accepted.
                  onPressed: (_busy || verifyState is! ConnectionCheckVerified)
                      ? null
                      : _connect,
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

/// Whether the verification state is a rejection — drives the bleak greyscale
/// fade of the backdrop. Checking / verified / idle all stay in full colour.
bool _isRejected(ConnectionCheckState state) =>
    state is ConnectionCheckFailedHttp || state is ConnectionCheckFailedNetwork;

/// A luminance-preserving saturation [ColorFilter]: [s] == 1 leaves colour
/// untouched, [s] == 0 collapses to greyscale. Intermediate values (driven by a
/// tween) give the smooth desaturation when a key is rejected.
ColorFilter _saturationColorFilter(double s) {
  const lumR = 0.2126;
  const lumG = 0.7152;
  const lumB = 0.0722;
  final inv = 1 - s;
  return ColorFilter.matrix(<double>[
    lumR * inv + s, lumG * inv, lumB * inv, 0, 0, //
    lumR * inv, lumG * inv + s, lumB * inv, 0, 0, //
    lumR * inv, lumG * inv, lumB * inv + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Persistent novice guidance for the cloud-provider key step: the tappable
/// console link plus a one-line, plain-language walkthrough so getting a key
/// isn't a dead-end "link and leave". Always visible (not buried in the live
/// status slot) so it survives the moment the user starts typing.
class _GetKeyHelp extends StatelessWidget {
  const _GetKeyHelp({required this.console, required this.brand});

  final String console;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GetKeyLink(console: console, brand: brand),
        SizedBox(height: tokens.spacing.step1),
        Text(
          context.messages.onboardingApiKeyNoKeyHelp,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: dsTokensDark.colors.text.mediumEmphasis,
          ),
        ),
      ],
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
    );
  }
}

/// Compact, dark-themed live verification line for the key step. Mirrors the
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
      case ConnectionCheckFailedHttp(:final status):
        // Show our own clean, localized message rather than the provider's raw
        // body — which varies wildly (raw JSON, echoes the pasted key back,
        // etc.). 401/403 means the key was rejected; anything else is treated
        // as "couldn't reach the provider".
        final rejected = status == 401 || status == 403;
        return _line(
          context,
          leading: Icon(
            Icons.error_outline_rounded,
            color: danger,
            size: tokens.spacing.step5,
          ),
          text: rejected
              ? messages.onboardingApiKeyInvalid
              : messages.onboardingApiKeyUnreachable(providerName),
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
          text: messages.onboardingApiKeyUnreachable(providerName),
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
