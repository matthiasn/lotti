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
  bool get isCancelled => kind == AiPickProviderResultKind.cancelled;
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

/// FTUE entry-point modal: "Set up AI features". Centered sheet with
/// seven provider tiles (Gemini RECOMMENDED / OpenAI / Anthropic NEW /
/// Alibaba NEW / MLX Audio NEW / Ollama DESKTOP ONLY / Voxtral DESKTOP ONLY), a
/// Don't-show-again secondary action, and a primary Continue button
/// that surfaces the user's pick.
///
/// Replaces the legacy `ProviderTypeSelectionModal` for the FTUE
/// flow — that modal is still used by the in-form provider type
/// switcher inside `InferenceProviderEditPage`.
///
/// Usage:
/// ```dart
/// final result = await AiPickProviderModal.show(context: context);
/// switch (result.kind) {
///   case _AiPickProviderResultKind.confirmed:
///     // route to the edit form preselected to result.providerType
///   case _AiPickProviderResultKind.dontShowAgain:
///     // persist the suppression flag
///   case _AiPickProviderResultKind.cancelled:
///     break;
/// }
/// ```
class AiPickProviderModal extends StatefulWidget {
  const AiPickProviderModal({
    required this.tiles,
    required this.initialSelection,
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

  final List<AiPickProviderTileSpec> tiles;
  final InferenceProviderType initialSelection;

  /// Opens the modal and returns the user's choice. Dismissal returns
  /// [AiPickProviderResult.cancelled].
  static Future<AiPickProviderResult> show({
    required BuildContext context,
    List<AiPickProviderTileSpec> tiles = defaultTiles,
    InferenceProviderType? initialSelection,
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
      title: context.messages.aiPickProviderModalTitle,
      builder: (modalCtx) => AiPickProviderModal(
        tiles: tiles,
        initialSelection: seed,
      ),
    );
    return result ?? const AiPickProviderResult.cancelled();
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
        Text(
          messages.aiPickProviderSubtitle,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
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
        Text(
          messages.aiPickProviderFooterHint,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        // Wrap so the two actions reflow onto a second line on narrow
        // sheets instead of overflowing the modal width.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
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
