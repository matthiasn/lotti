import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One choice in a [CompanionSwatchRow]: its value, the colour it shows, and
/// what a screen reader calls it.
typedef CompanionSwatch<T> = ({T value, Color colour, String label});

/// A row of round colour swatches to pick one from — her skin tone, her hair
/// colour. The picked one wears a ring, and a hovered or focused one a thin
/// one; each is a [TapTargets.minimum] target and says its name and whether
/// it is selected to a screen reader.
///
/// The swatches are illustration colours, hers, not interface colours; the
/// ring and the gaps are the design system's.
class CompanionSwatchRow<T> extends StatelessWidget {
  const CompanionSwatchRow({
    required this.swatches,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<CompanionSwatch<T>> swatches;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final swatch in swatches)
          Semantics(
            button: true,
            selected: swatch.value == selected,
            label: swatch.label,
            onTap: () => onSelected(swatch.value),
            excludeSemantics: true,
            child: DsQuietInk(
              key: ValueKey('companionSwatch-${swatch.value}'),
              customBorder: const CircleBorder(),
              onTap: () => onSelected(swatch.value),
              builder: (context, highlighted) {
                final picked = swatch.value == selected;
                return SizedBox.square(
                  dimension: TapTargets.minimum,
                  child: Center(
                    child: Container(
                      width: ControlSizes.iconChip,
                      height: ControlSizes.iconChip,
                      decoration: BoxDecoration(
                        color: swatch.colour,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: picked || highlighted
                              ? tokens.colors.interactive.enabled
                              : tokens.colors.decorative.level01,
                          width: picked
                              ? BorderWidths.emphasis
                              : BorderWidths.hairline,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
