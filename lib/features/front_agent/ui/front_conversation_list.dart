import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_conversation_service.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the list's controls.
@visibleForTesting
abstract final class FrontConversationListKeys {
  static const Key newChat = Key('front-conversations-new');
  static const Key archived = Key('front-conversations-archived');
  static Key row(String id) => Key('front-conversation-$id');
  static Key menu(String id) => Key('front-conversation-menu-$id');
  static Key rename(String id) => Key('front-conversation-rename-$id');
  static Key archive(String id) => Key('front-conversation-archive-$id');
  static Key delete(String id) => Key('front-conversation-delete-$id');
}

/// The user's conversations with her, as a ChatGPT or Claude sidebar lists
/// them: a new one first, then the live ones newest first, searchable by
/// title, each with rename, archive and delete; the archived ones folded
/// away at the end. Picking one opens it and closes the list.
class FrontConversationList extends ConsumerStatefulWidget {
  const FrontConversationList({super.key});

  @override
  ConsumerState<FrontConversationList> createState() =>
      _FrontConversationListState();
}

class _FrontConversationListState extends ConsumerState<FrontConversationList> {
  String _query = '';
  bool _showArchived = false;

  FrontChatController get _controller =>
      ref.read(frontChatControllerProvider.notifier);

  void _closeList() =>
      ref.read(frontConversationListOpenProvider.notifier).close();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Read through `.value`: a reload keeps the list on screen.
    final index = ref.watch(frontConversationsProvider).value;
    final activeId = ref.watch(frontActiveConversationProvider).value;
    final needle = _query.trim().toLowerCase();
    final matching = [
      for (final c in index?.conversations ?? const <FrontConversation>[])
        if (needle.isEmpty || c.title.toLowerCase().contains(needle)) c,
    ];
    final live = [
      for (final c in matching)
        if (!c.archived) c,
    ];
    final archived = [
      for (final c in matching)
        if (c.archived) c,
    ];
    final hasAny = index?.conversations.isNotEmpty ?? false;

    Widget row(FrontConversation c) => _ConversationRow(
      key: FrontConversationListKeys.row(c.id),
      conversation: c,
      selected: c.id == activeId,
      onOpen: () {
        _controller.openConversation(c.id);
        _closeList();
      },
      onRename: () => _act(() => _rename(c)),
      onArchive: () => _act(() => _archive(c)),
      onDelete: () => _act(() => _delete(c)),
    );

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.step3),
      children: [
        if (hasAny) ...[
          DesignSystemSearch(
            hintText: messages.frontChatSearchChats,
            size: DesignSystemSearchSize.small,
            onChanged: (value) => setState(() => _query = value),
            onClear: () => setState(() => _query = ''),
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
        DesignSystemListItem(
          key: FrontConversationListKeys.newChat,
          title: messages.queryNewChat,
          leading: const Icon(LottiIcons.add, size: IconSizes.s),
          onTap: () {
            _controller.startConversation();
            _closeList();
          },
        ),
        for (final c in live) row(c),
        if (index != null && live.isEmpty && archived.isEmpty)
          Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Text(
              hasAny
                  ? messages.frontChatNoMatchingChats
                  : messages.frontChatNoChats,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        if (archived.isNotEmpty) ...[
          MergeSemantics(
            child: Semantics(
              expanded: _showArchived,
              child: DesignSystemListItem(
                key: FrontConversationListKeys.archived,
                title: '${messages.queryArchivedChats} · ${archived.length}',
                leading: const Icon(LottiIcons.archive, size: IconSizes.s),
                trailing: Icon(
                  _showArchived ? LottiIcons.collapse : LottiIcons.expand,
                  size: IconSizes.s,
                ),
                onTap: () => setState(() => _showArchived = !_showArchived),
              ),
            ),
          ),
          if (_showArchived)
            for (final c in archived) row(c),
        ],
      ],
    );
  }

  /// Runs one menu action; a write that fails says so instead of being
  /// lost, and the list stays as it was.
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on Exception {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.frontChatActionFailed,
        );
      }
    }
  }

  Future<void> _rename(FrontConversation conversation) async {
    final title = await ModalUtils.showSinglePageModal<String>(
      context: context,
      builder: (context) => _RenameDialog(title: conversation.title),
    );
    if (title != null) {
      await _controller.renameConversation(conversation.id, title);
    }
  }

  Future<void> _archive(FrontConversation conversation) async {
    final archiving = !conversation.archived;
    await _controller.archiveConversation(
      conversation.id,
      archived: archiving,
    );
    if (mounted && archiving) {
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.frontChatArchivedToast,
      );
    }
  }

  Future<void> _delete(FrontConversation conversation) async {
    final confirmed = await ModalUtils.showSinglePageModal<bool>(
      context: context,
      builder: (context) {
        final messages = context.messages;
        final tokens = context.designTokens;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.queryDeleteChat,
              style: tokens.typography.styles.heading.heading3,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.frontChatDeleteExplanation,
              style: tokens.typography.styles.body.bodyMedium,
            ),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemModalActionBar(
              primary: DesignSystemButton(
                key: const Key('front-conversation-delete-confirm'),
                label: messages.queryDeleteChat,
                fullWidth: true,
                variant: DesignSystemButtonVariant.danger,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              secondary: [
                DesignSystemButton(
                  label: messages.cancelButton,
                  variant: DesignSystemButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await _controller.deleteConversation(conversation.id);
    }
  }
}

/// One conversation: its title, when it last moved, and its menu.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.selected,
    required this.onOpen,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  final FrontConversation conversation;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final id = conversation.id;
    return DesignSystemListItem(
      title: conversation.title,
      subtitle: _when(context, conversation.lastActivity),
      selected: selected,
      activated: selected,
      onTap: onOpen,
      trailing: DesignSystemContextMenuButton(
        key: FrontConversationListKeys.menu(id),
        items: [
          DesignSystemContextMenuItem(
            key: FrontConversationListKeys.rename(id),
            label: messages.queryRenameChat,
            icon: LottiIcons.edit,
            onTap: onRename,
          ),
          DesignSystemContextMenuItem(
            key: FrontConversationListKeys.archive(id),
            label: conversation.archived
                ? messages.queryRestoreChat
                : messages.queryArchiveChat,
            icon: conversation.archived
                ? LottiIcons.unarchive
                : LottiIcons.archive,
            onTap: onArchive,
          ),
          DesignSystemContextMenuItem(
            key: FrontConversationListKeys.delete(id),
            label: messages.queryDeleteChat,
            icon: LottiIcons.delete,
            isDestructive: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  /// The time for today, the date for any other day.
  static String _when(BuildContext context, DateTime at) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return today
        ? DateFormat.jm(locale).format(at)
        : DateFormat.yMMMd(locale).format(at);
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
  late final _text = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final title = _text.text.trim();
    if (title.isNotEmpty &&
        title.length <= FrontConversationService.maxTitleLength) {
      Navigator.of(context).pop(title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemTextInput(
          key: const Key('front-conversation-title-input'),
          controller: _text,
          label: messages.queryRenameChat,
          autofocus: true,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemModalActionBar(
          primary: DesignSystemButton(
            key: const Key('front-conversation-title-save'),
            label: messages.saveButton,
            fullWidth: true,
            onPressed: _save,
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
