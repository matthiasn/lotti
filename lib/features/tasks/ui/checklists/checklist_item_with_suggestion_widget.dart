import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

class ChecklistItemWithSuggestionWidget extends ConsumerStatefulWidget {
  const ChecklistItemWithSuggestionWidget({
    required this.itemId,
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.hideCompleted = false,
    this.onTitleChange,
    this.showEditIcon = true,
    this.readOnly = false,
    this.onEdit,
    this.index = 0,
    super.key,
  });

  final String itemId;
  final String title;
  final bool readOnly;
  final bool isChecked;
  final bool hideCompleted;
  final bool showEditIcon;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
  final StringCallback? onTitleChange;

  /// Index in the list for ReorderableDragStartListener.
  final int index;

  @override
  ConsumerState<ChecklistItemWithSuggestionWidget> createState() =>
      _ChecklistItemWithSuggestionWidgetState();
}

class _ChecklistItemWithSuggestionWidgetState
    extends ConsumerState<ChecklistItemWithSuggestionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _showRow = true;
  Timer? _holdTimer;

  bool get _shouldHide => widget.hideCompleted && widget.isChecked;
  bool _lastHideCompleted = false;
  bool _lastIsChecked = false;

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

    _lastHideCompleted = widget.hideCompleted;
    _lastIsChecked = widget.isChecked;
    _showRow = !_shouldHide;
  }

  @override
  void didUpdateWidget(ChecklistItemWithSuggestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasHideCompleted = _lastHideCompleted;
    final wasChecked = _lastIsChecked;
    final isHideCompleted = widget.hideCompleted;
    final isChecked = widget.isChecked;

    _lastHideCompleted = isHideCompleted;
    _lastIsChecked = isChecked;

    // Case 1: item just got completed while hideCompleted is true
    // (Open-only mode, user just checked the box).
    if (!wasChecked && isChecked && isHideCompleted) {
      _cancelTimers();
      _startHideSequence();
      return;
    }

    // Case 2: filter toggled to hide completed items while this item was already
    // completed. We hide it immediately without playing the completion fanfare.
    if (!wasHideCompleted && isHideCompleted && isChecked) {
      _cancelTimers();
      setState(() {
        _showRow = false;
      });
      return;
    }

    // Case 3: filter toggled back to show all items.
    if (wasHideCompleted && !isHideCompleted) {
      _cancelTimers();
      setState(() {
        _showRow = true;
      });
      return;
    }

    // Case 4: item was unchecked again.
    if (wasChecked && !isChecked) {
      _cancelTimers();
      setState(() {
        _showRow = true;
      });
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    _animationController.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _startHideSequence() {
    if (!_shouldHide) return;

    _holdTimer = Timer(checklistCompletionAnimationDuration, () {
      if (!mounted || !_shouldHide) return;

      setState(() {
        _showRow = false;
      });
    });
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

    final content = Stack(
      children: [
        ChecklistItemWidget(
          title: widget.title,
          isChecked: widget.isChecked,
          index: widget.index,
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

    if (widget.hideCompleted) {
      return AnimatedCrossFade(
        duration: checklistCompletionFadeDuration,
        sizeCurve: Curves.easeInOut,
        crossFadeState:
            _showRow ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: content,
        secondChild: const SizedBox.shrink(),
      );
    }

    return content;
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
