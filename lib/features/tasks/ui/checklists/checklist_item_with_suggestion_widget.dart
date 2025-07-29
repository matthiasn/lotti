import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';

class ChecklistItemWithSuggestionWidget extends ConsumerStatefulWidget {
  const ChecklistItemWithSuggestionWidget({
    required this.itemId,
    required this.taskId,
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.onTitleChange,
    this.showEditIcon = true,
    this.readOnly = false,
    this.onEdit,
    super.key,
  });

  final String itemId;
  final String taskId;
  final String title;
  final bool readOnly;
  final bool isChecked;
  final bool showEditIcon;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
  final StringCallback? onTitleChange;

  @override
  ConsumerState<ChecklistItemWithSuggestionWidget> createState() =>
      _ChecklistItemWithSuggestionWidgetState();
}

class _ChecklistItemWithSuggestionWidgetState
    extends ConsumerState<ChecklistItemWithSuggestionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completionService = ref.watch(checklistCompletionServiceProvider);
    final suggestion = completionService.whenOrNull(
      data: (suggestions) => suggestions
          .firstWhereOrNull((s) => s.checklistItemId == widget.itemId),
    );

    // Start pulsing animation if there's a suggestion
    if (suggestion != null && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (suggestion == null && _animationController.isAnimating) {
      _animationController
        ..stop()
        ..reset();
    }

    return Stack(
      children: [
        ChecklistItemWidget(
          title: widget.title,
          isChecked: widget.isChecked,
          onChanged: (checked) {
            widget.onChanged(checked);
            // Clear suggestion if user manually changes the state
            if (suggestion != null) {
              ref
                  .read(checklistCompletionServiceProvider.notifier)
                  .clearSuggestion(widget.itemId);
            }
          },
          onTitleChange: widget.onTitleChange,
          showEditIcon: widget.showEditIcon,
          readOnly: widget.readOnly,
          onEdit: widget.onEdit,
        ),
        if (suggestion != null)
          Positioned(
            left: 8,
            top: 8,
            bottom: 8,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () {
                  _showSuggestionDialog(context, suggestion);
                },
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(suggestion.confidence),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getConfidenceColor(ChecklistCompletionConfidence confidence) {
    final colorScheme = context.colorScheme;
    switch (confidence) {
      case ChecklistCompletionConfidence.high:
        return colorScheme.primary;
      case ChecklistCompletionConfidence.medium:
        return colorScheme.secondary;
      case ChecklistCompletionConfidence.low:
        return colorScheme.tertiary;
    }
  }

  void _showSuggestionDialog(
    BuildContext context,
    ChecklistCompletionSuggestion suggestion,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AI Suggestion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This item appears to be completed:',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(suggestion.reason),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.insights,
                    size: 16,
                    color: _getConfidenceColor(suggestion.confidence),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Confidence: ${suggestion.confidence.name}',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            LottiTertiaryButton(
              label: context.messages.cancelButton,
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(checklistCompletionServiceProvider.notifier)
                    .clearSuggestion(widget.itemId);
              },
            ),
            LottiPrimaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onChanged(true);
                ref
                    .read(checklistCompletionServiceProvider.notifier)
                    .clearSuggestion(widget.itemId);
              },
              label: 'Mark Complete',
              icon: Icons.check_circle,
            ),
          ],
        );
      },
    );
  }
}
