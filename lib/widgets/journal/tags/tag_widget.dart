import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
      deleteIcon: Icon(
        MdiIcons.close,
        size: fontSizeMedium,
        color: styleConfig().tagTextColor,
      ),
      deleteButtonTooltipMessage: localizations.journalTagsRemoveHint,
    );
  }
}
