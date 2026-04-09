import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/countdown_snackbar_content.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Duration for the archive SnackBar countdown.
const kChecklistArchiveDuration = Duration(seconds: 2);

/// Duration for the delete SnackBar countdown.
const kChecklistDeleteDuration = Duration(seconds: 5);

/// A single checklist item row, provider-aware and using the new visual design.
///
/// Replaces the old `ChecklistItemWrapper` + `ChecklistItemWidget` +
/// `ChecklistItemWithSuggestionWidget` stack.
///
/// Features:
/// - Watches its own [checklistItemControllerProvider] for live updates.
/// - Swipe right → archive/unarchive; swipe left → delete with undo.
/// - Long-press (mobile) or drag-handle drag for cross-checklist moves via
///   `super_drag_and_drop`.
/// - [ReorderableDragStartListener] on the drag handle for within-list reorder.
/// - AI completion suggestion pulsing indicator.
/// - Animated hide when filter is "open only" and item is completed/archived.
class ChecklistItemRow extends ConsumerStatefulWidget {
  const ChecklistItemRow({
    required this.itemId,
    required this.checklistId,
    required this.taskId,
    required this.index,
    this.hideIfChecked = false,
    this.showDivider = false,
    super.key,
  });

  final String itemId;
  final String checklistId;
  final String taskId;
  final int index;

  /// When true, completed/archived items animate out after a short hold.
  final bool hideIfChecked;

  /// Whether to show a divider below this row.
  final bool showDivider;

  @override
  ConsumerState<ChecklistItemRow> createState() => _ChecklistItemRowState();
}

