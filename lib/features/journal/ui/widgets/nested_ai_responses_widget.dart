import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays AI responses linked to an entry (e.g., audio) in a collapsible
/// nested tree view.
///
/// This widget creates a visual hierarchy showing that AI responses belong
/// to the parent entry, similar to comment threads or nested replies.
///
/// Features:
/// - Only renders if AI responses exist (completely hidden otherwise)
/// - Collapsible section with smooth animation
/// - Indented visual style to indicate nesting
/// - Shows count of AI responses in the header
class NestedAiResponsesWidget extends ConsumerStatefulWidget {
  const NestedAiResponsesWidget({
    required this.parentEntryId,
    required this.linkedFromEntity,
    super.key,
  });

  /// The ID of the parent entry (e.g., audio entry) to fetch linked AI responses for.
  final String parentEntryId;

  /// The parent entity that AI responses are linked from (used for context in AI response display).
  final JournalEntity linkedFromEntity;

  @override
  ConsumerState<NestedAiResponsesWidget> createState() =>
      _NestedAiResponsesWidgetState();
}

class _NestedAiResponsesWidgetState
    extends ConsumerState<NestedAiResponsesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;
  bool _isExpanded = true; // Default to expanded so users see the responses

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start expanded
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncAiResponses = ref.watch(
      linkedAiResponsesControllerProvider(entryId: widget.parentEntryId),
    );

    return asyncAiResponses.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (aiResponses) {
        // Don't render anything if no AI responses exist
        if (aiResponses.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildNestedSection(context, aiResponses);
      },
    );
  }

  Widget _buildNestedSection(
    BuildContext context,
    List<AiResponseEntry> aiResponses,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingSmall,
        top: AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nested connector line and content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical connector line
              _buildConnectorLine(context, aiResponses.length),
              const SizedBox(width: AppTheme.spacingSmall),
              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Collapsible header
                    _buildHeader(context, aiResponses.length),
                    // Animated content
                    SizeTransition(
                      sizeFactor: _expandAnimation,
                      axisAlignment: -1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppTheme.spacingXSmall),
                          ...aiResponses.map(
                            (response) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.spacingSmall,
                              ),
                              child: _buildAiResponseCard(context, response),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorLine(BuildContext context, int responseCount) {
    final colorScheme = context.colorScheme;

    return SizedBox(
      width: 16,
      child: Column(
        children: [
          // Horizontal line connecting to parent
          Container(
            width: 16,
            height: 12,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 2,
                ),
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingXSmall,
          horizontal: AppTheme.spacingXSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_fix_high_outlined,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              context.messages.nestedAiResponsesTitle(count),
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            RotationTransition(
              turns: _rotationAnimation,
              child: Icon(
                Icons.expand_more,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiResponseCard(BuildContext context, AiResponseEntry response) {
    return AiResponseSummary(
      response,
      linkedFromId: widget.linkedFromEntity.meta.id,
      fadeOut: false,
    );
  }
}
