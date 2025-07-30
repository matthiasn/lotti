import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/theme.dart';

/// A reusable text field widget that follows the Lotti design system
///
/// This widget provides a consistent text input experience across the app
/// with support for labels, hints, prefixes, validation, and more.
class LottiTextField extends StatelessWidget {
  const LottiTextField({
    required this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.style,
    this.fillColor,
    this.borderRadius,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autocorrect;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final TextStyle? style;
  final Color? fillColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveBorderRadius = borderRadius ?? 12.0;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autocorrect: autocorrect,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      validator: validator,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      focusNode: focusNode,
      style: style ??
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.5),
          ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  prefixIcon,
                  size: 20,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              )
            : prefix,
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  suffixIcon,
                  size: 20,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              )
            : suffix,
        filled: true,
        fillColor: fillColor ??
            (enabled
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.1)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        helperStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        errorStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.error,
        ),
      ),
    );
  }
}

/// A specialized text field for multiline input
class LottiTextArea extends StatelessWidget {
  const LottiTextArea({
    required this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.fillColor,
    this.borderRadius,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final Color? fillColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return LottiTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      validator: validator,
      focusNode: focusNode,
      fillColor: fillColor,
      borderRadius: borderRadius,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
    );
  }
}
