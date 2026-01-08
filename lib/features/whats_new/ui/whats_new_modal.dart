import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Modal that displays "What's New" content for all unseen releases.
///
/// Features an editorial magazine-style design with:
/// - 21:9 hero banner (in heroImage slot)
/// - Scrollable markdown content
/// - Navigation footer (in stickyActionBar)
class WhatsNewModal {
  WhatsNewModal._();

  /// Pattern to extract image URLs from markdown: ![alt](url)
  static final _imageUrlPattern = RegExp(r'!\[[^\]]*\]\((https?://[^)]+)\)');

  /// Custom modal type builder that allows taller dialogs (90% of screen).
  static WoltModalType _modalTypeBuilder(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width < WoltModalConfig.pageBreakpoint) {
      return WoltModalType.bottomSheet();
    } else {
      return const _TallDialogType();
    }
  }

  /// Extracts all image URLs from markdown content.
  static Iterable<String> _extractImageUrls(String markdown) {
    return _imageUrlPattern.allMatches(markdown).map((m) => m.group(1)!);
  }

  /// Shows the What's New modal.
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final state = await ref.read(whatsNewControllerProvider.future);
    final releases = state.unseenContent;

    if (releases.isEmpty) {
      if (!context.mounted) return;
      await _showEmptyModal(context, ref);
      return;
    }

    // Precache all images for smooth page transitions
    if (context.mounted) {
      for (final release in releases) {
        // Banner image
        final bannerUrl = release.bannerImageUrl;
        if (bannerUrl != null) {
          unawaited(
            precacheImage(
              NetworkImage(bannerUrl),
              context,
              onError: (_, __) {}, // Ignore failures silently
            ),
          );
        }

        // Extract and precache images from markdown content
        final allMarkdown =
            [release.headerMarkdown, ...release.sections].join();
        for (final imageUrl in _extractImageUrls(allMarkdown)) {
          unawaited(
            precacheImage(
              NetworkImage(imageUrl),
              context,
              onError: (_, __) {}, // Ignore failures silently
            ),
          );
        }
      }
    }

    final pageNotifier = ValueNotifier<int>(0);
    // Track the highest page index viewed (starts at 0 since first page is shown)
    var maxViewedIndex = 0;
    pageNotifier.addListener(() {
      if (pageNotifier.value > maxViewedIndex) {
        maxViewedIndex = pageNotifier.value;
      }
    });

    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Helper to mark viewed releases as seen
    Future<void> markViewedAsSeen() async {
      final controller = ref.read(whatsNewControllerProvider.notifier);
      for (var i = 0; i <= maxViewedIndex && i < releases.length; i++) {
        await controller.markAsSeen(releases[i].release.version);
      }
    }

    // Track if "Done" was pressed to mark all as seen
    var markAllOnClose = false;

    if (!context.mounted) return;
    await WoltModalSheet.show<void>(
      context: context,
      pageIndexNotifier: pageNotifier,
      pageListBuilder: (modalContext) {
        final screenWidth = MediaQuery.of(modalContext).size.width;
        final isWide = screenWidth >= WoltModalConfig.pageBreakpoint;
        final modalWidth = isWide ? 500.0 : screenWidth;
        final bannerHeight = modalWidth * (9 / 21);

        return [
          for (int i = 0; i < releases.length; i++)
            _buildReleasePage(
              context: modalContext,
              content: releases[i],
              isLatest: i == 0,
              bannerHeight: bannerHeight,
              currentIndex: i,
              totalReleases: releases.length,
              pageNotifier: pageNotifier,
              onMarkAllSeen: () {
                markAllOnClose = true;
                Navigator.of(modalContext).pop();
              },
            ),
        ];
      },
      modalTypeBuilder: _modalTypeBuilder,
      barrierDismissible: true,
      modalBarrierColor: ModalUtils.getModalBarrierColor(
        isDark: isDark,
        context: context,
      ),
      onModalDismissedWithDrag: () {
        unawaited(markViewedAsSeen());
      },
    );

    // Mark releases as seen when modal closes
    if (markAllOnClose) {
      // "Done" was pressed - mark all releases as seen
      await ref.read(whatsNewControllerProvider.notifier).markAllAsSeen();
    } else {
      // Normal close - only mark viewed releases
      await markViewedAsSeen();
    }
  }

  static Future<void> _showEmptyModal(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;

    return ModalUtils.showSinglePageModal(
      context: context,
      hasTopBarLayer: false,
      showCloseButton: false,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      builder: (modalContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No new updates to show',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              await ref
                  .read(whatsNewControllerProvider.notifier)
                  .resetSeenStatus();
              if (!modalContext.mounted) return;
              Navigator.of(modalContext).pop();
              if (!context.mounted) return;
              // Re-show modal with all releases now visible
              await show(context, ref);
            },
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('View past releases'),
          ),
        ],
      ),
    );
  }

  static WoltModalSheetPage _buildReleasePage({
    required BuildContext context,
    required WhatsNewContent content,
    required bool isLatest,
    required double bannerHeight,
    required int currentIndex,
    required int totalReleases,
    required ValueNotifier<int> pageNotifier,
    required VoidCallback onMarkAllSeen,
  }) {
    final colorScheme = context.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final allContent = [
      content.headerMarkdown,
      ...content.sections,
    ].join('\n');

    // Minimum content height: 50% of screen minus banner and footer
    final minContentHeight = (screenHeight * 0.5) - bannerHeight - 56;

    return WoltModalSheetPage(
      hasTopBarLayer: false,
      backgroundColor: ModalUtils.getModalBackgroundColor(context),
      heroImage: _HeroBanner(
        imageUrl: content.bannerImageUrl,
        version: content.release.version,
        isLatest: isLatest,
      ),
      heroImageHeight: bannerHeight,
      stickyActionBar: _NavigationFooter(
        totalReleases: totalReleases,
        currentRelease: currentIndex,
        colorScheme: colorScheme,
        onNavigate: (index) => pageNotifier.value = index,
        onMarkAllSeen: onMarkAllSeen,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minContentHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: SelectionArea(
            child: GptMarkdown(allContent),
          ),
        ),
      ),
    );
  }
}

