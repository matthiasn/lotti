import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';

class ChatModalPage extends ConsumerWidget {
  const ChatModalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        // Get the selected category ID if only one is selected
        final selectedCategoryIds = state.selectedCategoryIds;
        final categoryId =
            selectedCategoryIds.length == 1 ? selectedCategoryIds.first : null;

        // Read streaming status for ambient glow (only when a category is set)
        final isStreaming = categoryId != null &&
            ref.watch(chatSessionControllerProvider(categoryId)
                .select((s) => s.isStreaming));

        Widget innerContent;
        if (categoryId == null) {
          innerContent = Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please select a single category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The AI assistant needs a specific category context to help you with tasks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else {
          innerContent = ChatInterface(categoryId: categoryId);
        }

        final panel = _AmbientPulseBorder(
          isActive: isStreaming,
          child: Material(
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 880,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: innerContent,
              ),
            ),
          ),
        );

        // Provide the bottom sheet with finite height; center the panel.
        final sheetHeight = MediaQuery.of(context).size.height * 0.85;
        return SizedBox(
          height: sheetHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: panel,
            ),
          ),
        );
      },
    );
  }
}

/// Subtle, sinusoidal 1px brand-accent border pulse around the panel while
/// streaming is active.
class _AmbientPulseBorder extends StatefulWidget {
  const _AmbientPulseBorder({
    required this.child,
    required this.isActive,
  });

  final Widget child;
  final bool isActive;

  @override
  State<_AmbientPulseBorder> createState() => _AmbientPulseBorderState();
}

class _AmbientPulseBorderState extends State<_AmbientPulseBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // slightly faster loop
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AmbientPulseBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sinusoidal pulse 0..1
        final t = _controller.isAnimating ? _controller.value : 0.0;
        final sine = 0.5 - 0.5 * math.cos(2 * math.pi * t);
        // Subtle but visible overlay stroke alpha (~0.12–0.20 while active).
        final overlayAlpha = widget.isActive ? (0.12 + 0.08 * sine) : 0.0;
        final overlayColor =
            theme.colorScheme.primary.withValues(alpha: overlayAlpha);
        // Reduced halo size and intensity
        final glow1Blur = widget.isActive ? (6.0 + 10.0 * sine) : 0.0; // 6–16
        final glow1Spread =
            widget.isActive ? (0.5 + 1.5 * sine) : 0.0; // 0.5–2.0
        final glow1Alpha =
            widget.isActive ? (0.1 + 0.1 * sine) : 0.0; // 0.18–0.28
        final glow2Blur = widget.isActive ? (3.0 + 7.0 * sine) : 0.0; // 3–10
        final glow2Spread =
            widget.isActive ? (0.25 + 0.75 * sine) : 0.0; // 0.25–1.0
        final glow2Alpha =
            widget.isActive ? (0.10 + 0.06 * sine) : 0.0; // 0.10–0.16

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary
                          .withValues(alpha: glow1Alpha),
                      blurRadius: glow1Blur,
                      spreadRadius: glow1Spread,
                    ),
                    BoxShadow(
                      color: theme.colorScheme.primary
                          .withValues(alpha: glow2Alpha),
                      blurRadius: glow2Blur,
                      spreadRadius: glow2Spread,
                    ),
                  ]
                : null,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: overlayAlpha > 0
                ? Border.all(color: overlayColor, width: 2)
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
