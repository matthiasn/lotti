import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagAddListTile extends ConsumerWidget {
  TagAddListTile({
    required this.entryId,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final TagsService tagsService = getIt<TagsService>();
  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: Icon(MdiIcons.tag),
      title: Text(context.messages.journalTagPlusHint),
      onTap: () => pageIndexNotifier.value = 1,
    );
  }
}
