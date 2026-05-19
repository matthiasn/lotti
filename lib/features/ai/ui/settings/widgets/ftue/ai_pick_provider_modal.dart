import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Outcome of the pick-provider modal. Three terminal states the caller
/// has to dispatch on:
/// - [AiPickProviderResultKind.confirmed]: user picked a provider type
///   and tapped Continue.
/// - [AiPickProviderResultKind.dontShowAgain]: user opted out of the
///   FTUE prompt entirely; the caller should persist the suppression
///   flag and skip the flow.
/// - [AiPickProviderResultKind.cancelled]: modal dismissed (close
///   button, swipe, back nav).
enum AiPickProviderResultKind { confirmed, dontShowAgain, cancelled }

@immutable
class AiPickProviderResult {
  const AiPickProviderResult._({required this.kind, this.providerType});

  /// User picked [providerType] and tapped Continue.
  const AiPickProviderResult.confirmed(InferenceProviderType providerType)
    : this._(
        kind: AiPickProviderResultKind.confirmed,
        providerType: providerType,
      );

  /// User tapped "Don't show again".
  const AiPickProviderResult.dontShowAgain()
    : this._(kind: AiPickProviderResultKind.dontShowAgain);

  /// Modal dismissed without picking a provider.
  const AiPickProviderResult.cancelled()
    : this._(kind: AiPickProviderResultKind.cancelled);

  final AiPickProviderResultKind kind;
  final InferenceProviderType? providerType;

  bool get isConfirmed => kind == AiPickProviderResultKind.confirmed;
  bool get isDontShowAgain => kind == AiPickProviderResultKind.dontShowAgain;
}

/// Per-row metadata describing one tile rendered inside the modal.
/// Kept as plain Dart so tests can assert against the static spec
/// without having to pump the widget tree.
@immutable
class AiPickProviderTileSpec {
  const AiPickProviderTileSpec({
    required this.providerType,
    this.badge,
    this.disabled = false,
  });

  final InferenceProviderType providerType;

  /// Optional badge tone-key (recommended / new / desktopOnly). The
  /// modal resolves the localised label + tone at render time.
  final AiPickProviderBadge? badge;

  /// When `true`, the tile shows but the radio is non-tappable. Used
  /// for `desktopOnly` providers on phone-size viewports — the user
  /// can still see the option, they just cannot pick it.
  final bool disabled;
}

enum AiPickProviderBadge { recommended, newcomer, desktopOnly }

/// Provider-type picker — single modal used for both the FTUE flow
/// ("Set up AI features", showFtueChrome=true) and the bare type
/// picker invoked outside the FTUE (showFtueChrome=false). Centered
/// sheet with provider tiles, an optional Don't-show-again secondary
/// action, and a primary Continue button that surfaces the user's
/// pick.
///
/// Three entry points:
///   - [show] — full-control entry, returns [AiPickProviderResult].
///   - [showAllTypes] — non-FTUE entry, surfaces every
///     `InferenceProviderType` and returns the picked type or null.
///
/// Usage:
/// ```dart
/// final result = await AiPickProviderModal.show(context: context);
/// switch (result.kind) {
///   case AiPickProviderResultKind.confirmed:
///     // route to the edit form preselected to result.providerType
///   case AiPickProviderResultKind.dontShowAgain:
///     // persist the suppression flag
///   case AiPickProviderResultKind.cancelled:
///     break;
/// }
/// ```
class AiPickProviderModal extends StatefulWidget {
  const AiPickProviderModal({
    required this.tiles,
    required this.initialSelection,
    this.showFtueChrome = true,
    super.key,
  });

