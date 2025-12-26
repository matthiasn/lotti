import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lotti/services/dev_logger.dart';

/// Mixin for managing entry highlight animations and scroll-to-entry with retry logic.
///
/// Provides:
/// - Temporary highlight animation after scrolling to an entry
/// - Retry logic for scrolling to entries that may not be rendered yet
/// - Proper cleanup of timers and state on disposal
mixin HighlightScrollMixin<T extends StatefulWidget> on State<T> {
  // Tunable timings (override in the host State if needed)
  // Keep scroll highlight visible long enough for multi-pulse sequences (4x1200ms)
  Duration get highlightDuration => const Duration(milliseconds: 4800);
  Duration get scrollDuration => const Duration(milliseconds: 300);

  // Check if we're in a test environment
  static bool get _isTestMode {
    // In tests, Platform.environment is usually minimal
    return Platform.environment['FLUTTER_TEST'] == 'true';
  }

  // Give first-load renders ample time (linked entries + layouts). In tests, shorten to speed up.
  int get maxScrollRetries => _isTestMode ? 5 : 30;
  Duration get scrollRetryDelay => _isTestMode
      ? const Duration(milliseconds: 50)
      : const Duration(milliseconds: 100);
  // Initial delay before first attempt to let heavy subtrees mount.
  // Longer delay for navigation from calendar to ensure page fully renders.
  // In tests, no delay.
  Duration get initialScrollDelay =>
      _isTestMode ? Duration.zero : const Duration(milliseconds: 800);

  // State
  String? _highlightedEntryId;
  Timer? _highlightTimer;
  Timer? _retryTimer;
  bool _disposed = false;
  String? _scrollingToEntryId;

  /// The currently highlighted entry ID (used for temporary scroll highlights)
  String? get highlightedEntryId => _highlightedEntryId;

  /// Set the highlighted entry ID (for testing purposes only - use scrollToEntry in production code)
  @visibleForTesting
  set highlightedEntryId(String? value) => _highlightedEntryId = value;

  /// Disposes of highlight-related resources. Call this from your widget's dispose().
  void disposeHighlight() {
    _disposed = true;
    _highlightTimer?.cancel();
    _retryTimer?.cancel();
  }

  /// Scrolls to an entry and triggers a temporary highlight animation.
  ///
  /// [entryId] - The ID of the entry to scroll to
  /// [alignment] - Scroll alignment (0.0 = top, 1.0 = bottom)
  /// [onScrolled] - Optional callback invoked immediately (used to clear focus intent)
  /// [isInitialLoad] - Whether this is the first load (navigation from another page)
  void scrollToEntry(
    String entryId,
    double alignment, {
    required GlobalKey Function(String) getEntryKey,
    VoidCallback? onScrolled,
    bool isInitialLoad = false,
  }) {
    // Prevent duplicate concurrent scroll operations to the same entry
    if (_scrollingToEntryId == entryId) return;

    // Use longer delay for initial load (navigation from calendar)
    // Shorter delay for subsequent scrolls on already-rendered page
    final delay =
        isInitialLoad ? initialScrollDelay : const Duration(milliseconds: 100);

    // Attempt to scroll with an appropriate delay
    _scrollingToEntryId = entryId;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _scrollToEntryWithRetry(
        entryId,
        alignment,
        getEntryKey: getEntryKey,
        attempt: 0,
        onScrolled: onScrolled,
      );
    });
  }

  void _scrollToEntryWithRetry(
    String entryId,
    double alignment, {
    required GlobalKey Function(String) getEntryKey,
    required int attempt,
    VoidCallback? onScrolled,
  }) {
    // Guard: bail out if this retry is for a stale scroll operation
    if (_scrollingToEntryId != entryId) return;

    if (_disposed) {
      _scrollingToEntryId = null;
      // Clear intent on terminal failure if requested
      onScrolled?.call();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;

      // Guard: bail out if a newer scroll operation has started
      if (_scrollingToEntryId != entryId) return;

      final key = getEntryKey(entryId);
      final context = key.currentContext;

      if (context != null) {
        try {
          await Scrollable.ensureVisible(
            context,
            alignment: alignment,
            duration: scrollDuration,
            curve: Curves.easeInOut,
          );

          // Trigger highlight animation after scroll completes
          if (mounted && !_disposed) {
            setState(() {
              _highlightedEntryId = entryId;
            });

            // Clear highlight after duration
            _highlightTimer?.cancel();
            _highlightTimer = Timer(highlightDuration, () {
              if (mounted && !_disposed) {
                setState(() {
                  _highlightedEntryId = null;
                });
              }
            });
          }
          _scrollingToEntryId = null;
          _retryTimer?.cancel();
          // Clear intent on success if requested
          onScrolled?.call();
        } catch (e) {
          DevLogger.warning(
            name: 'HighlightScrollMixin',
            message: 'Failed to scroll to entry $entryId: $e',
          );
          _scrollingToEntryId = null;
          _retryTimer?.cancel();
          // Treat exception as terminal and clear intent if requested
          onScrolled?.call();
        }
      } else if (attempt < maxScrollRetries - 1) {
        // Entry not found, schedule retry
        _retryTimer?.cancel();
        _retryTimer = Timer(scrollRetryDelay, () {
          _scrollToEntryWithRetry(
            entryId,
            alignment,
            getEntryKey: getEntryKey,
            attempt: attempt + 1,
            onScrolled: onScrolled,
          );
        });
      } else {
        // Final attempt failed - log warning and clear state
        DevLogger.warning(
          name: 'HighlightScrollMixin',
          message:
              'Failed to scroll to entry $entryId after $maxScrollRetries attempts',
        );
        _scrollingToEntryId = null;
        _retryTimer?.cancel();
        // Final attempt failed: clear intent if requested
        onScrolled?.call();
      }
    });
  }
}
