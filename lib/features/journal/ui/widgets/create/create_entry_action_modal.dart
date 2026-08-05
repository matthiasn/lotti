import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/index.dart';

/// Bottom-sheet menu of "create entry" actions (text, checklist, audio, task,
/// event, timer, image import/screenshot/paste).
///
/// `linkedFromId`/`categoryId` are threaded into each action so created
/// entities are linked to and categorized like the host. Visibility is
/// resolved *before* the list is assembled — platform gating, config flags,
/// clipboard state, task-host checks all happen in [_CreateEntryMenuList] —
/// so a divider can never end up stranded against a row that declined to
/// render.
///
/// On a task host the order mirrors the first-run card's writing-first
/// priority (note, checklist, voice note) and the Timer row stands down: the
/// page's Track time pill is the same action under its own name, and one
/// action gets one home — the same dedupe rationale the compact action bar
/// documents.
class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    final spacing = context.designTokens.spacing;
    // Mirrors ModalUtils.modalTypeBuilder's own breakpoint: the mobile
    // bottom sheet folds behind the home indicator, so its last row earns a
    // step6 foot; the centered desktop dialog has a visible bottom edge and
    // the same foot read as a dead band under the final divider.
    final isBottomSheet =
        MediaQuery.sizeOf(context).width < WoltModalConfig.pageBreakpoint;
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createEntryTitle,
      // The rows own their vertical rhythm entirely — a sheet-level top
      // breath made the first row's divider-to-title measure taller than
      // its siblings'. Only the foot is the sheet's own, sized per
      // presentation (previously a literal `bottom: 30, top: 10`).
      padding: EdgeInsets.only(
        bottom: isBottomSheet ? spacing.step6 : spacing.step3,
      ),
      builder: (modalContext) => _CreateEntryMenuList(
        linkedFromId: linkedFromId,
        categoryId: categoryId,
      ),
    );
  }
}

/// Builds the list of create entry items with dividers between them.
///
/// Owns the sheet's hover index ([HoverDividerIndex]) because the hairlines
/// are siblings of the rows, not children: only the list can see that the
/// pointer is on row *i* and therefore that the rules above and below it must
/// fade. Without it the hovered row was bisected top and bottom by the very
/// lines the highlight is meant to replace.
class _CreateEntryMenuList extends ConsumerStatefulWidget {
  const _CreateEntryMenuList({
    required this.linkedFromId,
    required this.categoryId,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  ConsumerState<_CreateEntryMenuList> createState() =>
      _CreateEntryMenuListState();
}

class _CreateEntryMenuListState extends ConsumerState<_CreateEntryMenuList>
    with HoverDividerIndex<_CreateEntryMenuList> {
  @override
  Widget build(BuildContext context) {
    final linkedFromId = widget.linkedFromId;
    final categoryId = widget.categoryId;
    // Every visibility decision lands here, before the list exists, so the
    // divider loop below can treat "listed" and "rendered" as the same thing.
    // Letting an item collapse itself to a SizedBox after being listed is how
    // the sheet used to close on an orphan rule under a row that wasn't there.
    final id = linkedFromId;
    final host = id == null
        ? null
        : ref.watch(entryControllerProvider(id)).value?.entry;
    final hostIsTask = host is Task;
    final enableEvents =
        ref
            .watch(configFlagProvider(enableEventsFlag))
            .unwrapPrevious()
            .value ??
        false;
    final canPasteImage =
        ref
            .watch(
              imagePasteControllerProvider((
                linkedFromId: linkedFromId,
                categoryId: categoryId,
              )),
            )
            .value ??
        false;

    // Each row reports its own hover so the list can fade the pair of
    // hairlines bracketing it. The index is positional, so it is bound here
    // rather than inside the row widgets — a row does not know where in the
    // sheet it landed.
    ValueChanged<bool> hover(int index) =>
        (hovered) => onRowHoverChanged(index, hovered: hovered);

    // Built as builders, not widgets: a row's hover callback needs its final
    // position in the list, which is only known once every conditional row
    // above it has resolved.
    final items = <Widget Function(ValueChanged<bool>)>[
      // Writing first — the same priority the task page's first-run card
      // teaches: type it down, structure it, say it. The long tail follows.
      (h) => CreateTextItem(
        linkedFromId,
        categoryId: categoryId,
        onHoverChanged: h,
      ),
      if (hostIsTask)
        (h) => CreateChecklistItem(linkedFromId, onHoverChanged: h),
      (h) => CreateAudioItem(
        linkedFromId,
        categoryId: categoryId,
        onHoverChanged: h,
      ),
      (h) => CreateTaskItem(
        linkedFromId,
        categoryId: categoryId,
        onHoverChanged: h,
      ),
      if (enableEvents)
        (h) => CreateEventItem(
          linkedFromId,
          categoryId: categoryId,
          onHoverChanged: h,
        ),
      // On a task host the Track time pill IS the timer — offering it here
      // a second time under a different name taxed every user with a
      // synonym.
      if (linkedFromId != null && !hostIsTask)
        (h) => CreateTimerItem(linkedFromId, onHoverChanged: h),
      if (isMacOS || isMobile || isLinux || isWindows)
        (h) => ImportImageItem(
          linkedFromId,
          categoryId: categoryId,
          onHoverChanged: h,
        ),
      if (isMacOS || isLinux)
        (h) => CreateScreenshotItem(
          linkedFromId,
          categoryId: categoryId,
          onHoverChanged: h,
        ),
      if (canPasteImage)
        (h) => PasteImageItem(
          linkedFromId,
          categoryId: categoryId,
          onHoverChanged: h,
        ),
    ];

    final gutter = context.designTokens.spacing.step5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          // Inset to the rows' gutter, matching the first-run card. The rule
          // above row `i` is the one below row `i - 1`, so that is the index
          // the mixin is asked about; it fades for a pointer on either side.
          // Colour only — the divider is never removed, so the rows below the
          // pointer cannot jump by 1 px on hover.
          if (i > 0)
            DesignSystemDivider(
              indent: gutter,
              color: hoverDividerColorFor(i - 1),
            ),
          items[i](hover(i)),
        ],
      ],
    );
  }
}
