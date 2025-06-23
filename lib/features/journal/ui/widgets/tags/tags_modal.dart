import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_list_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagsModal extends ConsumerStatefulWidget {
  const TagsModal({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  ConsumerState<TagsModal> createState() => _TagsModalState();
}

class _TagsModalState extends ConsumerState<TagsModal> {
  List<TagEntity> suggestions = [];
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final tagsService = getIt<TagsService>();

    final item = entryState?.entry;

    if (item == null) {
      return const SizedBox.shrink();
    }

    void copyTags() {
      if (item.meta.tagIds != null) {
        HapticFeedback.heavyImpact();
        tagsService.setClipboard(item.meta.id);
      }
    }

    Future<void> pasteTags() async {
      final tagsFromClipboard = await tagsService.getClipboard();
      await notifier.addTagIds(tagsFromClipboard);
      await HapticFeedback.heavyImpact();
    }

    Future<void> onSuggestionSelected(TagEntity tagSuggestion) async {
      await notifier.addTagIds([tagSuggestion.id]);

      setState(() {
        suggestions = [];
        _controller.clear();
      });
    }

    Future<void> onSubmitted(String tag) async {
      final tagId = await notifier.addTagDefinition(tag.trim());
      await notifier.addTagIds([tagId]);
      _controller.clear();
    }

    Future<void> onChanged(String pattern) async {
      final newSuggestions = await tagsService.getMatchingTags(
        pattern.trim(),
      );

      setState(() {
        suggestions = newSuggestions;
      });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: ListView(
                shrinkWrap: true,
                children: List.generate(
                  suggestions.length,
                  (int index) {
                    final tag = suggestions.elementAt(index);
                    return TagCard(
                      tagEntity: tag,
                      index: index,
                      onTap: () => onSuggestionSelected(tag),
                    );
                  },
                ),
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(context.messages.journalTagsLabel),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                    ),
                    child: CupertinoTextField(
                      controller: _controller,
                      onSubmitted: onSubmitted,
                      onChanged: onChanged,
                      style: TextStyle(
                        color: context.textTheme.titleLarge?.color,
                      ),
                      cursorColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: copyTags,
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 16,
                    bottom: 16,
                  ),
                  icon: Icon(MdiIcons.contentCopy),
                  tooltip: context.messages.journalTagsCopyHint,
                ),
                IconButton(
                  onPressed: pasteTags,
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 16,
                    bottom: 16,
                  ),
                  icon: Icon(MdiIcons.contentPaste),
                  tooltip: context.messages.journalTagsPasteHint,
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 25),
              child: TagsListWidget(entryId: widget.entryId),
            ),
            verticalModalSpacer,
          ],
        ),
      ),
    );
  }
}

class TagCard extends StatelessWidget {
  const TagCard({
    required this.tagEntity,
    required this.onTap,
    required this.index,
    super.key,
  });

  final TagEntity tagEntity;
  final int index;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 32,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          color: getTagColor(tagEntity),
          width: 20,
          height: 20,
        ),
      ),
      title: tagEntity.tag,
    );
  }
}
