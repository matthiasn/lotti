import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Modal that displays "What's New" content for all unseen releases.
///
/// Users can swipe between releases (newest first) to catch up on updates
/// they may have missed. Features an editorial magazine-style design with
/// 21:9 hero banners and refined typography.
class WhatsNewModal extends ConsumerStatefulWidget {
  const WhatsNewModal({super.key});

  /// Shows the What's New modal.
  static Future<void> show(BuildContext context) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      hasTopBarLayer: false,
      showCloseButton: false,
      padding: EdgeInsets.zero,
      builder: (modalContext) => const WhatsNewModal(),
    );
  }

  @override
  ConsumerState<WhatsNewModal> createState() => _WhatsNewModalState();
}

class _WhatsNewModalState extends ConsumerState<WhatsNewModal> {
  late PageController _pageController;
  int _currentRelease = 0;
  WhatsNewController? _controller;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save controller reference for use in dispose
    _controller = ref.read(whatsNewControllerProvider.notifier);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Mark all as seen when modal is dismissed
    _controller?.markAllAsSeen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final whatsNewAsync = ref.watch(whatsNewControllerProvider);

    return whatsNewAsync.when(
      data: (state) {
        final releases = state.unseenContent;
        if (releases.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No new updates'),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(whatsNewControllerProvider.notifier).resetSeenStatus();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Show all releases'),
                  ),
                ],
              ),
            ),
          );
        }

        return _WhatsNewReleases(
          releases: releases,
          pageController: _pageController,
          currentRelease: _currentRelease,
          onReleaseChanged: (index) => setState(() => _currentRelease = index),
        );
      },
      loading: () => const SizedBox(
        height: 500,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Error loading content: $e'),
        ),
      ),
    );
  }
}

class _WhatsNewReleases extends StatelessWidget {
  const _WhatsNewReleases({
    required this.releases,
    required this.pageController,
    required this.currentRelease,
    required this.onReleaseChanged,
  });

  final List<WhatsNewContent> releases;
  final PageController pageController;
  final int currentRelease;
  final ValueChanged<int> onReleaseChanged;

  @override
  Widget build(BuildContext context) {
    // Use 70% of screen height, capped between 500 and 700
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = (screenHeight * 0.7).clamp(500.0, 700.0);

    return SizedBox(
      height: modalHeight,
      child: Column(
        children: [
          // Release content (swipable between releases)
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: releases.length,
              onPageChanged: onReleaseChanged,
              itemBuilder: (context, index) {
                return _ReleaseCard(
                  content: releases[index],
                  isLatest: index == 0,
                );
              },
            ),
          ),

          // Navigation footer with glassmorphism
          if (releases.length > 1)
            _NavigationFooter(
              totalReleases: releases.length,
              currentRelease: currentRelease,
              onNavigate: (index) {
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutQuart,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A single release card with hero banner, metadata, and content.
class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.content,
    required this.isLatest,
  });

  final WhatsNewContent content;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    // Combine header and all sections into single scrollable content
    final allContent = [content.headerMarkdown, ...content.sections].join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero banner with gradient overlay
        _HeroBanner(
          imageUrl: content.bannerImageUrl,
          version: content.release.version,
          isLatest: isLatest,
        )
            .animate()
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .slideY(begin: -0.03, end: 0, duration: 500.ms),

        // Scrollable markdown content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: SelectionArea(
              child: GptMarkdown(allContent),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        ),
      ],
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

    return AspectRatio(
      aspectRatio: 21 / 9,
      child: Stack(
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
      ),
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
    required this.onNavigate,
  });

  final int totalReleases;
  final int currentRelease;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left arrow (newer)
              _NavigationArrow(
                icon: Icons.chevron_left,
                isVisible: canGoNewer,
                onTap: () => onNavigate(currentRelease - 1),
                tooltip: 'Newer release',
              ),

              // Indicator dots
              _IndicatorDots(
                total: totalReleases,
                current: currentRelease,
              ),

              // Right arrow (older)
              _NavigationArrow(
                icon: Icons.chevron_right,
                isVisible: canGoOlder,
                onTap: () => onNavigate(currentRelease + 1),
                tooltip: 'Older release',
              ),
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
  });

  final IconData icon;
  final bool isVisible;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

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
  });

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

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