/// 21:9 hero banner with gradient overlay and version badge.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.imageUrl,
    required this.version,
    required this.isLatest,
  });

  final String? imageUrl;
  final String version;
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
            errorBuilder: (_, __, ___) => _BannerFallback(version: version),
          )
        else
          _BannerFallback(version: version),

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
  const _BannerFallback({required this.version});

  final String version;

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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism navigation footer with animated indicator dots.
class _NavigationFooter extends StatelessWidget {
  const _NavigationFooter({
    required this.totalReleases,
    required this.currentRelease,
    required this.colorScheme,
    required this.onNavigate,
    required this.onMarkAllSeen,
  });

  final int totalReleases;
  final int currentRelease;
  final ColorScheme colorScheme;
  final ValueChanged<int> onNavigate;
  final VoidCallback onMarkAllSeen;

  @override
  Widget build(BuildContext context) {
    final canGoNewer = currentRelease > 0;
    final canGoOlder = currentRelease < totalReleases - 1;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Skip button (marks all as seen and closes)
              SizedBox(
                width: 64,
                child: TextButton(
                  onPressed: onMarkAllSeen,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // Left arrow (newer)
              _NavigationArrow(
                icon: Icons.chevron_left,
                isVisible: canGoNewer,
                onTap: () => onNavigate(currentRelease - 1),
                tooltip: 'Newer release',
                colorScheme: colorScheme,
              ),

              // Indicator dots (centered)
              Expanded(
                child: Center(
                  child: _IndicatorDots(
                    total: totalReleases,
                    current: currentRelease,
                    colorScheme: colorScheme,
                  ),
                ),
              ),

              // Right arrow (older)
              _NavigationArrow(
                icon: Icons.chevron_right,
                isVisible: canGoOlder,
                onTap: () => onNavigate(currentRelease + 1),
                tooltip: 'Older release',
                colorScheme: colorScheme,
              ),

              // Spacer to balance Skip button on left
              const SizedBox(width: 64),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation arrow button with animated visibility.
class _NavigationArrow extends StatelessWidget {
  const _NavigationArrow({
    required this.icon,
    required this.isVisible,
    required this.onTap,
    required this.tooltip,
    required this.colorScheme,
  });

  final IconData icon;
  final bool isVisible;
  final VoidCallback onTap;
  final String tooltip;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1.0 : 0.0,
        child: isVisible
            ? IconButton(
                icon: Icon(icon),
                onPressed: onTap,
                tooltip: tooltip,
                color: colorScheme.primary,
                iconSize: 28,
              )
            : null,
      ),
    );
  }
}

/// Animated indicator dots showing current position in releases.
class _IndicatorDots extends StatelessWidget {
  const _IndicatorDots({
    required this.total,
    required this.current,
    required this.colorScheme,
  });

  final int total;
  final int current;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index == current;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

/// Custom dialog type that allows configurable max height (90% of screen).
class _TallDialogType extends WoltModalType {
  const _TallDialogType()
      : super(
          shapeBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          showDragHandle: false,
          dismissDirection: WoltModalDismissDirection.down,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 350),
        );

  static const double _maxHeightFraction = 0.9;

  @override
  String routeLabel(BuildContext context) {
    return MaterialLocalizations.of(context).dialogLabel;
  }

  @override
  BoxConstraints layoutModal(Size availableSize) {
    const maxWidth = 500.0;
    final width =
        availableSize.width > maxWidth ? maxWidth : availableSize.width * 0.9;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: availableSize.height * _maxHeightFraction,
    );
  }

  @override
  Offset positionModal(
    Size availableSize,
    Size modalContentSize,
    TextDirection textDirection,
  ) {
    // Center horizontally and vertically
    final xOffset = (availableSize.width - modalContentSize.width) / 2;
    final yOffset = (availableSize.height - modalContentSize.height) / 2;
    return Offset(xOffset, yOffset);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
