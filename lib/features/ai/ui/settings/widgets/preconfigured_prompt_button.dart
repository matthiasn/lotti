import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/widgets/enhanced_preconfigured_prompt_modal.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Reusable button widget for selecting preconfigured prompts
///
/// This widget provides a beautiful, animated button that opens the
/// preconfigured prompt selection modal when tapped.
///
/// Features:
/// - Gradient background with subtle animation
/// - Hover and press states
/// - Icon and text with proper typography
/// - Callback for when a prompt is selected
class PreconfiguredPromptButton extends StatefulWidget {
  const PreconfiguredPromptButton({
    required this.onPromptSelected,
    super.key,
  });

  /// Callback when a preconfigured prompt is selected
  final ValueChanged<PreconfiguredPrompt> onPromptSelected;

  @override
  State<PreconfiguredPromptButton> createState() =>
      _PreconfiguredPromptButtonState();
}

class _PreconfiguredPromptButtonState extends State<PreconfiguredPromptButton>
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
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTap() {
    showEnhancedPreconfiguredPromptModal(
      context,
      widget.onPromptSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPressed
                ? [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    context.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  ]
                : [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    context.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.primary.withValues(
              alpha: _isPressed ? 0.3 : 0.2,
            ),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.primary.withValues(
                alpha: _isPressed ? 0.1 : 0.05,
              ),
              blurRadius: _isPressed ? 12 : 8,
              offset: Offset(0, _isPressed ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            borderRadius: BorderRadius.circular(12),
            splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            context.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: context.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.messages.promptUsePreconfiguredButton,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.messages
                              .enhancedPromptFormPreconfiguredPromptDescription,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()
                      ..translateByVector3(Vector3(_isPressed ? 2 : 0, 0, 0)),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color:
                          context.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
