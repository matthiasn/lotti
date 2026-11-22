import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/lists/design_system_swipe_actions.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_collapse.dart';
import 'package:lotti/features/design_system/components/motion/strikethrough_wipe.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_chat_approval_caption.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/celebration/celebration_preferences_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// State for [ChecklistItemRow]. Manages inline title editing, the delayed
/// hide/cross-fade when an item is checked off under the Open/Done filter
/// (via `_holdTimer`), the undoable swipe-to-delete (whose grace period the
/// repository times, since the row leaves the screen with the item), and the
/// pulsing animation overlaid when an AI completion
/// suggestion targets this item. Tracks the item's last checked/archived
/// state to decide visibility on data updates.
class ChecklistItemRowState extends ConsumerState<ChecklistItemRow>
    with TickerProviderStateMixin {
  bool _isEditing = false;
  bool _showRow = true;
  Timer? _holdTimer;

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

  /// Set when a *local* tap already fired the check-off celebration, so the
  /// data-change listener (which sees the same check land a moment later)
  /// doesn't fire a second burst for it. External check-offs (an accepted AI
  /// proposal, a sync from another device) leave this false, so they DO get the
  /// burst — the reward fires whenever an item becomes checked, not only on a
  /// direct tap.
  bool _suppressDataCheckCelebration = false;

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
    _suggestionController.dispose();
    _checkPopController.dispose();
    super.dispose();
  }

  /// The check-off reward — a checkbox "pop" and a spark burst at the checkbox,
  /// plus a light haptic on a direct tap. Fired imperatively (not from a
  /// rebuild) so it runs while the row is still mounted and the checkbox rect
  /// is still readable.
  ///
  /// This must NOT wait for a widget rebuild: completing the *last* open item
  /// brings the checklist to 100%, and the card swaps the row list for an "all
  /// done" line on the next build — unmounting this row before any
  /// lifecycle-driven celebration could fire. [spawnCompletionBurst] captures
  /// the geometry here and renders in the overlay, so the sparks survive the
  /// row collapsing away. Burst + pop are suppressed under reduced motion.
  ///
  /// [interactive] is true for a direct tap on this row's checkbox (or its AI
  /// "mark complete" dialog): it adds the haptic and flags the upcoming
  /// data-change so the listener doesn't double-fire. It is false for an
  /// external check-off (an accepted AI proposal, a sync) routed through the
  /// data listener — same sparks, no haptic.
  void _celebrateCheck({required bool interactive}) {
    // Can be driven by the data listener (an accepted AI proposal, a sync), so
    // the row may already be gone by the time it runs — bail before touching
    // ref/context on an unmounted state.
    if (!mounted) return;
    final prefs = ref.read(celebrationPreferencesProvider);
    // A direct tap also gets a haptic (feedback, not motion), honouring the
    // independent haptics switch. The data-listener suppression flag is set by
    // the caller *before* it writes the check, so it is already in place when
    // the change lands back through the listener.
    if (interactive && prefs.haptics) unawaited(HapticFeedback.lightImpact());
    // The visual pop + spark burst honour the master switch + the "celebrate
    // checklist items" switch and the system reduced-motion setting.
    if (!prefs.animateChecklistItems) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    _checkPopController.forward(from: 0);
    final checkboxContext = _checkboxKey.currentContext;
    // Only emit the spark burst when the checkbox is actually on screen. An
    // external check-off (an accepted AI "check off" proposal, a sync) can land
    // on an item scrolled out of view; without this guard the sparks would
    // erupt at the off-screen checkbox position — e.g. clamped over the page
    // title. A direct tap is always on screen, so this never suppresses it.
    if (checkboxContext != null && _checkboxIsInViewport(checkboxContext)) {
      final resolved = prefs.checklistItemsSelection.resolve(
        seed: nextCelebrationSeed(),
      );
      spawnCompletionBurst(
        checkboxContext,
        params: prefs.paramsFor(resolved.primary),
        secondParams: resolved.secondary == null
            ? null
            : prefs.paramsFor(resolved.secondary!),
        duration: const Duration(milliseconds: 850),
      );
    }
  }

  /// Whether the checkbox currently overlaps its enclosing scroll viewport.
  /// Returns true when there is no enclosing scrollable (nothing can clip it).
  bool _checkboxIsInViewport(BuildContext checkboxContext) {
    final box = checkboxContext.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final checkboxRect = box.localToGlobal(Offset.zero) & box.size;
    final scrollable = Scrollable.maybeOf(checkboxContext);
    if (scrollable == null) return true;
    final viewport = scrollable.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return true;
    }
    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    return viewportRect.overlaps(checkboxRect);
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

      // Celebrate whenever an item *becomes* checked, not only on a direct tap:
      // an accepted AI "check off" proposal (or any external check) arrives
      // here. A local tap already fired the burst imperatively and set the
      // suppression flag, so it isn't double-celebrated; an item going back to
      // unchecked clears the flag so a later external check still celebrates.
      final becameChecked = !_lastIsChecked && item.data.isChecked;
      if (!item.data.isChecked) {
        _suppressDataCheckCelebration = false;
      } else if (becameChecked) {
        if (_suppressDataCheckCelebration) {
          _suppressDataCheckCelebration = false;
        } else {
          _celebrateCheck(interactive: false);
        }
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
        // Flag the suppression BEFORE the write so the data listener (which can
        // fire as soon as the controller updates) sees it and doesn't add a
        // second burst on top of the imperative one below.
        if (checked) _suppressDataCheckCelebration = true;
        itemNotifier.updateChecked(checked: checked);
        if (checked) _celebrateCheck(interactive: true);
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
          // Leading divider: it separates this row from the one above and is
          // part of this row's widget, so it mounts/unmounts together with the
          // row (no "row appears, divider follows a frame later" flicker).
          if (widget.showDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: tokens.colors.decorative.level01,
            ),
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
                    LottiIcons.drag,
                    size: IconSizes.l,
                    color: tokens.colors.text.lowEmphasis.withValues(
                      alpha: SecondaryGlyphAlpha.hint,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  // Checkbox
                  // Checking an item off earns a small spark burst at the
                  // checkbox — the same celebration language as habits, but
                  // dialled down (no glow, fewer/finer sparks, quicker) so
                  // rapid check-offs read as a cascade of little pops rather
                  // than visual chaos. Fired imperatively (see [_celebrateCheck])
                  // rather than from a widget edge, so it also fires when
                  // checking the LAST item collapses the row, and the data
                  // listener fires it for external check-offs (accepted AI
                  // proposals) too. Reduced motion suppresses the sparks + pop.
                  // One shape for one control: the design system's checkbox,
                  // inside a 44×44 target that lights up under a pointer or a
                  // press. It used to sit in a resting circular "well" — a
                  // square inside a circle, two shapes for one checkbox. Both
                  // the ring and the box route through [applyCheck].
                  InkWell(
                    onTap: canToggle
                        ? () => applyCheck(checked: !item.data.isChecked)
                        : null,
                    borderRadius: BorderRadius.circular(
                      tokens.radii.badgesPills,
                    ),
                    hoverColor: tokens.colors.surface.hover,
                    child: SizedBox.square(
                      dimension: TapTargets.compact,
                      child: Center(
                        child: SizedBox.square(
                          key: _checkboxKey,
                          dimension: ControlSizes.checkbox,
                          child: ScaleTransition(
                            scale: _checkPopScale,
                            child: DesignSystemCheckbox(
                              value: item.data.isChecked,
                              semanticsLabel: item.data.title,
                              onChanged: canToggle
                                  ? (value) =>
                                        applyCheck(checked: value ?? false)
                                  : null,
                            ),
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
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                // Tapping the words opens the editor, the
                                // same as the pencil. This does not collide
                                // with check-off: that gesture belongs to the
                                // checkbox's own 44x44 well above, so the
                                // title was simply dead space — the pencil
                                // was the only way in, and it is a 16pt
                                // target at the far end of the row.
                                //
                                // Opaque so the whole title column responds,
                                // including the gaps between wrapped lines,
                                // rather than only the glyphs themselves.
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _isEditing = true),
                                child: StrikethroughWipe(
                                  done: isStrikethrough,
                                  // Off → the strike-through still shows, but
                                  // applies instantly with no left-to-right
                                  // wipe. Folds in the master switch.
                                  animate: ref
                                      .watch(celebrationPreferencesProvider)
                                      .animateChecklistItems,
                                  text: item.data.title,
                                  baseStyle: tokens
                                      .typography
                                      .styles
                                      .body
                                      .bodySmall
                                      .copyWith(
                                        color: tokens.colors.text.highEmphasis,
                                      ),
                                  struckStyle: tokens
                                      .typography
                                      .styles
                                      .body
                                      .bodySmall
                                      .copyWith(
                                        color: tokens.colors.text.lowEmphasis,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                  maxLines: 4,
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                              // Outside the title's tap-to-edit gesture, so
                              // tapping it opens the chat instead.
                              if (item.data.currentChatApproval
                                  case final approval?)
                                ChecklistChatApprovalCaption(
                                  approval: approval,
                                  taskId: widget.taskId,
                                ),
                            ],
                          ),
                  ),
                  // Edit affordance.
                  //
                  // Centred in a [TapTargets.minimum] slot rather than sitting
                  // flush at the content edge, for two reasons. It puts the
                  // glyph on the same trailing axis as the Linked Tasks row's
                  // chevron — which is itself centred in a 48pt slot so it
                  // lands where manage mode's unlink button sits — so the two
                  // cards' trailing marks line up instead of missing each
                  // other by 25pt. And it gives the pencil the 48pt target the
                  // checkbox beside it already takes: at a bare 20pt glyph it
                  // was the one control on this row below the floor.
                  //
                  // Deliberately quieter than the checkbox and the title: this
                  // is a secondary route into a row whose primary action is
                  // checking it off, so it is sized down to [IconSizes.s] and
                  // dimmed, the same way the drag handle above steps back.
                  if (!_isEditing)
                    GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      // The extra trailing step3 is what puts this glyph on the
                      // *same vertical line* as the Linked Tasks card's
                      // chevron. That card insets its content by `cardPadding`
                      // (16); this row insets by step3 (8), so two slots of
                      // equal width still landed 8pt apart — close enough to
                      // look like a mistake rather than a variation.
                      child: SizedBox(
                        // A step8 slot, not a full tap target: centred, it puts
                        // the glyph on the same vertical line as the card
                        // *header's* overflow control, which is the trailing
                        // axis a reader actually sees. A 48pt slot sat 12pt
                        // inboard of it and left ~33pt of dead margin.
                        width: tokens.spacing.step8,
                        height: TapTargets.minimum,
                        child: Center(
                          child: Icon(
                            LottiIcons.edit,
                            // Deliberately the caption tier. A pencil is a
                            // dense glyph — at IconSizes.s it carried 2.5x the
                            // chevron's ink and read as the loudest thing on a
                            // row whose primary action is checking it off.
                            size: IconSizes.xs,
                            color: tokens.colors.text.lowEmphasis.withValues(
                              alpha: SecondaryGlyphAlpha.affordance,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                  onTap: () async => _showSuggestionDialog(context, suggestion),
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

      // Swipe right toggles archive, swipe left deletes with an undo window:
      // the design system's one swipe mechanic, its band naming the action.
      void toggleArchive() {
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
      }

      Future<void> deleteWithUndo() async {
        // Capture the message strings from `context` BEFORE the await:
        // `beginItemDeletion` removes this row from the checklist's items,
        // which unmounts the row and invalidates `context`. The
        // `messenger` reference is captured higher up and survives.
        final deletedMessage = context.messages.checklistItemDeleted;
        final undoLabel = context.messages.checklistItemArchiveUndo;

        // The repository deletes the item when the undo window closes —
        // this row is gone by then — and records the deletion, so it
        // completes even if the app dies meanwhile.
        final key = await checklistNotifier.beginItemDeletion(
          widget.itemId,
          undoWindow: kChecklistDeleteDuration,
        );
        if (key == null) return;

        messenger.showDesignSystemToast(
          tone: DesignSystemToastTone.warning,
          title: deletedMessage,
          duration: kChecklistDeleteDuration,
          countdown: true,
          replaceCurrent: true,
          action: ToastAction(
            label: undoLabel,
            onPressed: () {
              unawaited(
                checklistNotifier.undoItemDeletion(
                  key: key,
                  checklistItemId: widget.itemId,
                ),
              );
              messenger.hideCurrentSnackBar();
            },
          ),
        );
      }

      final colors = tokens.colors;
      Widget child = DesignSystemSwipeActions(
        swipeKey: Key('dismissible-${item.id}'),
        borderRadius: BorderRadius.zero,
        startToEnd: DesignSystemSwipeAction(
          color: colors.alert.warning.defaultColor,
          foregroundColor: colors.text.onInteractiveAlert,
          icon: item.data.isArchived
              ? LottiIcons.unarchive
              : LottiIcons.archive,
          label: item.data.isArchived
              ? context.messages.checklistItemSwipeRestore
              : context.messages.checklistItemSwipeArchive,
          onTrigger: toggleArchive,
        ),
        endToStart: DesignSystemSwipeAction(
          color: colors.alert.error.defaultColor,
          foregroundColor: colors.text.onInteractiveAlert,
          icon: LottiIcons.delete,
          label: context.messages.checklistItemSwipeDelete,
          onTrigger: () async => deleteWithUndo(),
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
      // [SizeFadeCollapse] scales the row and shrinks the space it reserves on
      // one shared factor, so the checkbox, title and trailing affordances
      // shrink together. An AnimatedCrossFade to a zero-sized second child used
      // to sit here and could not do that: it re-laid the outgoing row out
      // against zero-size constraints (jumping its contents on frame one) and
      // then clipped a still-full-size checkbox as the box closed.
      if (widget.hideIfChecked || widget.hideIfUnchecked) {
        child = SizeFadeCollapse(
          duration: checklistCompletionFadeDuration,
          collapsed: !_showRow,
          child: child,
        );
      }

      return RepaintBoundary(child: child);
    }
  }

  Color _getSuggestionColor(ChecklistCompletionConfidence confidence) {
    // An agent's suggestion speaks in agent violet; less confidence recedes
    // to neutral ink rather than borrowing unrelated scheme roles.
    final colors = context.designTokens.colors;
    return switch (confidence) {
      ChecklistCompletionConfidence.high => colors.aiCard.accent,
      ChecklistCompletionConfidence.medium => colors.text.mediumEmphasis,
      ChecklistCompletionConfidence.low => colors.text.lowEmphasis,
    };
  }

  Future<void> _showSuggestionDialog(
    BuildContext context,
    ChecklistCompletionSuggestion suggestion,
  ) async {
    final tokens = context.designTokens;
    final completion = ref.read(checklistCompletionServiceProvider.notifier);

    await DsActionModal.show<void>(
      context: context,
      title: context.messages.checklistAiSuggestionTitle,
      builder: (modalContext) => Column(
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
          Text(
            suggestion.reason,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          Row(
            children: [
              Icon(
                LottiIcons.insights,
                size: IconSizes.s,
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
          SizedBox(height: tokens.spacing.step6),
          DesignSystemModalActionBar(
            secondary: [
              DesignSystemButton(
                label: context.messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(modalContext).pop();
                  completion.clearSuggestion(widget.itemId);
                },
              ),
            ],
            primary: DesignSystemButton(
              label: context.messages.checklistAiMarkComplete,
              leadingIcon: LottiIcons.confirmCircled,
              fullWidth: true,
              onPressed: () {
                Navigator.of(modalContext).pop();
                _suppressDataCheckCelebration = true;
                ref
                    .read(
                      checklistItemControllerProvider((
                        id: widget.itemId,
                        taskId: widget.taskId,
                      )).notifier,
                    )
                    .updateChecked(checked: true);
                _celebrateCheck(interactive: true);
                completion.clearSuggestion(widget.itemId);
              },
            ),
          ),
        ],
      ),
    );
  }
}
