import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a sheet for choosing several of the people the user keeps — who
/// was at an event — seeded with [initialSelectedIds].
///
/// Rows toggle a staged set; *Apply* returns it, and dismissing returns
/// null, so nothing is written until the user commits. The caller diffs the
/// result against what was linked before.
Future<Set<String>?> showPersonPicker({
  required BuildContext context,
  required String title,
  required Set<String> initialSelectedIds,
}) async {
  final staged = ValueNotifier<Set<String>>({...initialSelectedIds});
  try {
    return await ModalUtils.showSinglePageModal<Set<String>>(
      context: context,
      title: title,
      padding: EdgeInsets.zero,
      stickyActionBarBuilder: (footerContext) => buildPickerApplyFooter(
        context: footerContext,
        label: footerContext.messages.tasksLabelsSheetApply,
        onTap: () => Navigator.of(footerContext).pop(staged.value),
        buttonKey: const ValueKey('person-picker-apply'),
      ),
      builder: (_) => PersonPickerSheet(stagedNotifier: staged),
    );
  } finally {
    staged.dispose();
  }
}

/// The people adapter over [EntityPickerSheet]: everyone on the People
/// page, by name, each with their face, filtered by the search field.
class PersonPickerSheet extends ConsumerWidget {
  const PersonPickerSheet({required this.stagedNotifier, super.key});

  final ValueNotifier<Set<String>> stagedNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = [
      for (final item
          in ref.watch(relationshipsListControllerProvider).value ??
              const <RelationshipListItem>[])
        item.relationship,
    ]..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));

    List<PickerItem> entries(String query) {
      final q = query.trim().toLowerCase();
      return [
        for (final person in people)
          if (q.isEmpty || _matches(person, q)) _item(person),
      ];
    }

    return EntityPickerSheet(
      mode: PickerMode.multi,
      entriesBuilder: entries,
      searchHintText: context.messages.relationshipPickerSearchHint,
      emptyMessage: context.messages.filterSelectionNoMatches,
      stagedNotifier: stagedNotifier,
    );
  }

  static String _name(RelationshipEntry person) => person.data.title;

  /// A person matches by name or by the nickname the user calls them.
  static bool _matches(RelationshipEntry person, String query) =>
      person.data.title.toLowerCase().contains(query) ||
      (person.data.nickname?.toLowerCase().contains(query) ?? false);

  static PickerItem _item(RelationshipEntry person) {
    final data = person.data;
    final nickname = data.nickname?.trim();
    return PickerItem(
      id: person.meta.id,
      rowKey: ValueKey('person-picker-row-${person.meta.id}'),
      leading: PersonaAvatar(
        initial: personaInitial(data.title),
        id: person.meta.id,
        imageId: data.avatarImageId,
        crop: data.avatarCrop,
      ),
      title: data.title,
      subtitle: nickname == null || nickname.isEmpty || nickname == data.title
          ? null
          : nickname,
    );
  }
}
