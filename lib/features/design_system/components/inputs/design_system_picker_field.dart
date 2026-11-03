import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A field whose value is picked rather than typed — a category, a date:
/// the text input's own label above a box of the same shape, height, fill
/// and border, holding an optional [leading] mark, the value (or the
/// [placeholder] in the hint ink) and a trailing [trailingIcon] that says a
/// picker opens. Beside text inputs it keeps one field silhouette, so a form
/// reads as one column of the same kind of thing.
///
/// [onTap] opens the picker; null shows the value without the affordance of
/// a change — a host still reading the current one.
class DesignSystemPickerField extends StatefulWidget {
  const DesignSystemPickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.leading,
    this.trailingIcon = LottiIcons.chevronDown,
    this.fieldKey,
    this.trailingKey,
    this.filled = true,
    super.key,
  });

  final String label;

  /// The picked value; null shows [placeholder].
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final Widget? leading;
  final IconData trailingIcon;

  /// Identity for the tappable box itself.
  final Key? fieldKey;

  /// Identity for the trailing glyph.
  final Key? trailingKey;

  /// [DesignSystemTextInput.filled]'s rule: false inside a modal sheet, so
  /// the sheet's raised surface shows through and the hairline alone frames
  /// the field, as the sheet's text inputs are framed.
  final bool filled;

  @override
  State<DesignSystemPickerField> createState() =>
      _DesignSystemPickerFieldState();
}

class _DesignSystemPickerFieldState extends State<DesignSystemPickerField> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onTap != null;
    final radius = BorderRadius.circular(tokens.radii.l);
    final value = widget.value;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${widget.label}: ${value ?? widget.placeholder}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: widget.fieldKey,
              borderRadius: radius,
              onTap: widget.onTap,
              onHover: (hovered) => setState(() => _hovered = hovered),
              child: Ink(
                decoration: BoxDecoration(
                  color: widget.filled
                      ? tokens.colors.background.level01
                      : Colors.transparent,
                  borderRadius: radius,
                  border: Border.all(
                    color: designSystemFieldBorderColor(
                      tokens,
                      hovered: _hovered && enabled,
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: tokens.spacing.step9),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step4,
                      vertical: tokens.spacing.step2,
                    ),
                    child: Row(
                      children: [
                        // One square slot, whatever the mark, so every picked
                        // value in a column starts on the same line.
                        if (widget.leading case final leading?) ...[
                          SizedBox.square(
                            dimension: IconSizes.l,
                            child: Center(child: leading),
                          ),
                          SizedBox(width: tokens.spacing.step3),
                        ],
                        Expanded(
                          child: Text(
                            value ?? widget.placeholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(
                                  color: value == null
                                      ? tokens.colors.text.lowEmphasis
                                      : tokens.colors.text.highEmphasis,
                                ),
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Icon(
                          widget.trailingIcon,
                          key: widget.trailingKey,
                          size: IconSizes.m,
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
