import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/widgets/journal/tags/tags_list_widget.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagsModal extends StatefulWidget {
  const TagsModal({
    super.key,
  });

  @override
  State<TagsModal> createState() => _TagsModalState();
}

class _TagsModalState extends State<TagsModal> {
  List<TagEntity> suggestions = [];

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final tagsService = getIt<TagsService>();
    final localizations = AppLocalizations.of(context)!;
    final cubit = context.read<EntryCubit>();
    final item = cubit.entry;

    void copyTags() {
      if (item.meta.tagIds != null) {
        HapticFeedback.heavyImpact();
        tagsService.setClipboard(item.meta.id);
      }
    }

    Future<void> pasteTags() async {
      final tagsFromClipboard = await tagsService.getClipboard();
      await cubit.addTagIds(tagsFromClipboard);
      await HapticFeedback.heavyImpact();
    }

    Future<void> onSuggestionSelected(TagEntity tagSuggestion) async {
      await cubit.addTagIds([tagSuggestion.id]);

      setState(() {
        suggestions = [];
        _controller.clear();
      });
    }

    Future<void> onSubmitted(String tag) async {
      final tagId = await cubit.addTagDefinition(tag.trim());
      await cubit.addTagIds([tagId]);
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
                  child: Text(
                    localizations.journalTagsLabel,
                    style: formLabelStyle(),
                  ),
                ),
                Expanded(
                  child: CupertinoTextField(
                    controller: _controller,
                    onSubmitted: onSubmitted,
                    onChanged: onChanged,
                    autofocus: true,
                    keyboardAppearance: keyboardAppearance(),
                    style: chartTitleStyle(),
                    cursorColor: styleConfig().primaryColor,
                  ),
                ),
                IconButton(
                  onPressed: copyTags,
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 16,
                    bottom: 16,
                  ),
                  icon: Icon(
                    MdiIcons.contentCopy,
                    color: styleConfig().primaryTextColor,
                  ),
                  tooltip: localizations.journalTagsCopyHint,
                ),
                IconButton(
                  onPressed: pasteTags,
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 16,
                    bottom: 16,
                  ),
                  icon: Icon(
                    MdiIcons.contentPaste,
                    color: styleConfig().primaryTextColor,
                  ),
                  tooltip: localizations.journalTagsPasteHint,
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 25),
              child: TagsListWidget(),
            ),
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
