import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A styled dropdown field component that matches the AI Settings design language
class AiDropdownField<T> extends StatefulWidget {
  const AiDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.validator,
    this.prefixIcon,
    super.key,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool enabled;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;

  @override
  State<AiDropdownField<T>> createState() => _AiDropdownFieldState<T>();
}

class _AiDropdownFieldState<T> extends State<AiDropdownField<T>> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
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
              color: context.colorScheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Dropdown Field
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                if (_isOpen)
                  context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.5)
                else
                  context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                if (_isOpen)
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
              color: _isOpen
                  ? context.colorScheme.primary.withValues(alpha: 0.5)
                  : context.colorScheme.primaryContainer.withValues(alpha: 0.2),
              width: _isOpen ? 1.5 : 1,
            ),
            boxShadow: _isOpen
                ? [
                    BoxShadow(
                      color: context.colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: DropdownButtonFormField<T>(
            value: widget.value,
            items: widget.items,
            onChanged: widget.enabled ? widget.onChanged : null,
            validator: widget.validator,
            onTap: () {
              setState(() {
                _isOpen = true;
              });
            },
            style: TextStyle(
              color: widget.enabled
                  ? context.colorScheme.onSurface
                  : context.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: context.colorScheme.surfaceContainerHighest,
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
                      color: _isOpen
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                    )
                  : null,
              suffixIcon: Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color:
                    context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? 12 : 16,
                vertical: 14,
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
      ],
    );
  }

  @override
  void didUpdateWidget(covariant AiDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _isOpen) {
      // Close dropdown when value changes externally
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isOpen = false;
        });
      });
    }
  }
}