class _ChecklistItemRowState extends ConsumerState<ChecklistItemRow>
    with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  bool _showRow = true;
  Timer? _holdTimer;
  Timer? _deleteTimer;

  late AnimationController _suggestionController;
  late Animation<double> _suggestionPulse;

  bool _lastHideIfChecked = false;
  bool _lastIsChecked = false;
  bool _lastIsArchived = false;

  @override
  void initState() {
    super.initState();
    _lastHideIfChecked = widget.hideIfChecked;
    _suggestionController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _suggestionPulse = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _suggestionController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ChecklistItemRow old) {
    super.didUpdateWidget(old);
    // React to parent-driven filter changes (hideIfChecked prop).
    if (old.hideIfChecked != widget.hideIfChecked) {
      _handleHideStateChange(
        newHideIfChecked: widget.hideIfChecked,
        newIsChecked: _lastIsChecked,
        newIsArchived: _lastIsArchived,
      );
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _deleteTimer?.cancel();
    _suggestionController.dispose();
    super.dispose();
  }

  bool get _shouldHide =>
      widget.hideIfChecked && (_lastIsChecked || _lastIsArchived);

  void _cancelTimers() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _startHideSequence() {
    if (!_shouldHide) return;
    _holdTimer = Timer(checklistCompletionAnimationDuration, () {
      if (!mounted || !_shouldHide) return;
      setState(() => _showRow = false);
    });
  }

  void _handleHideStateChange({
    required bool newHideIfChecked,
    required bool newIsChecked,
    required bool newIsArchived,
  }) {
    final wasHideChecked = _lastHideIfChecked;
    final wasChecked = _lastIsChecked;
    final wasArchived = _lastIsArchived;

    _lastHideIfChecked = newHideIfChecked;
    _lastIsChecked = newIsChecked;
    _lastIsArchived = newIsArchived;

    // Item just got completed/archived while filter hides them — fade then hide.
    if ((!wasChecked && newIsChecked && newHideIfChecked) ||
        (!wasArchived && newIsArchived && newHideIfChecked)) {
      _cancelTimers();
      _startHideSequence();
      return;
    }

    // Filter toggled to hide completed items for an already completed item.
    if (!wasHideChecked &&
        newHideIfChecked &&
        (newIsChecked || newIsArchived)) {
      _cancelTimers();
      setState(() => _showRow = false);
      return;
    }

    // Filter toggled back to show all.
    if (wasHideChecked && !newHideIfChecked) {
      _cancelTimers();
      setState(() => _showRow = true);
      return;
    }

    // Item unchecked or unarchived.
    if ((wasChecked && !newIsChecked) || (wasArchived && !newIsArchived)) {
      _cancelTimers();
      setState(() => _showRow = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = checklistItemControllerProvider((
      id: widget.itemId,
      taskId: widget.taskId,
    ));

    // React to actual data changes rather than every rebuild.
    ref.listen<AsyncValue<ChecklistItem?>>(provider, (previous, next) {
      if (!mounted) return;
      final item = next.whenOrNull(data: (item) => item);
      if (item == null) return;
      _handleHideStateChange(
        newHideIfChecked: widget.hideIfChecked,
        newIsChecked: item.data.isChecked,
        newIsArchived: item.data.isArchived,
      );
    });

    final itemAsync = ref.watch(provider);

    return itemAsync.map(
      data: (data) {
        final item = data.value;
        if (item == null || item.isDeleted) {
          return const SizedBox.shrink();
        }

        final itemNotifier = ref.read(provider.notifier);
        final checklistNotifier = ref.read(
          checklistControllerProvider((
            id: widget.checklistId,
            taskId: widget.taskId,
          )).notifier,
        );
        final messenger = ScaffoldMessenger.of(context);

        // AI suggestions
        final completionService = ref.watch(checklistCompletionServiceProvider);
        final suggestion = completionService.whenOrNull(
          data: (suggestions) => suggestions.firstWhereOrNull(
            (s) => s.checklistItemId == widget.itemId,
          ),
        );

        if (suggestion != null && !_suggestionController.isAnimating) {
          _suggestionController.repeat(reverse: true);
        } else if (suggestion == null && _suggestionController.isAnimating) {
          _suggestionController
            ..stop()
            ..reset();
        }

        final tokens = context.designTokens;
        final isStrikethrough = item.data.isChecked || item.data.isArchived;

        // Build the visual row content.
        Widget rowContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    // Drag handle — ReorderableDragStartListener for within-list
                    // reorder; DraggableWidget (below) handles cross-list.
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 24,
                        color: tokens.colors.text.lowEmphasis.withValues(
                          alpha: 0.32,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    // Checkbox
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: item.data.isChecked,
                        onChanged: item.data.isArchived
                            ? null
                            : (value) {
                                itemNotifier.updateChecked(
                                  checked: value ?? false,
                                );
                                if (suggestion != null) {
                                  ref
                                      .read(
                                        checklistCompletionServiceProvider
                                            .notifier,
                                      )
                                      .clearSuggestion(widget.itemId);
                                }
                              },
                        activeColor: tokens.colors.interactive.enabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(
                          color: tokens.colors.text.lowEmphasis,
                          width: 1.5,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    // Title — editable or display
                    Expanded(
                      child: _isEditing
                          ? TitleTextField(
                              initialValue: item.data.title,
                              onSave: (newTitle) {
                                if (newTitle != null &&
                                    newTitle.trim().isNotEmpty) {
                                  itemNotifier.updateTitle(newTitle.trim());
                                }
                                setState(() => _isEditing = false);
                              },
                              resetToInitialValue: true,
                              onCancel: () =>
                                  setState(() => _isEditing = false),
                            )
                          : Text(
                              item.data.title,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: isStrikethrough
                                        ? tokens.colors.text.lowEmphasis
                                        : tokens.colors.text.highEmphasis,
                                    decoration: isStrikethrough
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                              maxLines: 4,
                              overflow: TextOverflow.fade,
                            ),
                    ),
                    // Edit icon
                    if (!_isEditing)
                      GestureDetector(
                        onTap: () => setState(() => _isEditing = true),
                        child: Icon(
                          Icons.mode_edit_outlined,
                          size: 20,
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showDivider)
              Divider(
                height: 1,
                thickness: 1,
                color: tokens.colors.decorative.level01,
              ),
          ],
        );

        // Overlay AI suggestion pulsing bar on the left side.
        if (suggestion != null) {
          rowContent = Stack(
            children: [
              rowContent,
              Positioned(
                left: 0,
                top: tokens.spacing.step3,
                bottom: tokens.spacing.step3,
                child: AnimatedBuilder(
                  animation: _suggestionPulse,
                  builder: (context, child) => Transform.scale(
                    scale: _suggestionPulse.value,
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: () => _showSuggestionDialog(context, suggestion),
                    child: Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: _getSuggestionColor(suggestion.confidence),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Wrap in Dismissible for swipe actions.
        Widget child = Dismissible(
          key: Key('dismissible-${item.id}'),
          dismissThresholds: const {
            DismissDirection.endToStart: 0.25,
            DismissDirection.startToEnd: 0.25,
          },
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe right → toggle archive
              if (item.data.isArchived) {
                itemNotifier.unarchive();
              } else {
                itemNotifier.archive();
                showCountdownSnackBar(
                  messenger,
                  message: context.messages.checklistItemArchived,
                  duration: kChecklistArchiveDuration,
                  actionLabel: context.messages.checklistItemArchiveUndo,
                  onAction: () {
                    itemNotifier.unarchive();
                    messenger.hideCurrentSnackBar();
                  },
                );
              }
              return false;
            }
            // Swipe left → confirm delete
            return true;
          },
          onDismissed: (_) async {
            final deletedMessage = context.messages.checklistItemDeleted;
            final undoLabel = context.messages.checklistItemArchiveUndo;

            await checklistNotifier.unlinkItem(widget.itemId);

            _deleteTimer?.cancel();
            _deleteTimer = Timer(
              kChecklistDeleteDuration,
              () async => itemNotifier.delete(),
            );

            showCountdownSnackBar(
              messenger,
              message: deletedMessage,
              duration: kChecklistDeleteDuration,
              actionLabel: undoLabel,
              onAction: () {
                _deleteTimer?.cancel();
                _deleteTimer = null;
                checklistNotifier.relinkItem(widget.itemId);
                messenger.hideCurrentSnackBar();
              },
            );
          },
          background: ColoredBox(
            color: Colors.amber.shade700,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: tokens.spacing.step5),
                child: Icon(
                  item.data.isArchived ? Icons.unarchive : Icons.archive,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          secondaryBackground: ColoredBox(
            color: Colors.red,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: tokens.spacing.step5),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
          child: rowContent,
        );

        // Wrap in super_drag_and_drop for cross-checklist moves.
        child = DropRegion(
          formats: Formats.standardFormats,
          onDropOver: (_) => DropOperation.move,
          onPerformDrop: (event) => handleChecklistItemDrop(
            event: event,
            checklistNotifier: checklistNotifier,
            targetIndex: widget.index,
            targetItemId: widget.itemId,
          ),
          child: DragItemWidget(
            dragItemProvider: (request) async => createChecklistItemDragItem(
              itemId: item.id,
              checklistId: widget.checklistId,
              title: item.data.title,
            ),
            allowedOperations: () => [DropOperation.move],
            dragBuilder: buildDragDecorator,
            child: DraggableWidget(child: child),
          ),
        );

        // Animated hide/show for open-only filter mode.
        if (widget.hideIfChecked) {
          child = AnimatedCrossFade(
            duration: checklistCompletionFadeDuration,
            sizeCurve: Curves.easeInOut,
            crossFadeState: _showRow
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: child,
            secondChild: const SizedBox.shrink(),
          );
        }

        return RepaintBoundary(child: child);
      },
      error: ErrorWidget.new,
      loading: (_) => const SizedBox.shrink(),
    );
  }

  Color _getSuggestionColor(ChecklistCompletionConfidence confidence) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (confidence) {
      ChecklistCompletionConfidence.high => colorScheme.primary,
      ChecklistCompletionConfidence.medium => colorScheme.secondary,
      ChecklistCompletionConfidence.low => colorScheme.tertiary,
    };
  }

  void _showSuggestionDialog(
    BuildContext context,
    ChecklistCompletionSuggestion suggestion,
  ) {
    final tokens = context.designTokens;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.messages.checklistAiSuggestionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.checklistAiSuggestionBody,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(suggestion.reason),
            SizedBox(height: tokens.spacing.step5),
            Row(
              children: [
                Icon(
                  Icons.insights,
                  size: 16,
                  color: _getSuggestionColor(suggestion.confidence),
                ),
                SizedBox(width: tokens.spacing.step2),
                Text(
                  context.messages.checklistAiConfidenceLabel(
                    suggestion.confidence.name,
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref
                  .read(checklistCompletionServiceProvider.notifier)
                  .clearSuggestion(widget.itemId);
            },
            child: Text(context.messages.cancelButton),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref
                  .read(
                    checklistItemControllerProvider((
                      id: widget.itemId,
                      taskId: widget.taskId,
                    )).notifier,
                  )
                  .updateChecked(checked: true);
              ref
                  .read(checklistCompletionServiceProvider.notifier)
                  .clearSuggestion(widget.itemId);
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text(context.messages.checklistAiMarkComplete),
          ),
        ],
      ),
    );
  }
}
