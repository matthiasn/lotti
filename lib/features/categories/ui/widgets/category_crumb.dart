import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/category_icon/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/entry_category_move.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';

/// An entry's category above its title, as a selector: the category's icon,
/// its name and a down chevron, opening the shared category picker — the
/// one a journal entry, a task and an event reassign their category with.
/// The person page and the goal page both carry it, so a category reads and
/// changes the same way on every page an agent serves.
///
/// A pick moves the entry through [entryCategoryMoveProvider], the move the
/// editors save with, so what the entry holds — a person's check-ins and
/// notes, a goal's check-ins — travels with it, and its agent follows the new
/// category's profile on its next run. Dismissing the picker changes
/// nothing; a failed move says so and leaves the old category showing.
///
/// An entry in no category gets the same control, worded as the offer to set
/// one, so the place to change it never disappears. While [entryId] is null —
/// a host still reading which row to move — the crumb shows the category but
/// cannot be tapped.
class CategoryCrumb extends ConsumerStatefulWidget {
  const CategoryCrumb({
    required this.entryId,
    required this.categoryId,
    this.onMoved,
    super.key,
  });

  final String? entryId;
  final String? categoryId;

  /// Runs once a move has landed, for a host whose category read does not
  /// follow the entry by itself.
  final VoidCallback? onMoved;

  @override
  ConsumerState<CategoryCrumb> createState() => _CategoryCrumbState();
}

class _CategoryCrumbState extends ConsumerState<CategoryCrumb> {
  var _hovered = false;
  var _moving = false;

  Future<void> _pick(String entryId) async {
    if (_moving) return;
    final messages = context.messages;
    final move = ref.read(entryCategoryMoveProvider);
    final result = await showCategoryPicker(
      context: context,
      title: messages.habitCategoryLabel,
      currentCategoryId: widget.categoryId,
    );
    // null = dismissed; a pick or an explicit clear is a change.
    if (result == null) return;
    final picked = result.categoryOrNull;
    final previousId = widget.categoryId;
    if (picked?.id == previousId) return;
    if (!mounted) return;
    setState(() => _moving = true);
    final moved = await move.move(entryId, picked?.id);
    if (!mounted) return;
    setState(() => _moving = false);
    if (!moved) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.saveFailedRetry,
      );
      return;
    }
    widget.onMoved?.call();
    // Everything the undo needs is taken now, while the page is here: the
    // toast can outlive it — the user may leave before tapping Undo.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final onMoved = widget.onMoved;
    // The header commits at once, where an editor waits for Save: the
    // toast says where the entry went and offers the way back.
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: picked == null
          ? messages.categoryCrumbMovedOut
          : messages.categoryCrumbMovedTo(picked.name),
      action: ToastAction(
        label: messages.designSystemUndoLabel,
        // _undo answers its own failure with a toast, so nothing it does
        // can escape the tap that started it.
        onPressed: () => _undo(
          move: move,
          entryId: entryId,
          previousId: previousId,
          messenger: messenger,
          failedTitle: messages.saveFailedRetry,
          onMoved: onMoved,
        ),
      ),
      replaceCurrent: true,
    );
  }

  /// Moves the entry back. Only the busy state belongs to this widget, and
  /// it is touched only while the widget is mounted; the move itself and its
  /// failure toast go ahead after the page is gone.
  Future<void> _undo({
    required EntryCategoryMove move,
    required String entryId,
    required String? previousId,
    required ScaffoldMessengerState? messenger,
    required String failedTitle,
    required VoidCallback? onMoved,
  }) async {
    if (_moving) return;
    if (mounted) setState(() => _moving = true);
    bool moved;
    try {
      moved = await move.move(entryId, previousId);
    } on Object {
      moved = false;
    }
    if (mounted) setState(() => _moving = false);
    if (moved) {
      onMoved?.call();
      return;
    }
    // In place of the *Moved to* toast whose Undo this was.
    messenger?.showDesignSystemToast(
      tone: DesignSystemToastTone.error,
      title: failedTitle,
      replaceCurrent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final name = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(widget.categoryId)
        ?.name;
    final ink = name == null
        ? tokens.colors.text.lowEmphasis
        : tokens.colors.text.mediumEmphasis;
    final label = name ?? messages.taskSetCategoryLabel;
    final radius = BorderRadius.circular(tokens.radii.s);
    // The inset the hover wash needs, given back as a negative offset so the
    // icon still starts on the page's content gutter, where the title below
    // starts.
    final inset = tokens.spacing.step1;
    final entryId = widget.entryId;
    final onTap = entryId == null || _moving ? null : () => _pick(entryId);

    return Transform.translate(
      offset: Offset(-inset, 0),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: '${messages.habitCategoryLabel}: $label',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('category-crumb'),
            borderRadius: radius,
            onTap: onTap,
            onHover: (value) => setState(() => _hovered = value),
            child: AnimatedContainer(
              duration: MotionDurations.short2,
              decoration: BoxDecoration(
                color: _hovered
                    ? tokens.colors.surface.hover
                    : Colors.transparent,
                borderRadius: radius,
              ),
              // A touch-sized target around a caption-sized label.
              constraints: const BoxConstraints(minHeight: TapTargets.compact),
              padding: EdgeInsetsDirectional.only(
                start: inset,
                end: tokens.spacing.step2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.categoryId != null) ...[
                    CategoryIconCompact(
                      widget.categoryId,
                      size: CategoryIconConstants.iconSizeExtraSmall,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      key: const ValueKey('category-crumb-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: captionLabelStyle(tokens, color: ink),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step1),
                  Icon(LottiIcons.chevronDown, size: IconSizes.s, color: ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
