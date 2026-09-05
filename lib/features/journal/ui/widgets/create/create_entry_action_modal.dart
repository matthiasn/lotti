import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';

/// The "Add" sheet — the second of the app's two action modals, on the shared
/// [DsActionModal] shell.
///
/// A menu of "create entry" actions (text, checklist, audio, task, event,
/// timer, image import/screenshot/paste).
///
/// `linkedFromId`/`categoryId` are threaded into each action so created
/// entities are linked to and categorized like the host. Visibility is
/// resolved *before* the list is assembled — platform gating, config flags,
/// clipboard state, task-host checks all happen in [_CreateEntryMenuList] —
/// so the sheet's rhythm can never be spent on a row that declined to render.
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
    await DsActionModal.show<void>(
      context: context,
      title: context.messages.createEntryTitle,
      builder: (modalContext) => _CreateEntryMenuList(
        linkedFromId: linkedFromId,
        categoryId: categoryId,
      ),
    );
  }
}

/// Builds the list of create entry items.
class _CreateEntryMenuList extends ConsumerWidget {
  const _CreateEntryMenuList({
    required this.linkedFromId,
    required this.categoryId,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedFromId = this.linkedFromId;
    final categoryId = this.categoryId;
    // Every visibility decision lands here, before the list exists. Letting
    // an item collapse itself to a SizedBox after being listed is how the
    // sheet used to close on an orphan rule under a row that wasn't there.
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

    return DsActionModalList(
      children: [
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
        if (linkedFromId != null && !hostIsTask) CreateTimerItem(linkedFromId),
        if (isMacOS || isMobile || isLinux || isWindows)
          ImportImageItem(linkedFromId, categoryId: categoryId),
        if (isMacOS || isLinux)
          CreateScreenshotItem(linkedFromId, categoryId: categoryId),
        if (canPasteImage) PasteImageItem(linkedFromId, categoryId: categoryId),
      ],
    );
  }
}
