import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/theme.dart';

/// A styled text field component that matches the AI Settings design language
class AiTextField extends StatefulWidget {
  const AiTextField({
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.initialValue,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    super.key,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? initialValue;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  State<AiTextField> createState() => _AiTextFieldState();
}

class _AiTextFieldState extends State<AiTextField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  String? _errorText;

  void _setErrorText(String? next) {
    if (next == _errorText) return;
    setState(() => _errorText = next);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    // Validate initial value (no setState needed before first build)
    final value = widget.controller?.text ?? widget.initialValue;
    _errorText = widget.validator?.call(value);
  }

  @override
  void didUpdateWidget(AiTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-validate only when relevant inputs change
    if (oldWidget.validator != widget.validator ||
        oldWidget.controller?.text != widget.controller?.text ||
        oldWidget.initialValue != widget.initialValue) {
      _validateCurrentValue();
    }
  }

  void _validateCurrentValue() {
    final value = widget.controller?.text ?? widget.initialValue;
    _setErrorText(widget.validator?.call(value));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasError
                  ? context.colorScheme.error
                  : context.colorScheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Text Field
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                if (hasError)
                  context.colorScheme.errorContainer.withValues(alpha: 0.2)
                else if (_isFocused)
                  context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.5)
                else
                  context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                if (hasError)
                  context.colorScheme.errorContainer.withValues(alpha: 0.1)
                else if (_isFocused)
                  context.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4)
                else
                  context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? context.colorScheme.error.withValues(alpha: 0.7)
                  : _isFocused
                      ? context.colorScheme.primary.withValues(alpha: 0.5)
                      : context.colorScheme.primaryContainer
                          .withValues(alpha: 0.2),
              width: hasError || _isFocused ? 1.5 : 1,
            ),
            boxShadow: hasError
                ? [
                    BoxShadow(
                      color: context.colorScheme.error.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : _isFocused
                    ? [
                        BoxShadow(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            initialValue:
                widget.controller == null ? widget.initialValue : null,
            onChanged: (value) {
              widget.onChanged?.call(value);
              _setErrorText(widget.validator?.call(value));
            },
            enabled: widget.enabled,
            obscureText: widget.obscureText,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            style: TextStyle(
              color: widget.enabled
                  ? context.colorScheme.onSurface
                  : context.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color:
                    context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: hasError
                          ? context.colorScheme.error
                          : _isFocused
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                    )
                  : null,
              suffixIcon: widget.suffixIcon,
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? 12 : 16,
                vertical: (widget.maxLines ?? 1) > 1 ? 12 : 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        // Error text
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: context.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
