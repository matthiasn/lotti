import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/state/speech_dictionary_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/pages/definitions_list_page.dart';
import 'package:material_ui/material_ui.dart';

/// The list as a desktop settings panel: no header of its own — the detail
/// pane's breadcrumb names it — and the add button beside the search.
class SpeechDictionaryListBody extends StatelessWidget {
  const SpeechDictionaryListBody({super.key});

  @override
  Widget build(BuildContext context) =>
      const SpeechDictionaryListPage(showHeader: false);
}

const _listUrl = '/settings/speech-dictionary';

/// The add page, seeded with [term] when there is one: whatever was typed
/// into the search field is already the new entry's term, whether the user
/// takes the create button or the "no match" action.
String speechDictionaryCreateUrl(String term) {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return '$_listUrl/create';
  return '$_listUrl/create?term=${Uri.encodeComponent(trimmed)}';
}

/// The speech dictionary on the shared [DefinitionsListPage] shell.
///
/// Each row leads with the term's first letter, followed by the term and,
/// as its second line, the categories it is limited to (or "All
/// categories"). Search also matches misheard spellings; a query with no
/// match offers adding it as a term, and the create button carries the
/// query along too, so the editor opens with it filled in.
class SpeechDictionaryListPage extends ConsumerWidget {
  const SpeechDictionaryListPage({this.showHeader = true, super.key});

  /// See [DefinitionsListPage.showHeader].
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final categories = ref.watch(entitiesCacheServiceProvider);

    return DefinitionsListPage<SpeechDictionaryEntry>(
      showHeader: showHeader,
      itemsAsync: ref.watch(speechDictionaryEntriesProvider),
      title: messages.settingsSpeechDictionaryTitle,
      searchHint: messages.settingsSpeechDictionarySearchHint,
      displayName: (entry) => entry.term,
      searchText: (entry) => [entry.term, ...?entry.misheardAs].join(' '),
      emptyIcon: LottiIcons.book,
      emptyTitle: messages.settingsSpeechDictionaryEmptyState,
      emptyHint: messages.settingsSpeechDictionaryEmptyStateHint,
      noMatchMessage: messages.settingsSpeechDictionaryNoMatchQuery,
      noMatchActionBuilder: (context, query) => DesignSystemButton(
        label: context.messages.settingsSpeechDictionaryNoMatchCreate(query),
        leadingIcon: LottiIcons.add,
        onPressed: () => beamToNamed(speechDictionaryCreateUrl(query)),
      ),
      errorTitle: messages.settingsSpeechDictionaryErrorLoading,
      createLabel: messages.settingsSpeechDictionaryCreateTitle,
      onCreate: (query) => beamToNamed(speechDictionaryCreateUrl(query)),
      itemBuilder: (context, entry, {required ListRowDivider divider}) =>
          _EntryListItem(
            entry: entry,
            divider: divider,
            categories: categories,
          ),
    );
  }
}

/// The categories [entry] is limited to, by name and sorted, or "All
/// categories". Categories [categories] does not know are left out.
String speechDictionaryScopeLabel(
  SpeechDictionaryEntry entry,
  AppLocalizations messages,
  EntitiesCacheService? categories,
) {
  if (entry.appliesToAllCategories || categories == null) {
    return messages.settingsSpeechDictionaryAllCategories;
  }
  final names =
      entry.categoryIds!
          .map(categories.getCategoryById)
          .whereType<CategoryDefinition>()
          .map((category) => category.name)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names.isEmpty
      ? messages.settingsSpeechDictionaryAllCategories
      : names.join(', ');
}

class _EntryListItem extends StatelessWidget {
  const _EntryListItem({
    required this.entry,
    required this.divider,
    required this.categories,
  });

  final SpeechDictionaryEntry entry;
  final ListRowDivider divider;
  final EntitiesCacheService? categories;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DesignSystemListItem(
      title: entry.term,
      // Every row's second line answers the same question: where the term
      // applies.
      subtitle: speechDictionaryScopeLabel(
        entry,
        context.messages,
        categories,
      ),
      leading: DefinitionIconChip(
        background: tokens.colors.background.level03,
        foreground: tokens.colors.text.mediumEmphasis,
        name: entry.term,
      ),
      trailing: Icon(
        LottiIcons.chevronRight,
        size: tokens.spacing.step6,
        color: tokens.colors.text.lowEmphasis,
      ),
      showDivider: divider.showDivider,
      dividerColor: divider.color,
      dividerIndent:
          tokens.spacing.step5 +
          DefinitionIconChip.defaultSize +
          tokens.spacing.step3,
      onHoverChanged: divider.onHoverChanged,
      onTap: () => beamToNamed('$_listUrl/${entry.id}'),
    );
  }
}
