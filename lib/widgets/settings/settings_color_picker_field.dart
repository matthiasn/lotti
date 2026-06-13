import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Shared color field for settings editors (category, label).
///
/// One interaction model for one property: the field renders as a
/// [SettingsPickerField] with a leading swatch and a human-readable
/// value — the matching palette name from [labelColorPresets] (matched
/// case-insensitively on the CSS hex) or the localized "Custom" label
/// when no preset matches. Raw hex never surfaces in the field; it
/// stays behind the picker. Tapping opens a single shared modal
/// hosting the full flex_color_picker (preset swatches + wheel) which
/// applies every change live through [onColorChanged], so the hosting
/// form's dirty tracking works exactly as with an inline picker.
class SettingsColorPickerField extends StatelessWidget {
  const SettingsColorPickerField({
    required this.onColorChanged,
    this.color,
    this.label,
    this.semanticsLabel,
    super.key,
  });

  /// Currently selected color; when null the field shows the
  /// "Select a color" hint and no swatch.
  final Color? color;

  /// Called for every color change inside the picker modal (live
  /// apply) — the hosting editor marks its form dirty through this.
  final ValueChanged<Color> onColorChanged;

  /// Field label above the row. Omit when the field is the sole
  /// content of a section whose header already names it; pass
  /// [semanticsLabel] instead so assistive tech still hears the name.
  final String? label;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final selected = color;

    return SettingsPickerField(
      label: label,
      semanticsLabel: semanticsLabel,
      valueText: selected != null ? _valueText(context, selected) : null,
      hintText: context.messages.selectColor,
      leading: selected != null
          ? Container(
              width: tokens.spacing.step6,
              height: tokens.spacing.step6,
              decoration: BoxDecoration(
                color: selected,
                borderRadius: BorderRadius.circular(tokens.radii.xs),
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
            )
          : null,
      onTap: () => _showColorPickerModal(context),
    );
  }

  /// The palette name whose hex matches [selected] case-insensitively
  /// (preset names are palette proper nouns, not localized), or the
  /// localized "Custom" label when no preset matches.
  String _valueText(BuildContext context, Color selected) {
    final hex = colorToCssHex(selected).toUpperCase();
    for (final preset in labelColorPresets) {
      if (preset.hex.toUpperCase() == hex) return preset.name;
    }
    return context.messages.colorCustomLabel;
  }

  void _showColorPickerModal(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.selectColor,
      builder: (modalContext) => ColorPicker(
        color: color ?? theme.colorScheme.primary,
        onColorChanged: onColorChanged,
        selectedPickerTypeColor: theme.colorScheme.primary,
        pickersEnabled: const <ColorPickerType, bool>{
          ColorPickerType.custom: true,
          ColorPickerType.wheel: true,
          ColorPickerType.accent: false,
          ColorPickerType.primary: true,
          ColorPickerType.bw: false,
          ColorPickerType.both: false,
        },
        customColorSwatchesAndNames: {
          for (final preset in labelColorPresets)
            ColorTools.createPrimarySwatch(
              colorFromCssHex(preset.hex, substitute: Colors.blue),
            ): preset.name,
        },
        pickerTypeLabels: <ColorPickerType, String>{
          ColorPickerType.custom:
              modalContext.messages.settingsLabelsColorSubheading,
          ColorPickerType.wheel: modalContext.messages.customColor,
        },
        colorNameTextStyle: tokens.typography.styles.body.bodySmall,
      ),
    );
  }
}
