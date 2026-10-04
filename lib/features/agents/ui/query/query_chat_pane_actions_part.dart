part of 'query_chat_pane.dart';

/// Turns bare answer citations into local links without changing Markdown's
/// code spans/blocks, existing links, or numeric reference definitions.
String _linkEvidenceCitations(String text, int evidenceCount) {
  final referenceLabels = RegExp(
    r'^ {0,3}\[([^\]\n]+)\]:',
    multiLine: true,
  ).allMatches(text).map((match) => match[1]).toSet();
  final referencePattern = referenceLabels
      .whereType<String>()
      .map(RegExp.escape)
      .join('|');
  // The first alternatives consume protected Markdown before the final
  // numeric-citation alternative can see anything inside it. An unclosed
  // fence protects the remainder of the answer as code, too.
  final tokens = RegExp(
    [
      [
        r'(^[ \t]{0,3}(`{3,}|~{3,})[^\n]*(?:\n|$)[\s\S]*?',
        r'(?:^[ \t]{0,3}\2[`~]*[ \t]*(?=\n|$)|(?![\s\S])))',
      ].join(),
      r'(`+)[\s\S]*?\3',
      r'^(?: {4}|\t)[^\n]*',
      r'\\.',
      r'!?\[[^\]\n]*\]\([^\)\n]*\)',
      // Adjacent citations are links individually unless the second bracket
      // actually names a reference definition (Markdown labels ignore case).
      if (referencePattern.isNotEmpty) ...[
        [
          r'!?\[[^\]\n]*\][ \t]*(?:\n[ \t]*)?\[(?:',
          referencePattern,
          r')\]',
        ].join(),
        [r'!?\[(?:', referencePattern, r')\][ \t]*\[\]'].join(),
      ],
      r'\[(\d+)\](?!:)',
    ].join('|'),
    multiLine: true,
    caseSensitive: false,
  );
  return text.replaceAllMapped(tokens, (match) {
    final label = match[4];
    if (label == null || referenceLabels.contains(label)) return match[0]!;
    final number = int.tryParse(label);
    return number != null && number > 0 && number <= evidenceCount
        ? '[$label](#query-evidence-$label)'
        : '($label)';
  });
}

/// Conversation actions for the query chat pane that write no state themselves: opening citations, guarding async work, rename, archive and delete.
extension _QueryChatPaneActions on _QueryChatPaneState {
  Future<void> _openCitation(
    AgentChatMessage message,
    String url,
    String title,
    QueryChatHistory? chat,
  ) async {
    final match = RegExp(r'^#query-evidence-(\d+)$').firstMatch(url);
    if (match == null) {
      await handleMarkdownLinkTap(url, title);
      return;
    }
    final number = int.tryParse(match[1]!);
    if (number == null) return;
    final index = number - 1;
    final answer = chat?.events
        .where((e) => e.id == message.id)
        .firstOrNull
        ?.data;
    if (answer is! QueryChatAnswer ||
        index < 0 ||
        index >= answer.evidence.length) {
      return;
    }
    final source = answer.evidence[index].source;
    final fresh = await ref.read(querySourceAccessProvider).load([source.id]);
    if (!mounted) return;
    final current = QueryAccessSnapshot(
      showPrivate: ref.read(configFlagProvider('private')).value == true,
      categories: fresh.categories,
      entries: fresh.entries,
      lockdown: ref.read(lockdownControllerProvider),
    );
    if (current.allowsReference(source)) {
      _evidenceKeys[(message.id, index)]?.currentState?.reveal();
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      }
    }
  }

  Future<JournalEntity?> _visibleSource(String id) async {
    final fresh = await ref.read(querySourceAccessProvider).load([id]);
    if (!mounted || !ref.read(queryChatEnabledProvider)) return null;
    final current = QueryAccessSnapshot(
      showPrivate: ref.read(configFlagProvider('private')).value == true,
      categories: fresh.categories,
      entries: fresh.entries,
      lockdown: ref.read(lockdownControllerProvider),
    );
    final entry = current.entries[id];
    return entry != null && current.allowsEntry(entry) ? entry : null;
  }

  Future<void> _rename(
    QueryChatController controller,
    QueryChatHistory chat,
  ) async {
    _closeMenu();
    final authoredPrivate =
        chat.private || ref.read(configFlagProvider('private')).value == true;
    final result = await ModalUtils.showSinglePageModal<String>(
      context: context,
      builder: (context) => _QueryRenameDialog(
        controller: controller,
        chat: chat,
        private: authoredPrivate,
      ),
    );
    if (result != null) {
      await controller.rename(chat.id, result, private: authoredPrivate);
    }
  }

  Future<void> _archive(
    QueryChatController controller,
    String id, {
    required bool archived,
  }) async {
    await controller.archive(id, archived: archived);
    if (mounted && archived) {
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: context.messages.queryArchiveConfirmation,
      );
    }
  }

  Future<void> _delete(
    QueryChatController controller,
    QueryChatHistory chat,
  ) async {
    _closeMenu();
    var forget = false;
    final result = await ModalUtils.showSinglePageModal<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                messages.queryDeleteExplanation,
                style: tokens.typography.styles.body.bodyMedium,
              ),
              SizedBox(height: tokens.spacing.step4),
              for (final value in [false, true])
                DesignSystemSelectionRow(
                  title: value
                      ? messages.queryForgetConclusions
                      : messages.queryKeepConclusions,
                  type: DesignSystemSelectionRowType.singleSelect,
                  selected: forget == value,
                  onTap: () => setModalState(() => forget = value),
                ),
              SizedBox(height: tokens.spacing.step5),
              DesignSystemModalActionBar(
                primary: DesignSystemButton(
                  label: forget
                      ? messages.queryDeleteForget
                      : messages.queryDeleteKeep,
                  fullWidth: true,
                  variant: DesignSystemButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(forget),
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
      ),
    );
    if (result != null) await controller.delete(chat.id, forget: result);
  }
}
