import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
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
    this.onTune,
    this.enabled = true,
    super.key,
  });

  /// The current selection for this content type. A card is marked active when
  /// [selected] is the [FixedSelection] of its variant (or the Random / Combine
  /// card when the selection is one of the surprise modes).
  final CelebrationSelection selected;

  /// Called with the chosen selection: a [FixedSelection] of a tapped variant
  /// card, or [RandomSelection] / [CombineSelection] for the surprise cards.
  final ValueChanged<CelebrationSelection> onSelect;

  /// Opens the customization playground for a variant. When null, the per-card
  /// "tune" affordance is hidden (the surprise cards never show it — they have
  /// no parameters of their own).
  final ValueChanged<CelebrationVariant>? onTune;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final messages = context.messages;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The five fixed styles as a tidy card grid.
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step3,
              children: [
                for (final variant in CelebrationVariant.values)
                  CelebrationVariantCard(
                    variant: variant,
                    label: celebrationVariantLabel(context, variant),
                    selected:
                        selected is FixedSelection &&
                        (selected as FixedSelection).variant == variant,
                    onTap: () => onSelect(FixedSelection(variant)),
                    onTune: onTune == null ? null : () => onTune!(variant),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            // Surprise modes get full-width option rows (with room for a
            // one-line explanation) so they read as deliberate alternatives, not
            // greyed-out leftover cards. They reuse each variant's tuned params,
            // so there is nothing to customize on them.
            _SurpriseOptionRow(
              icon: Icons.shuffle_rounded,
              title: messages.settingsCelebrationsVariantRandom,
              subtitle: messages.settingsCelebrationsVariantRandomDescription,
              selected: selected is RandomSelection,
              onTap: () => onSelect(CelebrationSelection.random),
            ),
            SizedBox(height: tokens.spacing.step2),
            _SurpriseOptionRow(
              icon: Icons.auto_awesome_motion_rounded,
              title: messages.settingsCelebrationsVariantCombine,
              subtitle: messages.settingsCelebrationsVariantCombineDescription,
              selected: selected is CombineSelection,
              onTap: () => onSelect(CelebrationSelection.combine),
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
    this.onTune,
    super.key,
  });

  final CelebrationVariant variant;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Opens the customization playground for this variant. Hidden when null.
  final VoidCallback? onTune;

  @override
  State<CelebrationVariantCard> createState() => _CelebrationVariantCardState();
}

class _CelebrationVariantCardState extends State<CelebrationVariantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// The card's compact preview params — constant for this variant, so it's
  /// computed once rather than rebuilt every animation frame in the builder.
  late final CelebrationParams _previewParams = CelebrationParams.defaultsFor(
    widget.variant,
  ).withValue('count', 22).withValue('size', 0.55).withValue('reach', 0.9);

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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              // A faint accent wash on the selected card so the whole tile reads
              // active, not just its border.
              color: widget.selected
                  ? accent.withValues(alpha: 0.08)
                  : tokens.colors.surface.enabled,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step3,
                  ),
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
                                // A crisp solid play disc — the source being
                                // celebrated. It holds a single centered, opaque play
                                // triangle at rest and dims to become the burst's
                                // origin while playing (no overlapping translucent
                                // shapes, so it reads sharp at this small size).
                                Container(
                                  width: tokens.spacing.step7,
                                  height: tokens.spacing.step7,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(
                                      alpha: playing ? 0.4 : 1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: playing
                                      ? null
                                      : Icon(
                                          Icons.play_arrow_rounded,
                                          size: tokens.spacing.step5,
                                          color: tokens.colors.surface.enabled,
                                        ),
                                ),
                                if (playing)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CompletionBurst(
                                        progress: _controller.value,
                                        params: _previewParams,
                                        origin: Alignment.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
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
            // A quiet corner "tune" affordance — opens the playground without
            // selecting the card. Sits above the InkWell so it captures its own
            // tap, and only appears when customization is wired in.
            if (widget.onTune != null)
              Positioned(
                top: tokens.spacing.step1,
                right: tokens.spacing.step1,
                child: _CardTuneButton(
                  tooltip: context.messages.settingsCelebrationsCustomizeTitle,
                  selected: widget.selected,
                  onTap: widget.onTune!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small round "tune" button tucked into a variant card's corner.
class _CardTuneButton extends StatelessWidget {
  const _CardTuneButton({
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.colors.surface.enabled,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step1),
            child: Icon(
              Icons.tune_rounded,
              size: tokens.spacing.step4,
              color: selected
                  ? tokens.colors.interactive.enabled
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

/// A surprise-mode card (Random / Combine) — same footprint as a
/// [CelebrationVariantCard] but with a single representative [icon] instead of a
/// burst preview, since these modes have no parameters of their own.
///
/// A full-width selectable row: a tinted icon chip, a title + one-line
/// explanation, and a trailing check when active. Reads as a deliberate
/// alternative to the variant grid rather than an orphaned card.
class _SurpriseOptionRow extends StatelessWidget {
  const _SurpriseOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.08)
            : tokens.colors.surface.enabled,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          side: BorderSide(
            color: selected ? accent : tokens.colors.decorative.level02,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step3),
            child: Row(
              children: [
                Container(
                  width: tokens.spacing.step8,
                  height: tokens.spacing.step8,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                  ),
                  child: Icon(
                    icon,
                    size: tokens.spacing.step5,
                    color: accent,
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        subtitle,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: tokens.spacing.step5,
                  color: selected ? accent : tokens.colors.decorative.level02,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
