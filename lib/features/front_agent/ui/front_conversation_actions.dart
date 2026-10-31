import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_conversation_service.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for a conversation's actions, wherever its menu opens.
@visibleForTesting
abstract final class FrontConversationActionKeys {
  static Key rename(String id) => Key('front-conversation-rename-$id');
  static Key archive(String id) => Key('front-conversation-archive-$id');
  static Key delete(String id) => Key('front-conversation-delete-$id');
  static const Key titleInput = Key('front-conversation-title-input');
  static const Key titleSave = Key('front-conversation-title-save');
}

/// Renaming, archiving and deleting one conversation — the same three ways
/// out from the list's row menu and from the header's, so the same `⋯`
/// means the same thing everywhere.
///
/// Archiving says so with an undo; deleting asks first and says what it
/// does; a write that fails says so instead of being lost.
class FrontConversationActions {
  const FrontConversationActions(this._context, this._ref);

  final BuildContext _context;
  final WidgetRef _ref;

  FrontChatController get _controller =>
      _ref.read(frontChatControllerProvider.notifier);

  /// The three menu rows for [conversation].
  List<DesignSystemContextMenuItem> menuItems(FrontConversation conversation) {
    final messages = _context.messages;
    final id = conversation.id;
    return [
      DesignSystemContextMenuItem(
        key: FrontConversationActionKeys.rename(id),
        label: messages.queryRenameChat,
        icon: LottiIcons.edit,
        onTap: () => _run(() => _rename(conversation)),
      ),
      DesignSystemContextMenuItem(
        key: FrontConversationActionKeys.archive(id),
        label: conversation.archived
            ? messages.queryRestoreChat
            : messages.queryArchiveChat,
        icon: conversation.archived ? LottiIcons.unarchive : LottiIcons.archive,
        onTap: () => _run(() => _archive(conversation)),
      ),
      DesignSystemContextMenuItem(
        key: FrontConversationActionKeys.delete(id),
        label: messages.queryDeleteChat,
        icon: LottiIcons.delete,
        isDestructive: true,
        onTap: () => _run(() => _delete(conversation)),
      ),
    ];
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Exception {
      if (_context.mounted) {
        _context.showToast(
          tone: DesignSystemToastTone.error,
          title: _context.messages.frontChatActionFailed,
        );
      }
    }
  }

  Future<void> _rename(FrontConversation conversation) async {
    final title = await ModalUtils.showSinglePageModal<String>(
      context: _context,
      builder: (context) => _RenameDialog(title: conversation.title),
    );
    if (title != null) {
      await _controller.renameConversation(conversation.id, title);
    }
  }

  Future<void> _archive(FrontConversation conversation) async {
    final archiving = !conversation.archived;
    final wasOpen = _controller.isOpen(conversation.id);
    await _controller.archiveConversation(
      conversation.id,
      archived: archiving,
    );
    if (_context.mounted && archiving) {
      final controller = _controller;
      _context.showToast(
        tone: DesignSystemToastTone.success,
        title: _context.messages.frontChatArchivedToast,
        action: ToastAction(
          label: _context.messages.frontDoorUndo,
          // Undo puts it back as it was — open again, if it was open.
          onPressed: () => _run(() async {
            await controller.archiveConversation(
              conversation.id,
              archived: false,
            );
            if (wasOpen) controller.openConversation(conversation.id);
          }),
        ),
      );
    }
  }

  Future<void> _delete(FrontConversation conversation) async {
    final messages = _context.messages;
    // The app's own destructive confirmation.
    final confirmed = await showConfirmationModal(
      context: _context,
      title: messages.queryDeleteChat,
      message: messages.frontChatDeleteExplanation,
      confirmLabel: messages.queryDeleteChat,
    );
    if (confirmed) {
      await _controller.deleteConversation(conversation.id);
    }
  }
}

/// Owns the title field until the modal route finishes its dismissal.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.title});

  final String title;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  // The whole title selected: renaming is usually replacing.
  late final _text = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.title,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: widget.title.length,
      ),
    ),
  )..addListener(_changed);

  void _changed() => setState(() {});

  bool get _valid {
    final title = _text.text.trim();
    return title.isNotEmpty &&
        title.length <= FrontConversationService.maxTitleLength;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_valid) Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemTextInput(
          key: FrontConversationActionKeys.titleInput,
          controller: _text,
          label: messages.queryRenameChat,
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemModalActionBar(
          primary: DesignSystemButton(
            key: FrontConversationActionKeys.titleSave,
            label: messages.saveButton,
            fullWidth: true,
            // Nothing to save until there is a title.
            onPressed: _valid ? _save : null,
          ),
          secondary: [
            DesignSystemButton(
              label: messages.cancelButton,
              onPressed: () => Navigator.of(context).pop(),
              variant: DesignSystemButtonVariant.secondary,
            ),
          ],
        ),
      ],
    );
  }
}
