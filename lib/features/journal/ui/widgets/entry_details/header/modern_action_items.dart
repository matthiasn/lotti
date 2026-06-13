import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/action_menu_list_item.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/flags/language_flag.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

export 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_advanced_action_items.dart';
export 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_media_action_items.dart';
export 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_toggle_action_items.dart';

class ModernUnlinkItem extends ConsumerWidget {
  const ModernUnlinkItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionMenuListItem(
      icon: Icons.link_off_rounded,
      title: context.messages.journalUnlinkHint,
      onTap: () async {
        const unlinkKey = 'unlinkKey';
        final result = await showModalActionSheet<String>(
          context: context,
          title: context.messages.journalUnlinkQuestion,
          actions: [
            ModalSheetAction(
              icon: Icons.warning,
              label: context.messages.journalUnlinkConfirm,
              key: unlinkKey,
              isDestructiveAction: true,
            ),
          ],
        );

        if (result == unlinkKey) {
          final notifier = ref.read(
            linkedEntriesControllerProvider(id: linkedFromId).notifier,
          );
          await notifier.removeLink(toId: entryId);
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern styled toggle hidden action item
class ModernToggleHiddenItem extends ConsumerWidget {
  const ModernToggleHiddenItem({
    required this.link,
    super.key,
  });

  final EntryLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = link.hidden ?? false;
    final provider = linkedEntriesControllerProvider(id: link.fromId);
    final notifier = ref.read(provider.notifier);

    return ActionMenuListItem(
      icon: hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      title: hidden
          ? context.messages.journalShowLinkHint
          : context.messages.journalHideLinkHint,
      onTap: () {
        final updatedLink = link.copyWith(hidden: !hidden);
        notifier.updateLink(updatedLink);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled copy image action item
class ModernCopyImageItem extends ConsumerWidget {
  const ModernCopyImageItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final notifier = ref.read(provider.notifier);

    final item = entryState?.entry;
    if (item == null || item is! JournalImage) {
      return const SizedBox.shrink();
    }

    return ActionMenuListItem(
      icon: MdiIcons.contentCopy,
      title: context.messages.journalCopyImageLabel,
      onTap: () async {
        await notifier.copyImage();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Reusable copy entry text action item (plain or markdown)
class ModernCopyEntryTextItem extends ConsumerWidget {
  const ModernCopyEntryTextItem({
    required this.entryId,
    required this.markdown,
    super.key,
  });

  final String entryId;
  final bool markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final hasText = notifier.controller.document
        .toPlainText()
        .trim()
        .isNotEmpty;
    final entry = entryState?.entry;
    if (!hasText || entry == null) {
      return const SizedBox.shrink();
    }

    final title = markdown
        ? context.messages.copyAsMarkdown
        : context.messages.copyAsText;
    final icon = markdown ? Icons.code : MdiIcons.contentCopy;

    return ActionMenuListItem(
      icon: icon,
      title: title,
      onTap: () async {
        if (markdown) {
          await notifier.copyEntryTextMarkdown();
        } else {
          await notifier.copyEntryTextPlain();
        }
        if (context.mounted) {
          await Navigator.of(context).maybePop();
        }
      },
    );
  }
}

/// Modern styled labels action item for non-task entries.
/// Opens a dedicated single-page modal for label selection.
class ModernLabelsItem extends ConsumerWidget {
  const ModernLabelsItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    // Only show for non-task entries (tasks have their own labels UI)
    if (entry == null || entry is Task) {
      return const SizedBox.shrink();
    }

    return ActionMenuListItem(
      icon: MdiIcons.labelOutline,
      title: context.messages.entryLabelsActionTitle,
      subtitle: context.messages.entryLabelsActionSubtitle,
      onTap: () async {
        // Close the multi-page modal first
        Navigator.of(context).pop();
        if (!context.mounted) return;
        // Open dedicated labels modal
        await _openLabelsModal(context, entry);
      },
    );
  }

  Future<void> _openLabelsModal(
    BuildContext context,
    JournalEntity entry,
  ) async {
    await LabelSelectionModalUtils.openLabelSelector(
      context: context,
      entryId: entryId,
      initialLabelIds: entry.meta.labelIds ?? <String>[],
      categoryId: entry.meta.categoryId,
    );
  }
}

/// Modern styled set-language action item for tasks.
///
/// Renders the currently selected language's flag (or a generic language
/// glyph when none is set) next to the action text, and opens the same
/// language selection modal used elsewhere in the app. On selection, the
/// task's `languageCode` is updated via the journal repository.
class ModernSetTaskLanguageItem extends ConsumerWidget {
  const ModernSetTaskLanguageItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! Task) {
      return const SizedBox.shrink();
    }

    final task = entry;
    final languageCode = task.data.languageCode;
    final language = languageCode != null
        ? SupportedLanguage.fromCode(languageCode)
        : null;

    final leading = language != null
        ? SizedBox(
            width: 32,
            height: 24,
            child: buildLanguageFlag(
              languageCode: language.code,
              height: 24,
              width: 32,
              key: ValueKey('action-flag-${language.code}'),
            ),
          )
        : Icon(
            Icons.language,
            size: AppTheme.listItemIconSize,
            color: context.colorScheme.onSurface,
          );

    // Bind the update callback to the notifier while `ref` is still valid —
    // the Actions modal will be popped (unmounting this item) before the
    // language modal callback fires.
    final notifier = ref.read(entryControllerProvider(id: entryId).notifier);

    return ActionMenuListItem(
      leading: leading,
      title: context.messages.taskLanguageSetAction,
      onTap: () async {
        Navigator.of(context).pop();
        if (!context.mounted) return;
        await _openLanguageSelector(
          context: context,
          initialLanguageCode: task.data.languageCode,
          onLanguageChanged: notifier.updateTaskLanguage,
        );
      },
    );
  }

  Future<void> _openLanguageSelector({
    required BuildContext context,
    required String? initialLanguageCode,
    required Future<void> Function(String?) onLanguageChanged,
  }) async {
    final searchQuery = ValueNotifier<String>('');
    final searchController = TextEditingController();

    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        titleWidget: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: LanguageSelectionModalContent.buildHeader(
            context: context,
            controller: searchController,
            queryNotifier: searchQuery,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        builder: (BuildContext modalContext) {
          return LanguageSelectionModalContent(
            initialLanguageCode: initialLanguageCode,
            searchQuery: searchQuery,
            onLanguageSelected: (SupportedLanguage? language) async {
              await onLanguageChanged(language?.code);
              if (!modalContext.mounted) return;
              Navigator.pop(modalContext);
            },
          );
        },
      );
    } finally {
      searchController.dispose();
      searchQuery.dispose();
    }
  }
}
