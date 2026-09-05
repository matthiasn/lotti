import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/flags/language_flag.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_ui/material_ui.dart';

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
    return DsActionRow(
      icon: LottiIcons.linkOff,
      title: context.messages.journalUnlinkHint,
      onTap: () async {
        const unlinkKey = 'unlinkKey';
        final result = await showModalActionSheet<String>(
          context: context,
          title: context.messages.journalUnlinkQuestion,
          actions: [
            ModalSheetAction(
              icon: LottiIcons.warning,
              label: context.messages.journalUnlinkConfirm,
              key: unlinkKey,
              isDestructiveAction: true,
            ),
          ],
        );

        if (result == unlinkKey) {
          final notifier = ref.read(
            linkedEntriesControllerProvider(linkedFromId).notifier,
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
    final provider = linkedEntriesControllerProvider(link.fromId);
    final notifier = ref.read(provider.notifier);

    return DsActionRow(
      icon: hidden ? LottiIcons.hidden : LottiIcons.visible,
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
    final provider = entryControllerProvider(entryId);
    final entryState = ref.watch(provider).value;
    final notifier = ref.read(provider.notifier);

    final item = entryState?.entry;
    if (item == null || item is! JournalImage) {
      return const SizedBox.shrink();
    }

    return DsActionRow(
      icon: LottiIcons.copy,
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
    final provider = entryControllerProvider(entryId);
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
    final icon = markdown ? LottiIcons.code : LottiIcons.copy;

    return DsActionRow(
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
    final provider = entryControllerProvider(entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    // Only show for non-task entries (tasks have their own labels UI)
    if (entry == null || entry is Task) {
      return const SizedBox.shrink();
    }

    return DsActionRow(
      icon: LottiIcons.label,
      title: context.messages.entryLabelsActionTitle,
      subtitle: context.messages.entryLabelsActionSubtitle,
      trailing: DsActionRowTrailing.chevron,
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

/// The 4:3 proportion every flag in `country_flags` is drawn at. Named so the
/// width beside a language name follows the caption's line height instead of
/// being a second hand-tuned number.
const double _flagAspectRatio = 4 / 3;

/// Modern styled set-language action item for tasks.
///
/// Names the task's current language on the row's trailing edge and opens
/// the same language selection modal used elsewhere in the app. On selection,
/// the task's `languageCode` is updated via the journal repository.
class ModernSetTaskLanguageItem extends ConsumerWidget {
  const ModernSetTaskLanguageItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(entryId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! Task) {
      return const SizedBox.shrink();
    }

    final task = entry;
    final languageCode = task.data.languageCode;
    final language = languageCode != null
        ? SupportedLanguage.fromCode(languageCode)
        : null;

    final tokens = context.designTokens;

    // Bind the update callback to the notifier while `ref` is still valid —
    // the Actions modal will be popped (unmounting this item) before the
    // language modal callback fires.
    final notifier = ref.read(entryControllerProvider(entryId).notifier);

    return DsActionRow(
      icon: LottiIcons.language,
      title: context.messages.taskLanguageSetAction,
      // The setting itself rides the trailing edge, where every other row's
      // current value would. The flag used to sit in the leading slot, which
      // put the *answer* where the rest of the sheet puts the *subject* and
      // left a row whose glyph changed meaning with the entry. It now rides
      // beside the name it belongs to, at the caption's own line height so it
      // reads as a mark on the value rather than a second icon on the row.
      trailingValue: language?.localizedName(context),
      trailingValueLeading: language == null
          ? null
          : buildLanguageFlag(
              languageCode: language.code,
              height: tokens.typography.lineHeight.caption,
              width: tokens.typography.lineHeight.caption * _flagAspectRatio,
              key: ValueKey('action-flag-${language.code}'),
            ),
      trailing: DsActionRowTrailing.chevron,
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
