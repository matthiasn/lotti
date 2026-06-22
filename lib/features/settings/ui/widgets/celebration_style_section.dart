import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_variant_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The content type a celebration style is being assigned to.
enum _CelebrationSurface { tasks, habits, checklists }

/// Resolves a surface to its localized label, current variant, and setter, so
/// the section can drive any surface through one code path.
class _SurfaceBinding {
  const _SurfaceBinding({
    required this.surface,
    required this.label,
    required this.variant,
    required this.onSelect,
  });

  final _CelebrationSurface surface;
  final String label;
  final CelebrationVariant variant;
  final ValueChanged<CelebrationVariant> onSelect;
}

/// The Style section's assignment UI. Rather than stacking one full style picker
/// per content type (three near-identical 5-card grids), it shows a single
/// [CelebrationVariantPicker] bound to whichever surface is selected in the
/// [_SurfaceSelector] above it. The selector doubles as a summary — each segment
/// shows that surface's currently assigned style — so all three choices are
/// visible at a glance while only one picker is ever on screen.
///
/// Greyed and inert (via the picker / selector) when [enabled] is false (the
/// master switch is off).
class CelebrationStyleSection extends ConsumerStatefulWidget {
  const CelebrationStyleSection({this.enabled = true, super.key});

  final bool enabled;

  @override
  ConsumerState<CelebrationStyleSection> createState() =>
      _CelebrationStyleSectionState();
}

class _CelebrationStyleSectionState
    extends ConsumerState<CelebrationStyleSection> {
  _CelebrationSurface _active = _CelebrationSurface.tasks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final prefs = ref.watch(celebrationPreferencesProvider);
    final controller = ref.read(
      celebrationPreferencesControllerProvider.notifier,
    );

    final bindings = <_SurfaceBinding>[
      _SurfaceBinding(
        surface: _CelebrationSurface.tasks,
        label: messages.settingsCelebrationsTasksTitle,
        variant: prefs.tasksVariant,
        onSelect: controller.setTasksVariant,
      ),
      _SurfaceBinding(
        surface: _CelebrationSurface.habits,
        label: messages.settingsCelebrationsHabitsTitle,
        variant: prefs.habitsVariant,
        onSelect: controller.setHabitsVariant,
      ),
      _SurfaceBinding(
        surface: _CelebrationSurface.checklists,
        label: messages.settingsCelebrationsChecklistTitle,
        variant: prefs.checklistItemsVariant,
        onSelect: controller.setChecklistItemsVariant,
      ),
    ];
    final active = bindings.firstWhere((b) => b.surface == _active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SurfaceSelector(
          bindings: bindings,
          active: _active,
          enabled: widget.enabled,
          onSelect: (surface) => setState(() => _active = surface),
        ),
        SizedBox(height: tokens.spacing.step4),
        // One picker, re-bound to the active surface. The ValueKey makes a
        // surface switch a fresh subtree so the selected-ring lands on the new
        // surface's variant immediately rather than animating from the old one.
        CelebrationVariantPicker(
          key: ValueKey(_active),
          enabled: widget.enabled,
          selected: active.variant,
          onSelect: active.onSelect,
        ),
      ],
    );
  }
}

/// The segmented surface picker. Each segment shows a content type and the style
/// currently assigned to it; tapping selects that surface for editing. Greyed
/// and inert when [enabled] is false.
class _SurfaceSelector extends StatelessWidget {
  const _SurfaceSelector({
    required this.bindings,
    required this.active,
    required this.onSelect,
    required this.enabled,
  });

  final List<_SurfaceBinding> bindings;
  final _CelebrationSurface active;
  final ValueChanged<_CelebrationSurface> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.surface.enabled,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: tokens.colors.decorative.level02),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step1),
            child: Row(
              children: [
                for (final binding in bindings)
                  Expanded(
                    child: _SurfaceSegment(
                      binding: binding,
                      selected: binding.surface == active,
                      onTap: () => onSelect(binding.surface),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment of the [_SurfaceSelector]: the content type's name over the
/// localized name of the style currently assigned to it.
class _SurfaceSegment extends StatelessWidget {
  const _SurfaceSegment({
    required this.binding,
    required this.selected,
    required this.onTap,
  });

  final _SurfaceBinding binding;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      selected: selected,
      label: binding.label,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step2,
              vertical: tokens.spacing.step2,
            ),
            child: Column(
              children: [
                Text(
                  binding.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: selected
                        ? tokens.colors.text.highEmphasis
                        : tokens.colors.text.mediumEmphasis,
                    fontWeight: selected
                        ? tokens.typography.weight.semiBold
                        : tokens.typography.weight.regular,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  celebrationVariantLabel(context, binding.variant),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: selected ? accent : tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
