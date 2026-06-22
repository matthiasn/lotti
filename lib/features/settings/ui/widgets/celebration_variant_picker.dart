import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The localized display name for [variant].
String celebrationVariantLabel(
  BuildContext context,
  CelebrationVariant variant,
) {
  final messages = context.messages;
  return switch (variant) {
    CelebrationVariant.sparks => messages.settingsCelebrationsVariantSparks,
    CelebrationVariant.fireworks =>
      messages.settingsCelebrationsVariantFireworks,
    CelebrationVariant.confetti => messages.settingsCelebrationsVariantConfetti,
    CelebrationVariant.embers => messages.settingsCelebrationsVariantEmbers,
    CelebrationVariant.bubbles => messages.settingsCelebrationsVariantBubbles,
  };
}

/// A grid of selectable celebration-style cards for one content type. Each card
/// plays a contained preview of its own variant when tapped, and tapping reports
/// it through [onSelect]; [selected] marks the active one. Greyed and inert when
/// [enabled] is false (the master switch is off).
///
/// The picker is style-only — it holds no opinion about which content type it
/// drives — so the Settings page renders one per content type (tasks, habits,
/// checklist items), each wired to its own field and setter.
class CelebrationVariantPicker extends StatelessWidget {
  const CelebrationVariantPicker({
    required this.selected,
    required this.onSelect,
    this.enabled = true,
    super.key,
  });

  /// The currently selected variant for this content type.
  final CelebrationVariant selected;

  /// Called with the tapped variant.
  final ValueChanged<CelebrationVariant> onSelect;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            for (final variant in CelebrationVariant.values)
              CelebrationVariantCard(
                variant: variant,
                label: celebrationVariantLabel(context, variant),
                selected: variant == selected,
                onTap: () => onSelect(variant),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single style card: a contained burst preview over a resting "source" dot,
/// the variant name beneath, and a selected ring. Tapping replays the preview
/// and reports the [onTap] selection.
class CelebrationVariantCard extends StatefulWidget {
  const CelebrationVariantCard({
    required this.variant,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CelebrationVariant variant;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<CelebrationVariantCard> createState() => _CelebrationVariantCardState();
}

class _CelebrationVariantCardState extends State<CelebrationVariantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    // Honour the system reduce-motion setting, exactly as the live surfaces do
    // (spawnCompletionBurst no-ops under reduce motion). The selection still
    // happens; only the preview animation is suppressed.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      // InkWell (not GestureDetector) so the card is focusable and activatable
      // by keyboard (Enter/Space), not pointer-only. The Material paints the
      // surface + selected border so the ink and focus highlight sit on top and
      // stay visible (an opaque child would hide them).
      child: SizedBox(
        width: tokens.spacing.step12,
        child: Material(
          color: tokens.colors.surface.enabled,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            side: BorderSide(
              color: widget.selected
                  ? accent
                  : tokens.colors.decorative.level02,
              width: widget.selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: _play,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: tokens.spacing.step10,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final playing =
                            _controller.value > 0 && _controller.value < 1;
                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Resting "source" dot — the thing being celebrated.
                            Container(
                              width: tokens.spacing.step4,
                              height: tokens.spacing.step4,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: playing ? 0.4 : 0.9,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (!playing)
                              Icon(
                                Icons.play_arrow_rounded,
                                size: tokens.spacing.step7,
                                color: tokens.colors.text.lowEmphasis,
                              ),
                            if (playing)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CompletionBurst(
                                    progress: _controller.value,
                                    variant: widget.variant,
                                    origin: Alignment.center,
                                    count: 22,
                                    sizeScale: 0.55,
                                    reachFactor: 0.9,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: widget.selected
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
