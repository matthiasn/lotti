import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Standard content layout for modern cards
///
/// Provides a consistent layout structure with:
/// - Leading widget (optional)
/// - Title and subtitle
/// - Trailing widget (optional)
/// - Proper spacing and typography
class ModernCardContent extends StatelessWidget {
  const ModernCardContent({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isCompact = false,
    this.subtitleWidget,
    this.titleStyle,
    this.subtitleStyle,
    this.maxTitleLines = 1,
    this.maxSubtitleLines,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool isCompact;
  final Widget? subtitleWidget;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final int maxTitleLines;
  final int? maxSubtitleLines;

  @override
  Widget build(BuildContext context) {
    final effectiveMaxSubtitleLines = maxSubtitleLines ?? (isCompact ? 1 : 2);

    return Row(
      children: [
        // Leading widget
        if (leading != null) ...[
          leading!,
          SizedBox(
            width: isCompact ? AppTheme.spacingMedium : AppTheme.spacingLarge,
          ),
        ],

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                title,
                style: titleStyle ??
                    context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppTheme.letterSpacingTitle,
                      fontSize: isCompact
                          ? AppTheme.titleFontSizeCompact
                          : AppTheme.titleFontSize,
                      color: context.colorScheme.onSurface,
                    ),
                maxLines: maxTitleLines,
                overflow: TextOverflow.ellipsis,
              ),

              // Subtitle or custom subtitle widget
              if (subtitleWidget != null) ...[
                SizedBox(
                  height: isCompact
                      ? AppTheme.spacingBetweenTitleAndSubtitleCompact
                      : AppTheme.spacingBetweenTitleAndSubtitle,
                ),
                subtitleWidget!,
              ] else if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(
                  height: isCompact
                      ? AppTheme.spacingBetweenTitleAndSubtitleCompact
                      : AppTheme.spacingBetweenTitleAndSubtitle,
                ),
                Text(
                  subtitle!,
                  style: subtitleStyle ??
                      context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant
                            .withValues(alpha: AppTheme.alphaSurfaceVariant),
                        fontSize: isCompact
                            ? AppTheme.subtitleFontSizeCompact
                            : AppTheme.subtitleFontSize,
                        height: AppTheme.lineHeightSubtitle,
                        letterSpacing: AppTheme.letterSpacingSubtitle,
                      ),
                  maxLines: effectiveMaxSubtitleLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Trailing widget
        if (trailing != null) ...[
          SizedBox(
            width: isCompact ? AppTheme.spacingSmall : AppTheme.spacingMedium,
          ),
          trailing!,
        ],
      ],
    );
  }
}
