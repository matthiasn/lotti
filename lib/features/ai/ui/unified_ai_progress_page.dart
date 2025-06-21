import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/ai_progress_sticky_bar.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Creates a WoltModalSheetPage for AI progress with scroll control
WoltModalSheetPage unifiedAiProgressPage({
  required BuildContext context,
  required String entityId,
  required String promptId,
  required String promptName,
  required void Function() onBack,
}) {
  final scrollController = ScrollController(
    initialScrollOffset: 1111,
    keepScrollOffset: false,
  );

  return WoltModalSheetPage(
    scrollController: scrollController,
    stickyActionBar: AiProgressStickyBar(
      entityId: entityId,
      promptId: promptId,
      onTap: () {
        print('scrollController.hasClients ${scrollController.hasClients}');
        // Scroll to bottom when tapped
        //if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        //}
      },
    ),
    topBarTitle: Text(
      promptName,
      style: context.textTheme.titleSmall,
    ),
    isTopBarLayerAlwaysVisible: true,
    leadingNavBarWidget: IconButton(
      padding: WoltModalConfig.pagePadding,
      icon: const Icon(Icons.arrow_back),
      onPressed: onBack,
    ),
    trailingNavBarWidget: IconButton(
      padding: WoltModalConfig.pagePadding,
      icon: const Icon(Icons.close),
      onPressed: Navigator.of(context).pop,
    ),
    child: _UnifiedAiProgressContent(
      entityId: entityId,
      promptId: promptId,
      scrollController: scrollController,
    ),
  );
}

/// Content widget for AI progress with custom scroll control
class _UnifiedAiProgressContent extends ConsumerStatefulWidget {
  const _UnifiedAiProgressContent({
    required this.entityId,
    required this.promptId,
    required this.scrollController,
  });

  final String entityId;
  final String promptId;
  final ScrollController scrollController;

  @override
  ConsumerState<_UnifiedAiProgressContent> createState() =>
      _UnifiedAiProgressContentState();
}

class _UnifiedAiProgressContentState
    extends ConsumerState<_UnifiedAiProgressContent> {
  Timer? _scrollTimer;

  void _startScrollTimer() {
    _stopScrollTimer();
    // Scroll to bottom every 200ms while running
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _stopScrollTimer() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  @override
  void dispose() {
    _stopScrollTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promptConfigAsync = ref.watch(
      aiConfigByIdProvider(widget.promptId),
    );

    return promptConfigAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colorScheme.primary.withValues(alpha: 0.3),
                      context.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading configuration...',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: context.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading prompt',
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (config) {
        if (config == null || config is! AiConfigPrompt) {
          return const Center(child: Text('Invalid prompt configuration'));
        }

        final promptConfig = config;
        final state = ref.watch(
          unifiedAiControllerProvider(
            entityId: widget.entityId,
            promptId: widget.promptId,
          ),
        );

        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider(
            id: widget.entityId,
            aiResponseType: promptConfig.aiResponseType,
          ),
        );

        // Manage scroll timer based on inference status
        if (inferenceStatus == InferenceStatus.running) {
          if (_scrollTimer == null || !_scrollTimer!.isActive) {
            _startScrollTimer();
          }
        } else {
          _stopScrollTimer();
        }

        final isError = inferenceStatus == InferenceStatus.error;

        // If there's an error, try to parse it as an InferenceError
        if (isError) {
          try {
            final inferenceError = AiErrorUtils.categorizeError(state);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: AiErrorDisplay(
                error: inferenceError,
                onRetry: () {
                  ref.invalidate(
                    unifiedAiControllerProvider(
                      entityId: widget.entityId,
                      promptId: widget.promptId,
                    ),
                  );
                },
              ),
            );
          } catch (_) {
            // Fall back to text display
          }
        }

        // Return simple content without decoration
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SelectionArea(
            child: Text(
              state.isEmpty ? '' : state,
              style: monospaceTextStyleSmall.copyWith(
                fontWeight: FontWeight.w400,
                fontSize: 13,
                height: 1.5,
                color: context.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        );
      },
    );
  }
}
