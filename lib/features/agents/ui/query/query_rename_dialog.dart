import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_chat_controller.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Owns the input until the modal route finishes its dismissal animation.
class QueryRenameDialog extends ConsumerStatefulWidget {
  const QueryRenameDialog({
    required this.controller,
    required this.chat,
    required this.private,
    super.key,
  });
  final QueryChatController controller;
  final QueryChatHistory chat;
  final bool private;

  @override
  ConsumerState<QueryRenameDialog> createState() => _QueryRenameDialogState();
}

class _QueryRenameDialogState extends ConsumerState<QueryRenameDialog> {
  late final _text = TextEditingController(text: widget.chat.title);
  late bool _authoredPrivate = widget.private;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(queryChatDataProvider(widget.controller.key)).value;
    final showPrivate = ref.watch(configFlagProvider('private')).value ?? false;
    final lockdown = ref.watch(lockdownControllerProvider);
    final access = data == null
        ? null
        : QueryAccessSnapshot(
            showPrivate: showPrivate,
            categories: data.access.categories,
            entries: data.access.entries,
            lockdown: lockdown,
          );
    final current = data?.projection.chats
        .where((candidate) => candidate.id == widget.chat.id)
        .firstOrNull;
    final home = access?.entries[widget.controller.key.scope.id];
    final homeVisible =
        access != null &&
        (widget.controller.key.scope.kind == QueryScopeKind.category
            ? access.allowsCategory(widget.controller.key.scope.id)
            : home != null && access.allowsEntry(home));
    final visible =
        homeVisible &&
        current != null &&
        (!(_authoredPrivate || current.private) || showPrivate) &&
        current.events.every(
          (event) => access.allowsEvent(event.data),
        );
    _authoredPrivate = _authoredPrivate || showPrivate;
    if (!visible) {
      // Remove the field before the modal's dismissal animation so
      // neither the saved title nor newly typed text flashes on lock.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          _text.clear();
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemTextInput(
          controller: _text,
          label: context.messages.queryRenameChat,
          autofocus: true,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemModalActionBar(
          primary: DesignSystemButton(
            label: context.messages.saveButton,
            fullWidth: true,
            onPressed: () {
              if (_text.text.trim().isNotEmpty &&
                  _text.text.trim().length <= 120) {
                Navigator.of(context).pop(_text.text.trim());
              }
            },
          ),
          secondary: [
            DesignSystemButton(
              label: context.messages.cancelButton,
              onPressed: () => Navigator.of(context).pop(),
              variant: DesignSystemButtonVariant.secondary,
            ),
          ],
        ),
      ],
    );
  }
}
