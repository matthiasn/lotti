import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';

class TagWidget extends StatelessWidget {
  const TagWidget({
    required this.tagEntity,
    required this.onTapRemove,
    super.key,
  });

  final TagEntity tagEntity;
  final void Function()? onTapRemove;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Chip(
      label: GestureDetector(
        onDoubleTap: () => beamToNamed('/settings/tags/${tagEntity.id}'),
        child: Text(tagEntity.tag),
      ),
      backgroundColor: getTagColor(tagEntity),
      visualDensity: VisualDensity.compact,
      onDeleted: onTapRemove,
      deleteIcon: const Icon(
        Icons.close_rounded,
        size: fontSizeMedium,
        color: tagTextColor,
      ),
      deleteButtonTooltipMessage: localizations.journalTagsRemoveHint,
    );
  }
}
