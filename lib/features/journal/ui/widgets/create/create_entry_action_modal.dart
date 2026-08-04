import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
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
/// documents. While the first-run card itself is on screen, the note,
/// checklist and voice rows stand down too: the card is offering exactly
/// those, under exactly these names, a few centimetres higher.
class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
    String? title,
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
      // The host may rename the sheet to match its trigger — the task bar
      // says "Attach" while the first-run card owns the writing actions, and
      // trigger, sheet title and contents must be one word.
      title: title ?? context.messages.createEntryTitle,
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
class _CreateEntryMenuList extends ConsumerWidget {
  const _CreateEntryMenuList({
    required this.linkedFromId,
    required this.categoryId,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Every visibility decision lands here, before the list exists, so the
    // divider loop below can treat "listed" and "rendered" as the same thing.
    // Letting an item collapse itself to a SizedBox after being listed is how
    // the sheet used to close on an orphan rule under a row that wasn't there.
    final id = linkedFromId;
    final host = id == null
        ? null
        : ref.watch(entryControllerProvider(id)).value?.entry;
    final hostIsTask = host is Task;
    // While the first-run card is on screen it offers note, checklist and
    // voice note as worded rows; listing the same three here — under the same
    // names, since the two surfaces share strings — put two lists with
    // unequal membership on screen at once. The same dedupe the Timer row
    // and the compact action bar already apply: the sheet keeps only what
    // the card does not offer.
    final hostIsFirstRunTask = hostIsTask && watchTaskIsFirstRun(ref, host);
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

    final items = <Widget>[
      if (hostIsFirstRunTask) ...[
        // First-run order is likelihood order for a blank task: attach the
        // thing in front of you (a photo, the screen), and only then spawn a
        // second task — the rarest first move on a task not yet named, and
        // the one row that navigates away from the page inviting a name.
        if (isMacOS || isMobile || isLinux || isWindows)
          ImportImageItem(linkedFromId, categoryId: categoryId),
        if (isMacOS || isLinux)
          CreateScreenshotItem(linkedFromId, categoryId: categoryId),
        if (canPasteImage) PasteImageItem(linkedFromId, categoryId: categoryId),
        CreateTaskItem(linkedFromId, categoryId: categoryId),
        if (enableEvents) CreateEventItem(linkedFromId, categoryId: categoryId),
      ] else ...[
        // Writing first — the same priority the task page's first-run card
        // teaches: type it down, structure it, say it. The long tail follows.
        CreateTextItem(linkedFromId, categoryId: categoryId),
        if (hostIsTask) CreateChecklistItem(linkedFromId),
        CreateAudioItem(linkedFromId, categoryId: categoryId),
        CreateTaskItem(linkedFromId, categoryId: categoryId),
        if (enableEvents) CreateEventItem(linkedFromId, categoryId: categoryId),
        // On a task host the Track time pill IS the timer — offering it here
        // a second time under a different name taxed every user with a
        // synonym.
        if (linkedFromId != null && !hostIsTask) CreateTimerItem(linkedFromId!),
        if (isMacOS || isMobile || isLinux || isWindows)
          ImportImageItem(linkedFromId, categoryId: categoryId),
        if (isMacOS || isLinux)
          CreateScreenshotItem(linkedFromId, categoryId: categoryId),
        if (canPasteImage) PasteImageItem(linkedFromId, categoryId: categoryId),
      ],
    ];

    final gutter = context.designTokens.spacing.step5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          // Inset to the rows' gutter, matching the first-run card.
          if (i > 0) DesignSystemDivider(indent: gutter),
          items[i],
        ],
        // The dedupe must never read as a dead end: a first-run user who
        // learned "the + is where I add things" opens this sheet and finds
        // none of the writing actions the card holds. One quiet line says
        // where they are; the tap simply returns to the page that has them.
        if (hostIsFirstRunTask) ...[
          DesignSystemDivider(indent: gutter),
          const _FirstRunFooterRow(),
        ],
      ],
    );
  }
}

/// Quiet closing aside for the first-run Add sheet: names where the writing
/// actions live. A plain caption, not a control — a hidden tap target gave
/// the row a split identity (looked like text, behaved like a button), and
/// on the desktop dialog the Column's default centring made the same widget
/// render two different alignments. It sits a genuine tier below the row
/// subtitles — caption at lowEmphasis, the design system's quiet-meta
/// pairing — and starts on the rows' TITLE column (gutter + glyph + gap),
/// so the sheet closes on the two rails it already has instead of opening a
/// third.
class _FirstRunFooterRow extends StatelessWidget {
  const _FirstRunFooterRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          // The rows' text column, owned by the row component itself.
          left: DesignSystemListItem.titleColumnInset(tokens),
          right: spacing.step5,
          top: spacing.step4,
          bottom: spacing.step4,
        ),
        child: Text(
          context.messages.createEntryFirstRunFooter,
          textAlign: TextAlign.start,
          // mediumEmphasis, not low: this line is first-run WAYFINDING —
          // it tells a new user where the writing actions live — and at
          // lowEmphasis it sat a legibility tier below text that matters
          // less. The caption size alone keeps it a tier under the rows.
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}
