import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Mixin for managing entry highlight animations and scroll-to-entry with retry logic.
///
/// Provides:
/// - Temporary highlight animation after scrolling to an entry
/// - Retry logic for scrolling to entries that may not be rendered yet
/// - Proper cleanup of timers and state on disposal
mixin HighlightScrollMixin<T extends StatefulWidget> on State<T> {
  // Constants
  static const _highlightDuration = Duration(seconds: 2);
  static const _scrollDuration = Duration(milliseconds: 300);
  static const _maxScrollRetries = 5;

  // State
  String? _highlightedEntryId;
  Timer? _highlightTimer;
  bool _disposed = false;
  String? _scrollingToEntryId;

  /// The currently highlighted entry ID (used for temporary scroll highlights)
  String? get highlightedEntryId => _highlightedEntryId;

  /// Set the highlighted entry ID (typically not called directly - use scrollToEntry)
  set highlightedEntryId(String? value) => _highlightedEntryId = value;

  /// Disposes of highlight-related resources. Call this from your widget's dispose().
  void disposeHighlight() {
    _disposed = true;
    _highlightTimer?.cancel();
  }

  /// Scrolls to an entry and triggers a temporary highlight animation.
  ///
  /// [entryId] - The ID of the entry to scroll to
  /// [alignment] - Scroll alignment (0.0 = top, 1.0 = bottom)
  /// [onScrolled] - Optional callback invoked immediately (used to clear focus intent)
  void scrollToEntry(
    String entryId,
    double alignment, {
    required GlobalKey Function(String) getEntryKey,
    VoidCallback? onScrolled,
  }) {
    // Clear focus intent immediately on next frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      onScrolled?.call();
    });

    // Prevent duplicate concurrent scroll operations to the same entry
    if (_scrollingToEntryId == entryId) return;

    // Attempt to scroll with retry logic
    _scrollingToEntryId = entryId;
    _scrollToEntryWithRetry(
      entryId,
      alignment,
      getEntryKey: getEntryKey,
      attempt: 0,
    );
  }

  void _scrollToEntryWithRetry(
    String entryId,
    double alignment, {
    required GlobalKey Function(String) getEntryKey,
    required int attempt,
  }) {
    if (_disposed || attempt >= _maxScrollRetries) {
      _scrollingToEntryId = null;
      if (attempt >= _maxScrollRetries) {
        debugPrint(
          'Failed to scroll to entry $entryId after $_maxScrollRetries attempts',
        );
      }
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;

      final key = getEntryKey(entryId);
      final context = key.currentContext;

      if (context != null) {
        try {
          await Scrollable.ensureVisible(
            context,
            alignment: alignment,
            duration: _scrollDuration,
            curve: Curves.easeInOut,
          );

          // Trigger highlight animation after scroll completes
          if (mounted && !_disposed) {
            setState(() {
              _highlightedEntryId = entryId;
            });

            // Clear highlight after duration
            _highlightTimer?.cancel();
            _highlightTimer = Timer(_highlightDuration, () {
              if (mounted && !_disposed) {
                setState(() {
                  _highlightedEntryId = null;
                });
              }
            });
          }
          _scrollingToEntryId = null;
        } catch (e) {
          debugPrint('Failed to scroll to entry $entryId: $e');
          _scrollingToEntryId = null;
        }
      } else if (attempt < _maxScrollRetries) {
        // Entry not found, schedule retry
        _scrollToEntryWithRetry(
          entryId,
          alignment,
          getEntryKey: getEntryKey,
          attempt: attempt + 1,
        );
      }
    });
  }
}
