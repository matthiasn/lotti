import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagAddIconWidget extends ConsumerWidget {
  TagAddIconWidget({
    required this.entryId,
    super.key,
  });

  final String entryId;
  final TagsService tagsService = getIt<TagsService>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null) {
      return const SizedBox.shrink();
    }

    void onTapAdd() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) {
          return TagsModal(entryId: entryId);
        },
      );
    }

    return SizedBox(
      width: 40,
      child: IconButton(
        onPressed: onTapAdd,
        icon: Icon(MdiIcons.tag),
        splashColor: Colors.transparent,
        tooltip: context.messages.journalTagPlusHint,
      ),
    );
  }
}
