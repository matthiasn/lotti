import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/tags/tags_list_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagsModal extends StatelessWidget {
  const TagsModal({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

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

    return ColoredBox(
      color: colorConfig().ice,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 160,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TagsListWidget(),
            const SizedBox(height: 16),
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
                  child: TypeAheadField(
                    textFieldConfiguration: TextFieldConfiguration(
                      autocorrect: false,
                      //autofocus: true,
                      controller: controller,
                      onSubmitted: (String tag) async {
                        tag = tag.trim();
                        final tagId = await cubit.addTagDefinition(tag);
                        await cubit.addTagIds([tagId]);
                        controller.clear();
                      },
                      style: DefaultTextStyle.of(context).style.copyWith(
                            color: colorConfig().coal,
                            fontFamily: 'Oswald',
                            fontSize: fontSizeMedium,
                          ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    suggestionsCallback: (String pattern) async {
                      return tagsService.getMatchingTags(
                        pattern.trim(),
                        limit: isMobile ? 5 : 10,
                      );
                    },
                    suggestionsBoxDecoration: SuggestionsBoxDecoration(
                      color: colorConfig().ice,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context, TagEntity tagEntity) {
                      return ListTile(
                        title: Text(
                          tagEntity.tag,
                          style: TextStyle(
                            fontFamily: 'Oswald',
                            height: 1,
                            color: getTagColor(tagEntity),
                            fontWeight: FontWeight.normal,
                            fontSize: fontSizeMedium,
                          ),
                        ),
                      );
                    },
                    onSuggestionSelected: (TagEntity tagSuggestion) async {
                      await cubit.addTagIds([tagSuggestion.id]);
                      controller.clear();
                    },
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
                    color: colorConfig().coal,
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
                    color: colorConfig().coal,
                  ),
                  tooltip: localizations.journalTagsPasteHint,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 130 : 340),
          ],
        ),
      ),
    );
  }
}
