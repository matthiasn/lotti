import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_hero_banner.dart';
import 'package:lotti/features/whats_new/ui/whats_new_navigation_footer.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
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

  /// Builds a styled link with classic blue underline and pointer cursor.
  static Widget _buildLink(
    BuildContext context,
    InlineSpan text,
    String url,
    TextStyle style,
  ) {
    const linkColor = Colors.blue;
    return InkWell(
      onTap: () => handleMarkdownLinkTap(url, ''),
      mouseCursor: SystemMouseCursors.click,
      child: Text.rich(
        TextSpan(
          children: [text],
          style: style.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ),
      ),
    );
  }

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
  ///
  /// Visible for testing so the regex edge cases (no images, empty
  /// markdown, data URIs) can be unit-tested without driving precaching.
  @visibleForTesting
  static Iterable<String> extractImageUrls(String markdown) {
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
              onError: (_, _) {}, // Ignore failures silently
            ),
          );
        }

        // Extract and precache images from markdown content
        final allMarkdown = [
          release.headerMarkdown,
          ...release.sections,
        ].join();
        for (final imageUrl in extractImageUrls(allMarkdown)) {
          unawaited(
            precacheImage(
              NetworkImage(imageUrl),
              context,
              onError: (_, _) {}, // Ignore failures silently
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

    // Use a darker barrier for better visual separation
    final barrierColor = isDark
        ? Colors.black.withValues(alpha: 0.75)
        : context.colorScheme.outline.withValues(alpha: 0.5);

    await WoltModalSheet.show<void>(
      context: context,
      useRootNavigator: ModalUtils.shouldUseRootNavigatorForBottomSheet(
        context,
      ),
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
      modalBarrierColor: barrierColor,
      modalDecorator: (child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: child,
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
      heroImage: HeroBanner(
        imageUrl: content.bannerImageUrl,
        version: content.release.version,
        isLatest: isLatest,
      ),
      heroImageHeight: bannerHeight,
      stickyActionBar: NavigationFooter(
        totalReleases: totalReleases,
        currentRelease: currentIndex,
        colorScheme: colorScheme,
        onNavigate: (index) => pageNotifier.value = index,
        onMarkAllSeen: onMarkAllSeen,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minContentHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
          child: SelectionArea(
            child: GptMarkdown(
              allContent,
              onLinkTap: handleMarkdownLinkTap,
              linkBuilder: _buildLink,
            ),
          ),
        ),
      ),
    );
  }
}

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
    final width = availableSize.width > maxWidth
        ? maxWidth
        : availableSize.width * 0.9;
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