  /// Default tile lineup matching the design: Gemini (RECOMMENDED) →
  /// OpenAI → Anthropic (NEW) → Alibaba (NEW) → MLX Audio (NEW) →
  /// Ollama (DESKTOP ONLY) → Voxtral (DESKTOP ONLY).
  /// Alibaba lands before the local options so the embedded/desktop
  /// providers stay last in the list. Exposed as a static so tests can
  /// re-use the same spec the modal ships with without instantiating
  /// the widget.
  static const List<AiPickProviderTileSpec> defaultTiles =
      <AiPickProviderTileSpec>[
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.gemini,
          badge: AiPickProviderBadge.recommended,
        ),
        AiPickProviderTileSpec(providerType: InferenceProviderType.openAi),
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.anthropic,
          badge: AiPickProviderBadge.newcomer,
        ),
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.alibaba,
          badge: AiPickProviderBadge.newcomer,
        ),
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.mlxAudio,
          badge: AiPickProviderBadge.newcomer,
        ),
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.ollama,
          badge: AiPickProviderBadge.desktopOnly,
        ),
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.voxtral,
          badge: AiPickProviderBadge.desktopOnly,
        ),
      ];

  /// Full-coverage tile lineup used when the modal is reused outside
  /// the FTUE — e.g. the AI Settings "+ Add provider" handler after
  /// the FTUE has been dismissed, and the in-form provider-type
  /// switcher inside `InferenceProviderEditPage`. Starts with the
  /// curated [defaultTiles] (so power users see the same recommended
  /// surfacing) then appends the advanced types that the FTUE
  /// intentionally hides — alphabetical, no badges. Every
  /// `InferenceProviderType` value is reachable here.
  static const List<AiPickProviderTileSpec> allTypesTiles =
      <AiPickProviderTileSpec>[
        ...defaultTiles,
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.genericOpenAi,
        ),
        AiPickProviderTileSpec(providerType: InferenceProviderType.mistral),
        AiPickProviderTileSpec(
          providerType: InferenceProviderType.nebiusAiStudio,
        ),
        AiPickProviderTileSpec(providerType: InferenceProviderType.openRouter),
        AiPickProviderTileSpec(providerType: InferenceProviderType.whisper),
      ];

  final List<AiPickProviderTileSpec> tiles;
  final InferenceProviderType initialSelection;

  /// When `true` (the FTUE default), the modal shows the FTUE-only
  /// chrome: the "Pick a provider to get started…" subtitle, the
  /// "You can add more providers later…" footer hint, and the
  /// "Don't show again" secondary button. When `false`, all three
  /// are hidden — pure provider-type picker, no FTUE pitch — and
  /// the modal never produces `dontShowAgain` results.
  final bool showFtueChrome;

  /// Opens the modal and returns the user's choice. Dismissal returns
  /// [AiPickProviderResult.cancelled]. When [showFtueChrome] is
  /// `false`, the modal cannot return `dontShowAgain` (the button is
  /// hidden) — pass [showAllTypes] for that flow if you want the
  /// `InferenceProviderType?` shape directly.
  static Future<AiPickProviderResult> show({
    required BuildContext context,
    List<AiPickProviderTileSpec> tiles = defaultTiles,
    InferenceProviderType? initialSelection,
    String? title,
    bool showFtueChrome = true,
  }) async {
    final seed =
        initialSelection ??
        tiles
            .firstWhere(
              (t) => !t.disabled,
              orElse: () => tiles.first,
            )
            .providerType;
    final result = await ModalUtils.showSinglePageModal<AiPickProviderResult>(
      context: context,
      title: title ?? context.messages.aiPickProviderModalTitle,
      builder: (modalCtx) => AiPickProviderModal(
        tiles: tiles,
        initialSelection: seed,
        showFtueChrome: showFtueChrome,
      ),
    );
    return result ?? const AiPickProviderResult.cancelled();
  }

  /// Non-FTUE entry point — opens the modal with [allTypesTiles] and
  /// FTUE chrome hidden, then collapses the three-state result into
  /// a `Future<InferenceProviderType?>` for call sites that only
  /// care about the chosen type.
  ///
  /// Returns the picked type on Continue, or `null` on any other
  /// outcome (sheet dismissed, close X, swipe). The "Don't show
  /// again" button is hidden in this mode, so `dontShowAgain` is
  /// never produced.
  ///
  /// Used by the AI Settings "+ Add provider" handler in the
  /// dismissed-FTUE path, and the in-form provider-type switcher
  /// inside `InferenceProviderEditPage`.
  static Future<InferenceProviderType?> showAllTypes({
    required BuildContext context,
    InferenceProviderType? initialSelection,
    String? title,
  }) async {
    final result = await show(
      context: context,
      tiles: allTypesTiles,
      initialSelection: initialSelection,
      title: title ?? context.messages.aiConfigSelectProviderTypeModalTitle,
      showFtueChrome: false,
    );
    // `showFtueChrome:false` hides the Don't-show-again button, so
    // the underlying modal cannot emit `dontShowAgain`. Document the
    // invariant — if a future caller routes a chromed result through
    // this entry point, the suppression intent would otherwise be
    // silently dropped.
    assert(
      !result.isDontShowAgain,
      'showAllTypes received dontShowAgain — chrome should hide that button',
    );
    return result.isConfirmed ? result.providerType : null;
  }

  @override
  State<AiPickProviderModal> createState() => _AiPickProviderModalState();
}

