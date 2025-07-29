import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';

enum AiButtonStyle { primary, secondary, text }

/// A styled button component that matches the AI Settings design language
class AiFormButton extends StatelessWidget {
  const AiFormButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AiButtonStyle.primary,
    this.isLoading = false,
    this.enabled = true,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AiButtonStyle style;
  final bool isLoading;
  final bool enabled;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onPressed != null && !isLoading;

    Widget button;

    switch (style) {
      case AiButtonStyle.primary:
        button = _buildPrimaryButton(context, isEnabled);
      case AiButtonStyle.secondary:
        button = _buildSecondaryButton(context, isEnabled);
      case AiButtonStyle.text:
        button = _buildTextButton(context, isEnabled);
    }

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  Widget _buildPrimaryButton(BuildContext context, bool isEnabled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: [
                  context.colorScheme.primary,
                  context.colorScheme.primary.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isEnabled ? null : context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: context.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildButtonContent(
              context,
              color: isEnabled
                  ? context.colorScheme.onPrimary
                  : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, bool isEnabled) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? context.colorScheme.primary.withValues(alpha: 0.3)
              : context.colorScheme.primaryContainer.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildButtonContent(
              context,
              color: isEnabled
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextButton(BuildContext context, bool isEnabled) {
    return LottiTertiaryButton(
      label: label,
      onPressed: isEnabled ? onPressed : null,
      icon: icon,
    );
  }

  Widget _buildButtonContent(BuildContext context, {required Color color}) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    return content;
  }
}
