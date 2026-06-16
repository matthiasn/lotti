import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// 21:9 hero banner with gradient overlay and version badge.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    required this.imageUrl,
    required this.version,
    required this.isLatest,
    super.key,
  });

  /// Network URL of the banner image; falls back to [_BannerFallback] when
  /// null or when the image fails to load.
  final String? imageUrl;

  /// Version string shown in the badge (rendered as `v$version`).
  final String version;

  /// Whether this is the newest release; when true the badge shows a gold
  /// "NEW" pill.
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Banner image or fallback
        if (imageUrl != null)
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _BannerFallback(),
          )
        else
          const _BannerFallback(),

        // Gradient overlay for text legibility
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.5),
              ],
              stops: const [0.3, 1.0],
            ),
          ),
        ),

        // Version badge (top-right)
        Positioned(
          right: 16,
          top: 16,
          child: _VersionBadge(
            version: version,
            isLatest: isLatest,
            primaryColor: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Fallback display when banner image is unavailable.
class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primaryContainer.withValues(alpha: 0.2),
                ]
              : [
                  colorScheme.primaryContainer.withValues(alpha: 0.5),
                  colorScheme.primary.withValues(alpha: 0.15),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          size: 48,
          color: colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Glassmorphism version badge with optional "NEW" indicator.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge({
    required this.version,
    required this.isLatest,
    required this.primaryColor,
  });

  final String version;
  final bool isLatest;
  final Color primaryColor;

  static const _goldAccent = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLatest) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _goldAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
              Text(
                'v$version',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  fontFeatures: numericBadgeFontFeatures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
