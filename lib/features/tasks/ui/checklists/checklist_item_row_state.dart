import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/components/motion/strikethrough_wipe.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// State for [ChecklistItemRow]. Manages inline title editing, the delayed
/// hide/cross-fade when an item is checked off under the Open/Done filter
/// (via `_holdTimer`), the undoable swipe-to-delete grace period (via
/// `_deleteTimer`), and the pulsing animation overlaid when an AI completion
/// suggestion targets this item. Tracks the item's last checked/archived
/// state to decide visibility on data updates.
class ChecklistItemRowState extends ConsumerState<ChecklistItemRow>
    with TickerProviderStateMixin {
  bool _isEditing = false;
  bool _showRow = true;
  Timer? _holdTimer;
  Timer? _deleteTimer;

  late AnimationController _suggestionController;
  late Animation<double> _suggestionPulse;

  /// Drives the brief "pop" of the checkbox when an item is checked off — the
  /// per-item reward beat (a light haptic fires alongside it). Scales up with
  /// an overshoot and settles back, so the tap lands with a small bounce.
  late AnimationController _checkPopController;
  late Animation<double> _checkPopScale;

  /// Anchors the spark burst to the checkbox. Used to read the checkbox's
  /// on-screen rect at tap time so the burst can be fired into the overlay
  /// before the row is (potentially) torn down by the completion.
  final GlobalKey _checkboxKey = GlobalKey();

  bool _lastIsChecked = false;
  bool _lastIsArchived = false;
  bool _receivedInitialData = false;

  @override
  void initState() {
    super.initState();
    _suggestionController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _suggestionPulse = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _suggestionController, curve: Curves.easeInOut),
    );
    _checkPopController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _checkPopScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.28).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 55,
      ),
    ]).animate(_checkPopController);
  }

  @override
  void didUpdateWidget(ChecklistItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React to parent-driven filter changes — no animation for tab switches.
    if (oldWidget.hideIfChecked != widget.hideIfChecked ||
        oldWidget.hideIfUnchecked != widget.hideIfUnchecked) {
      _handleHideStateChange(
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
    _checkPopController.dispose();
    super.dispose();
  }

  /// The interactive check-off reward — a light haptic, the checkbox "pop", and
  /// a spark burst at the checkbox. Fired straight from the tap (or the AI
  /// "mark complete" action), so it runs while the row is still mounted and the
  /// checkbox rect is still readable.
  ///
  /// This must NOT wait for a widget rebuild: completing the *last* open item
  /// brings the checklist to 100%, and the card swaps the row list for an "all
  /// done" line on the next build — unmounting this row before any
  /// lifecycle-driven celebration could fire. [spawnCompletionBurst] captures
  /// the geometry here and renders in the overlay, so the sparks survive the
  /// row collapsing away. Burst + pop are suppressed under reduced motion; the
  /// haptic still fires, since it is feedback, not motion.
  void _celebrateInteractiveCheck() {
    unawaited(HapticFeedback.lightImpact());
    // The haptic always fires; the visual pop + spark burst honour the user's
    // "celebrate checklist items" switch and the system reduced-motion setting.
    if (!ref.read(celebrationPreferencesProvider).checklistItems) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    _checkPopController.forward(from: 0);
    final checkboxContext = _checkboxKey.currentContext;
    if (checkboxContext != null) {
      spawnCompletionBurst(
        checkboxContext,
        count: 16,
        sizeScale: 0.7,
        clearCenter: 0.3,
        duration: const Duration(milliseconds: 850),
      );
    }
  }

  bool get _shouldHide {
    // Archived items count as "done" for filtering purposes.
    final isCompleted = _lastIsChecked || _lastIsArchived;
    if (widget.hideIfChecked && isCompleted) return true;
    if (widget.hideIfUnchecked && !isCompleted) return true;
    return false;
  }

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
    required bool newIsChecked,
    required bool newIsArchived,
    bool animate = false,
  }) {
    final wasChecked = _lastIsChecked;
    final wasArchived = _lastIsArchived;

    _lastIsChecked = newIsChecked;
    _lastIsArchived = newIsArchived;

    final isCompleted = newIsChecked || newIsArchived;

    // If the user just interactively checked an item while the Open filter
    // is active, use the delayed hide animation so they see the checkmark
    // feedback before the row disappears.
    if (animate &&
        widget.hideIfChecked &&
        isCompleted &&
        (!wasChecked && newIsChecked || !wasArchived && newIsArchived)) {
      _cancelTimers();
      _startHideSequence();
      return;
    }

    // For everything else, compute the desired visibility directly from
    // the current filter flags and item state.
    _cancelTimers();
    setState(() => _showRow = !_shouldHide);
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

      // On the first data load, immediately hide items that don't match
      // the active filter instead of using the animation delay (which is
      // only for items the user just checked off interactively).
      if (!_receivedInitialData) {
        _receivedInitialData = true;
        _lastIsChecked = item.data.isChecked;
        _lastIsArchived = item.data.isArchived;
        final isCompleted = item.data.isChecked || item.data.isArchived;
        if ((widget.hideIfChecked && isCompleted) ||
            (widget.hideIfUnchecked && !isCompleted)) {
          setState(() => _showRow = false);
        }
        return;
      }

      _handleHideStateChange(
        newIsChecked: item.data.isChecked,
        newIsArchived: item.data.isArchived,
        animate: true,
      );
    });

    final itemAsync = ref.watch(provider);

    // Stale-while-revalidate: render from the retained value so a *reloading*
    // item keeps its last data instead of blanking to SizedBox.shrink for a
    // frame — that blank-on-reload was the flicker when an accepted AI
    // suggestion updated the checklist. A genuine first mount / deletion has no
    // value → collapse; a hard load error with no prior value still surfaces.
    final item = itemAsync.value;
    if (item == null || item.isDeleted) {
      if (itemAsync.hasError) {
        return ErrorWidget(itemAsync.error!);
      }
      return const SizedBox.shrink();
    }
    {
      // Synchronous first-frame fix: if the provider already has data
      // on the first build, ref.listen may not have fired yet.
      // Set _showRow immediately so the row never renders its content
      // before being hidden — avoids a single visible frame of
      // strikethrough items in the Open tab.
      if (!_receivedInitialData) {
        _receivedInitialData = true;
        _lastIsChecked = item.data.isChecked;
        _lastIsArchived = item.data.isArchived;
        final isCompleted = item.data.isChecked || item.data.isArchived;
        if ((widget.hideIfChecked && isCompleted) ||
            (widget.hideIfUnchecked && !isCompleted)) {
          _showRow = false;
        }
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

      // The suggestion pulse loops forever, so it must yield to reduced
      // motion: freeze it at rest (scale 1.0) rather than pulsing.
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (suggestion != null &&
          !reduceMotion &&
          !_suggestionController.isAnimating) {
        _suggestionController.repeat(reverse: true);
      } else if ((suggestion == null || reduceMotion) &&
          _suggestionController.isAnimating) {
        _suggestionController
          ..stop()
          ..reset();
      }

      final tokens = context.designTokens;
      final isStrikethrough = item.data.isChecked || item.data.isArchived;
      final canToggle = !item.data.isArchived;

      // Toggling the check — whether from the compact checkbox itself or
      // from the enlarged tap target wrapped around it — routes here so the
      // behaviour (persist + celebrate + clear any AI suggestion) lives in
      // one place.
      void applyCheck({required bool checked}) {
        itemNotifier.updateChecked(checked: checked);
        if (checked) _celebrateInteractiveCheck();
        if (suggestion != null) {
          ref
              .read(checklistCompletionServiceProvider.notifier)
              .clearSuggestion(widget.itemId);
        }
      }

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
                  // Drag handle — purely visual affordance. Long-press
                  // anywhere on the row engages the DraggableWidget below,
                  // which routes through super_drag_and_drop for BOTH
                  // within-list reorder (via dropChecklistItem ->
                  // _reorderItem) and cross-checklist moves (via
                  // moveToChecklist). A ReorderableDragStartListener here
                  // would win the gesture race and trap drags inside the
                  // source list.
                  // The drag handle is a quiet hint only — a long-press
                  // anywhere on the row starts the drag — so it sits at a
                  // very low alpha to keep the repeating grip texture from
                  // competing with the checkbox + title for attention.
                  Icon(
                    Icons.drag_indicator,
                    size: 24,
                    color: tokens.colors.text.lowEmphasis.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  // Checkbox
                  // Checking an item off earns a small spark burst at the
                  // checkbox — the same celebration language as habits, but
                  // dialled down (no glow, fewer/finer sparks, quicker) so
                  // rapid check-offs read as a cascade of little pops rather
                  // than visual chaos. Fired imperatively from the tap (see
                  // [_celebrateInteractiveCheck]) rather than from a widget
                  // edge, so it also fires when checking the LAST item
                  // collapses the row. Reduced motion suppresses the sparks
                  // and pop (the haptic still fires).
                  // The visual checkbox stays a compact 20×20, but a 44×44
                  // InkWell around it provides a Material-compliant tap
                  // target so users with reduced motor precision can hit it
                  // without aiming at the tiny box. A centre tap lands on the
                  // Checkbox itself (keeping its native gesture + a11y
                  // semantics); the surrounding ring is caught by the
                  // InkWell. Both route through [applyCheck].
                  InkWell(
                    onTap: canToggle
                        ? () => applyCheck(checked: !item.data.isChecked)
                        : null,
                    borderRadius: BorderRadius.circular(
                      tokens.radii.badgesPills,
                    ),
                    // Light up the whole 44×44 zone on hover / press so the
                    // forgiving tap area is *visible*, not just promised —
                    // users can see where it is safe to tap rather than
                    // having to aim at the tiny box.
                    hoverColor: tokens.colors.surface.hover,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      // A faint resting "well" (the same filled+bordered
                      // language as the metadata chips) makes the 44px tap
                      // zone visible at REST — on touch there is no hover, so
                      // the hover highlight alone left the forgiving area
                      // invisible where most users tap.
                      decoration: BoxDecoration(
                        color: tokens.colors.surface.enabled,
                        borderRadius: BorderRadius.circular(
                          tokens.radii.badgesPills,
                        ),
                        border: Border.all(
                          color: tokens.colors.decorative.level02,
                        ),
                      ),
                      child: SizedBox(
                        key: _checkboxKey,
                        width: 20,
                        height: 20,
                        child: ScaleTransition(
                          scale: _checkPopScale,
                          child: Checkbox(
                            value: item.data.isChecked,
                            onChanged: canToggle
                                ? (value) => applyCheck(checked: value ?? false)
                                : null,
                            activeColor: tokens.colors.interactive.enabled,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            // Medium emphasis (not low) at 2px: an empty
                            // checkbox is a control the user must be able to
                            // SEE — a faint low-emphasis outline nearly
                            // vanished against the dark card for low-vision
                            // users. This is control legibility, not the
                            // metadata-chip emphasis tiering.
                            side: BorderSide(
                              color: tokens.colors.text.mediumEmphasis,
                              width: 2,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
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
                            onCancel: () => setState(() => _isEditing = false),
                          )
                        : StrikethroughWipe(
                            done: isStrikethrough,
                            // Off → the strike-through still shows, but
                            // applies instantly with no left-to-right wipe.
                            animate: ref
                                .watch(celebrationPreferencesProvider)
                                .checklistItems,
                            text: item.data.title,
                            baseStyle: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                            struckStyle: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.lowEmphasis,
                                  decoration: TextDecoration.lineThrough,
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
              messenger.showDesignSystemToast(
                tone: DesignSystemToastTone.warning,
                title: context.messages.checklistItemArchived,
                duration: kChecklistArchiveDuration,
                countdown: true,
                replaceCurrent: true,
                action: ToastAction(
                  label: context.messages.checklistItemArchiveUndo,
                  onPressed: () {
                    itemNotifier.unarchive();
                    messenger.hideCurrentSnackBar();
                  },
                ),
              );
            }
            return false;
          }
          // Swipe left → confirm delete
          return true;
        },
        onDismissed: (_) async {
          // Capture the message strings from `context` BEFORE the await:
          // `unlinkItem` removes this row from the checklist's item list,
          // which unmounts the row and invalidates `context`. The
          // `messenger` reference is captured higher up and survives.
          final deletedMessage = context.messages.checklistItemDeleted;
          final undoLabel = context.messages.checklistItemArchiveUndo;

          await checklistNotifier.unlinkItem(widget.itemId);

          _deleteTimer?.cancel();
          _deleteTimer = Timer(
            kChecklistDeleteDuration,
            () async => itemNotifier.delete(),
          );

          messenger.showDesignSystemToast(
            tone: DesignSystemToastTone.warning,
            title: deletedMessage,
            duration: kChecklistDeleteDuration,
            countdown: true,
            replaceCurrent: true,
            action: ToastAction(
              label: undoLabel,
              onPressed: () {
                _deleteTimer?.cancel();
                _deleteTimer = null;
                checklistNotifier.relinkItem(widget.itemId);
                messenger.hideCurrentSnackBar();
              },
            ),
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

      // Animated hide/show for filtered modes (open-only or done-only).
      if (widget.hideIfChecked || widget.hideIfUnchecked) {
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
    }
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
              _celebrateInteractiveCheck();
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
