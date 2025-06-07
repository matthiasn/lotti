import 'package:flutter/material.dart';
import 'package:formz/formz.dart';
import 'package:lotti/themes/theme.dart';

/// Enhanced form field widget with modern Series A startup styling
///
/// Features:
/// - Modern card-based design with subtle elevation
/// - Professional color scheme with proper contrast
/// - Enhanced visual hierarchy and spacing
/// - Floating labels with smooth animations
/// - Context-aware styling based on field state
/// - Professional error handling with smooth transitions
/// - Seamless integration with Formz validation
/// - Accessibility optimizations
class EnhancedFormField<T extends FormzInput<dynamic, dynamic>> extends StatefulWidget {
  const EnhancedFormField({
    required this.controller,
    required this.labelText,
    this.onChanged,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.formzField,
    this.customErrorText,
    this.suffixIcon,
    this.helperText,
    this.isRequired = false,
    this.prefixIcon,
    this.onTap,
    this.readOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final T? formzField;
  final String? customErrorText;
  final Widget? suffixIcon;
  final String? helperText;
  final bool isRequired;
  final Widget? prefixIcon;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  State<EnhancedFormField<T>> createState() => _EnhancedFormFieldState<T>();
}

class _EnhancedFormFieldState<T extends FormzInput<dynamic, dynamic>>
    extends State<EnhancedFormField<T>> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late AnimationController _errorAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _errorFadeAnimation;
  late Animation<Offset> _errorSlideAnimation;

  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _errorFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _errorAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _errorSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _errorAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _animationController.dispose();
    _errorAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EnhancedFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newHasError = _getErrorText() != null;
    if (newHasError != _hasError) {
      _hasError = newHasError;
      if (_hasError) {
        _errorAnimationController.forward();
      } else {
        _errorAnimationController.reverse();
      }
    }
  }

  /// Get error text from Formz field or custom error text
  String? _getErrorText() {
    // Priority: custom error text > Formz validation error
    if (widget.customErrorText != null && widget.customErrorText!.isNotEmpty) {
      return widget.customErrorText;
    }

    if (widget.formzField != null) {
      final field = widget.formzField!;
      if (field.isNotValid && !field.isPure) {
        // Convert Formz error to user-friendly message
        return _getFormzErrorMessage(field.error);
      }
    }

    return null;
  }

  /// Convert Formz error to user-friendly message
  String _getFormzErrorMessage(Object? error) {
    // This can be customized based on your error types
    if (error == null) return '';

    // Handle common validation errors
    switch (error.toString()) {
      case 'ProviderFormError.tooShort':
        return 'This field is too short';
      case 'ProviderFormError.empty':
        return 'This field is required';
      case 'ProviderFormError.invalidUrl':
        return 'Please enter a valid URL';
      default:
        return error.toString();
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });

      if (_isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorText = _getErrorText();
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required indicator
        if (widget.labelText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  widget.labelText,
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        context.colorScheme.onSurface.withValues(alpha: 0.87),
                  ),
                ),
                if (widget.isRequired)
                  Text(
                    ' *',
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),

        // Main input field container
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? context.colorScheme.error
                        : _isFocused
                            ? context.colorScheme.primary
                            : context.colorScheme.outline
                                .withValues(alpha: 0.2),
                    width: hasError || _isFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_isFocused)
                      BoxShadow(
                        color:
                            context.colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    BoxShadow(
                      color: context.colorScheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  obscureText: widget.obscureText,
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                  onTap: widget.onTap,
                  readOnly: widget.readOnly,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter ${widget.labelText.toLowerCase()}',
                    hintStyle: context.textTheme.bodyLarge?.copyWith(
                      color:
                          context.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: widget.prefixIcon != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16, right: 12),
                            child: IconTheme(
                              data: IconThemeData(
                                color: _isFocused
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                size: 20,
                              ),
                              child: widget.prefixIcon!,
                            ),
                          )
                        : null,
                    suffixIcon: widget.suffixIcon != null
                        ? Padding(
                            padding: const EdgeInsets.only(right: 16, left: 12),
                            child: IconTheme(
                              data: IconThemeData(
                                color: context.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                size: 20,
                              ),
                              child: widget.suffixIcon!,
                            ),
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefixIcon != null ? 8 : 16,
                      vertical: widget.maxLines != null && widget.maxLines! > 1
                          ? 16
                          : 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
            );
          },
        ),

        // Error message with animation
        if (hasError)
          SlideTransition(
            position: _errorSlideAnimation,
            child: FadeTransition(
              opacity: _errorFadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: context.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorText,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Helper text
        if (widget.helperText != null && !hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              widget.helperText!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

/// Enhanced dropdown/selection field with modern styling
class EnhancedSelectionField extends StatefulWidget {
  const EnhancedSelectionField({
    required this.labelText,
    required this.value,
    required this.onTap,
    this.prefixIcon,
    this.isRequired = false,
    this.helperText,
    super.key,
  });

  final String labelText;
  final String value;
  final VoidCallback onTap;
  final Widget? prefixIcon;
  final bool isRequired;
  final String? helperText;

  @override
  State<EnhancedSelectionField> createState() => _EnhancedSelectionFieldState();
}

class _EnhancedSelectionFieldState extends State<EnhancedSelectionField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                widget.labelText,
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.87),
                ),
              ),
              if (widget.isRequired)
                Text(
                  ' *',
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),

        // Selection field container
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTapDown: (_) {
                  setState(() => _isPressed = true);
                  _animationController.forward();
                },
                onTapUp: (_) {
                  setState(() => _isPressed = false);
                  _animationController.reverse();
                  widget.onTap();
                },
                onTapCancel: () {
                  setState(() => _isPressed = false);
                  _animationController.reverse();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPressed
                          ? context.colorScheme.primary
                          : context.colorScheme.outline.withValues(alpha: 0.2),
                      width: _isPressed ? 2 : 1,
                    ),
                    boxShadow: [
                      if (_isPressed)
                        BoxShadow(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      BoxShadow(
                        color:
                            context.colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.prefixIcon != null ? 8 : 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            size: 20,
                          ),
                          child: widget.prefixIcon!,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          widget.value,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Helper text
        if (widget.helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              widget.helperText!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}
