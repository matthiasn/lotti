import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
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
/// [DsSegmentedToggle] above it — the same shared segmented control the Time
/// Analysis and Daily OS switches use, so the radii and selected fill line up.
///
/// Greyed and inert when [enabled] is false (the master switch is off).
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
        // The shared design-system segmented control, dimmed and inert while the
        // master switch is off. `expand` spreads the three surfaces evenly.
        Opacity(
          opacity: widget.enabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !widget.enabled,
            child: DsSegmentedToggle<_CelebrationSurface>(
              expand: true,
              selected: _active,
              onChanged: (surface) => setState(() => _active = surface),
              segments: [
                for (final binding in bindings)
                  DsSegment(binding.surface, binding.label),
              ],
            ),
          ),
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
