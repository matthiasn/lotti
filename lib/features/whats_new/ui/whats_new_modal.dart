import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Modal that displays "What's New" content for all unseen releases.
///
/// Features an editorial magazine-style design with:
/// - 21:9 hero banner (fixed header)
/// - Scrollable markdown content
/// - Navigation footer with indicator dots
class WhatsNewModal extends ConsumerStatefulWidget {
  const WhatsNewModal({super.key});

  /// Shows the What's New modal.
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const WhatsNewModal(),
    );
  }

  @override
  ConsumerState<WhatsNewModal> createState() => _WhatsNewModalState();
}

class _WhatsNewModalState extends ConsumerState<WhatsNewModal> {
  final _pageIndexNotifier = ValueNotifier<int>(0);
  WhatsNewController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ref.read(whatsNewControllerProvider.notifier);
  }

  @override
  void dispose() {
    _pageIndexNotifier.dispose();
    _controller?.markAllAsSeen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final whatsNewAsync = ref.watch(whatsNewControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return whatsNewAsync.when(
      data: (state) {
        final releases = state.unseenContent;
        if (releases.isEmpty) {
          return _buildEmptyDialog(context, isDark);
        }

        return _buildReleasesModal(context, releases, isDark);
      },
      loading: () => _buildLoadingDialog(context, isDark),
      error: (e, _) => _buildErrorDialog(context, e, isDark),
    );
  }

  Widget _buildEmptyDialog(BuildContext context, bool isDark) {
    return Dialog(
      backgroundColor: ModalUtils.getModalBackgroundColor(context),
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

  Widget _buildLoadingDialog(BuildContext context, bool isDark) {
    return Dialog(
      backgroundColor: ModalUtils.getModalBackgroundColor(context),
      child: const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorDialog(BuildContext context, Object error, bool isDark) {
    return Dialog(
      backgroundColor: ModalUtils.getModalBackgroundColor(context),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('Error loading content: $error'),
      ),
    );
  }

  Widget _buildReleasesModal(
    BuildContext context,
    List<WhatsNewContent> releases,
    bool isDark,
  ) {
    final colorScheme = context.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= WoltModalConfig.pageBreakpoint;

    // Calculate modal dimensions
    final modalHeight = (screenHeight * 0.85).clamp(500.0, screenHeight * 0.9);
    final modalWidth = isWide ? 500.0 : screenWidth;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: modalWidth,
        height: modalHeight,
        decoration: BoxDecoration(
          color: ModalUtils.getModalBackgroundColor(context),
          borderRadius: isWide ? BorderRadius.circular(16) : null,
        ),
        child: ClipRRect(
          borderRadius: isWide ? BorderRadius.circular(16) : BorderRadius.zero,
          child: ValueListenableBuilder<int>(
            valueListenable: _pageIndexNotifier,
            builder: (context, currentIndex, _) {
              final content = releases[currentIndex];
              final allContent = [
                content.headerMarkdown,
                ...content.sections,
              ].join('\n');

              return Column(
                children: [
                  // Hero banner (fixed header)
                  _HeroBanner(
                    imageUrl: content.bannerImageUrl,
                    version: content.release.version,
                    isLatest: currentIndex == 0,
                  ),

                  // Scrollable markdown content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: SelectionArea(
                        child: GptMarkdown(allContent),
                      ),
                    ),
                  ),

                  // Navigation footer (sticky)
                  if (releases.length > 1)
                    _NavigationFooter(
                      totalReleases: releases.length,
                      currentRelease: currentIndex,
                      colorScheme: colorScheme,
                      onNavigate: (index) => _pageIndexNotifier.value = index,
                    ),
                ],
              );
            },
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
    required this.colorScheme,
    required this.onNavigate,
  });

  final int totalReleases;
  final int currentRelease;
  final ColorScheme colorScheme;
  final ValueChanged<int> onNavigate;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left arrow (newer)
              _NavigationArrow(
                icon: Icons.chevron_left,
                isVisible: canGoNewer,
                onTap: () => onNavigate(currentRelease - 1),
                tooltip: 'Newer release',
                colorScheme: colorScheme,
              ),

              // Indicator dots
              _IndicatorDots(
                total: totalReleases,
                current: currentRelease,
                colorScheme: colorScheme,
              ),

              // Right arrow (older)
              _NavigationArrow(
                icon: Icons.chevron_right,
                isVisible: canGoOlder,
                onTap: () => onNavigate(currentRelease + 1),
                tooltip: 'Older release',
                colorScheme: colorScheme,
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
