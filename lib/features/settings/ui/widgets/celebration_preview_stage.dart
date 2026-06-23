import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The "Try it" stage: three dummy completion controls — a Done pill, a
/// checklist item, and a habit button — that each replay *their own* content
/// type's selected variant in context when tapped, so a user can feel the styles
/// on the real surfaces before committing. Greyed and inert when [enabled] is
/// false (the master switch is off).
class CelebrationPreviewStage extends ConsumerWidget {
  const CelebrationPreviewStage({this.enabled = true, super.key});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final tasksVariant = ref.watch(
      celebrationPreferencesProvider.select((p) => p.tasksVariant),
    );
    final habitsVariant = ref.watch(
      celebrationPreferencesProvider.select((p) => p.habitsVariant),
    );
    final checklistItemsVariant = ref.watch(
      celebrationPreferencesProvider.select((p) => p.checklistItemsVariant),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Wrap(
          spacing: tokens.spacing.step4,
          runSpacing: tokens.spacing.step3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Mirrors the task status pill: a centred burst with a roomy reach.
            _PreviewTrigger(
              variant: tasksVariant,
              count: 50,
              sizeScale: 0.8,
              clearCenter: 0.45,
              reachFactor: 2.2,
              child: _DonePill(label: messages.settingsCelebrationsPreviewDone),
            ),
            // Mirrors a checklist item: a finer, tighter burst around the box.
            _PreviewTrigger(
              variant: checklistItemsVariant,
              count: 16,
              sizeScale: 0.7,
              clearCenter: 0.3,
              reachFactor: 2,
              child: _ChecklistDummy(
                label: messages.settingsCelebrationsPreviewChecklistItem,
              ),
            ),
            // Mirrors the habit complete button.
            _PreviewTrigger(
              variant: habitsVariant,
              count: 50,
              sizeScale: 0.8,
              clearCenter: 0.4,
              reachFactor: 2.2,
              child: _HabitDummy(
                label: messages.settingsCelebrationsPreviewHabit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a dummy control: a tap pops it and fires a real overlay spark burst of
/// the given [variant], so the preview behaves exactly like the live surfaces.
class _PreviewTrigger extends StatefulWidget {
  const _PreviewTrigger({
    required this.variant,
    required this.child,
    required this.count,
    required this.sizeScale,
    required this.clearCenter,
    required this.reachFactor,
  });

  final CelebrationVariant variant;
  final Widget child;
  final int count;
  final double sizeScale;
  final double clearCenter;
  final double reachFactor;

  @override
  State<_PreviewTrigger> createState() => _PreviewTriggerState();
}

class _PreviewTriggerState extends State<_PreviewTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _fire() {
    // Match the live surfaces under reduce motion: spawnCompletionBurst already
    // no-ops, so suppress the anchor pop too rather than popping with no burst.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) _pop.forward(from: 0);
    spawnCompletionBurst(
      context,
      variant: widget.variant,
      count: widget.count,
      sizeScale: widget.sizeScale,
      clearCenter: widget.clearCenter,
      reachFactor: widget.reachFactor,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    // InkResponse (not GestureDetector) so the dummy control is focusable and
    // activatable by keyboard (Enter/Space), not pointer-only. Material
    // (transparent) hosts the ink so it works without an ancestor Material; the
    // radial splash stays shape-agnostic across the pill / box / habit dummies.
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        onTap: _fire,
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, child) {
            // A single 1 → 1.12 → 1 overshoot for the duration of the pop.
            final scale = 1 + 0.12 * math.sin(_pop.value * math.pi);
            return Transform.scale(scale: scale, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// A dummy "Done" status pill.
class _DonePill extends StatelessWidget {
  const _DonePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: tokens.spacing.step4,
            color: accent,
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dummy checklist item: a checked box and a label.
class _ChecklistDummy extends StatelessWidget {
  const _ChecklistDummy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tokens.spacing.step5,
          height: tokens.spacing.step5,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
          child: Icon(
            Icons.check_rounded,
            size: tokens.spacing.step4,
            color: tokens.colors.surface.enabled,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

/// A dummy habit complete button: a label with a trailing "+" disc.
class _HabitDummy extends StatelessWidget {
  const _HabitDummy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level02),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Icon(
            Icons.add_circle_rounded,
            size: tokens.spacing.step5,
            color: accent,
          ),
        ],
      ),
    );
  }
}
