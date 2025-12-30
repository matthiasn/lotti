import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

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

  /// Key for the header widget - used for testing
  static const headerKey = Key('nested_ai_responses_header');

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

  /// Whether the section is expanded - derived from animation controller.
  bool get _isExpanded =>
      _animationController.status == AnimationStatus.completed ||
      _animationController.status == AnimationStatus.forward;

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
    if (_isExpanded) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAiResponses = ref.watch(
      linkedAiResponsesControllerProvider(widget.parentEntryId),
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
              _buildConnectorLine(context),
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

  Widget _buildConnectorLine(BuildContext context) {
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
      key: NestedAiResponsesWidget.headerKey,
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
    final colorScheme = context.colorScheme;

    return Dismissible(
      key: Key(response.meta.id),
      dismissThresholds: const {DismissDirection.endToStart: 0.25},
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndDelete(context, response.meta.id),
      background: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ColoredBox(
            color: colorScheme.error,
            child: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      child: AiResponseSummary(
        response,
        linkedFromId: widget.linkedFromEntity.meta.id,
        fadeOut: false,
      ),
    );
  }

  /// Confirms deletion with the user and performs the delete operation.
  /// Returns true only if the user confirmed AND the delete succeeded.
  Future<bool> _confirmAndDelete(
    BuildContext context,
    String responseId,
  ) async {
    // Capture context values before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorMessage = context.messages.aiResponseDeleteError;
    final errorColor = context.colorScheme.error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.messages.aiResponseDeleteTitle),
          content: Text(dialogContext.messages.aiResponseDeleteWarning),
          actions: [
            LottiTertiaryButton(
              label: dialogContext.messages.aiResponseDeleteCancel,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            LottiTertiaryButton(
              label: dialogContext.messages.aiResponseDeleteConfirm,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              isDestructive: true,
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    // Perform the delete and only dismiss if successful
    try {
      final success = await ref
          .read(journalRepositoryProvider)
          .deleteJournalEntity(responseId);

      if (!success && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
          ),
        );
      }
      return success;
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
          ),
        );
      }
      return false;
    }
  }
}