class _AiPickProviderModalState extends State<AiPickProviderModal> {
  late InferenceProviderType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  void _select(InferenceProviderType type) {
    if (_selected == type) return;
    setState(() => _selected = type);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showFtueChrome) ...[
          Text(
            messages.aiPickProviderSubtitle,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
        ],
        for (var i = 0; i < widget.tiles.length; i++) ...[
          if (i > 0) SizedBox(height: tokens.spacing.step3),
          _ProviderTile(
            spec: widget.tiles[i],
            selected: widget.tiles[i].providerType == _selected,
            onTap: widget.tiles[i].disabled
                ? null
                : () => _select(widget.tiles[i].providerType),
          ),
        ],
        SizedBox(height: tokens.spacing.step5),
        if (widget.showFtueChrome) ...[
          Text(
            messages.aiPickProviderFooterHint,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
        ],
        // Wrap so the two FTUE actions reflow onto a second line on
        // narrow sheets instead of overflowing the modal width. In
        // non-FTUE mode this collapses to a single right-aligned
        // Continue button, which Wrap renders correctly without a
        // dedicated branch.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            if (widget.showFtueChrome)
              DesignSystemButton(
                label: messages.aiPickProviderDontShowAgainButton,
                variant: DesignSystemButtonVariant.tertiary,
                size: DesignSystemButtonSize.large,
                onPressed: () => Navigator.of(context).pop(
                  const AiPickProviderResult.dontShowAgain(),
                ),
              ),
            DesignSystemButton(
              label: messages.aiPickProviderContinueButton,
              size: DesignSystemButtonSize.large,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => Navigator.of(context).pop(
                AiPickProviderResult.confirmed(_selected),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final AiPickProviderTileSpec spec;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = aiProviderAccent(type: spec.providerType, tokens: tokens);
    final surface = aiProviderSurface(type: spec.providerType, tokens: tokens);
    final displayName = aiProviderDisplayName(
      type: spec.providerType,
      messages: messages,
    );
    final tagline = aiProviderTagline(
      type: spec.providerType,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.l);
    final borderColor = selected
        ? accent.withValues(alpha: 0.5)
        : tokens.colors.decorative.level01;
    return Opacity(
      opacity: spec.disabled ? 0.55 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: radius,
            border: Border.all(color: borderColor),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  // Provider-tinted icon tile.
                  Container(
                    width: tokens.spacing.step8,
                    height: tokens.spacing.step8,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                    ),
                    child: Icon(
                      aiProviderIcon(spec.providerType),
                      color: accent,
                      size: tokens.spacing.step6,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  // Name + optional badge stacked over the tagline.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: tokens.spacing.step3,
                          runSpacing: tokens.spacing.step1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              displayName,
                              style: tokens.typography.styles.subtitle.subtitle1
                                  .copyWith(
                                    color: tokens.colors.text.highEmphasis,
                                    fontWeight:
                                        tokens.typography.weight.semiBold,
                                  ),
                            ),
                            if (spec.badge != null)
                              _PickProviderBadge(badge: spec.badge!),
                          ],
                        ),
                        if (tagline.isNotEmpty) ...[
                          SizedBox(height: tokens.spacing.step1),
                          Text(
                            tagline,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  _RadioIndicator(selected: selected, accent: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickProviderBadge extends StatelessWidget {
  const _PickProviderBadge({required this.badge});

  final AiPickProviderBadge badge;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final (label, tone) = switch (badge) {
      AiPickProviderBadge.recommended => (
        messages.aiPickProviderBadgeRecommended,
        DesignSystemBadgeTone.success,
      ),
      AiPickProviderBadge.newcomer => (
        messages.aiPickProviderBadgeNew,
        DesignSystemBadgeTone.primary,
      ),
      AiPickProviderBadge.desktopOnly => (
        messages.aiPickProviderBadgeDesktopOnly,
        DesignSystemBadgeTone.secondary,
      ),
    };
    return DesignSystemBadge.outlined(label: label, tone: tone);
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final size = tokens.spacing.step6;
    if (selected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: Icon(
          Icons.check_rounded,
          size: tokens.spacing.step5,
          color: tokens.colors.text.onInteractiveAlert,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.colors.decorative.level02,
          width: 2,
        ),
      ),
    );
  }
}
