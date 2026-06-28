import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
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
    final prefs = ref.watch(celebrationPreferencesProvider);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Wrap(
          spacing: tokens.spacing.step4,
          runSpacing: tokens.spacing.step3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PreviewTrigger(
              selection: prefs.tasksSelection,
              paramsFor: prefs.paramsFor,
              child: _DonePill(label: messages.settingsCelebrationsPreviewDone),
            ),
            _PreviewTrigger(
              selection: prefs.checklistItemsSelection,
              paramsFor: prefs.paramsFor,
              child: _ChecklistDummy(
                label: messages.settingsCelebrationsPreviewChecklistItem,
              ),
            ),
            _PreviewTrigger(
              selection: prefs.habitsSelection,
              paramsFor: prefs.paramsFor,
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

/// Wraps a dummy control: a tap pops it and fires a real overlay burst of the
/// content type's [selection] (resolving Random / Combine fresh each tap), so
/// the preview behaves exactly like the live surfaces.
class _PreviewTrigger extends StatefulWidget {
  const _PreviewTrigger({
    required this.selection,
    required this.paramsFor,
    required this.child,
  });

  final CelebrationSelection selection;
  final CelebrationParams Function(CelebrationVariant) paramsFor;
  final Widget child;

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
    final resolved = widget.selection.resolve(seed: nextCelebrationSeed());
    spawnCompletionBurst(
      context,
      params: widget.paramsFor(resolved.primary),
      secondParams: resolved.secondary == null
          ? null
          : widget.paramsFor(resolved.secondary!),
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
