import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/settings/ui/pages/tags/tag_edit_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:showcaseview/showcaseview.dart';

class CreateTagPage extends StatefulWidget {
  const CreateTagPage({
    required this.tagType,
    super.key,
  });

  final String tagType;

  @override
  State<CreateTagPage> createState() => _CreateTagPageState();
}

class _CreateTagPageState extends State<CreateTagPage> {
  TagEntity? _tagEntity;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    final tag = getIt<TagsService>().match ?? '';

    if (widget.tagType == 'TAG') {
      _tagEntity = TagEntity.genericTag(
        id: uuid.v1(),
        vectorClock: null,
        createdAt: now,
        updatedAt: now,
        private: false,
        tag: tag,
      );
    }
    if (widget.tagType == 'PERSON') {
      _tagEntity = TagEntity.personTag(
        id: uuid.v1(),
        vectorClock: null,
        createdAt: now,
        updatedAt: now,
        private: false,
        tag: tag,
      );
    }
    if (widget.tagType == 'STORY') {
      _tagEntity = TagEntity.storyTag(
        id: uuid.v1(),
        vectorClock: null,
        createdAt: now,
        updatedAt: now,
        private: false,
        tag: tag,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tagEntity == null) {
      return const EmptyScaffoldWithTitle('');
    }
    return ShowCaseWidget(
      builder: (context) => TagEditPage(
        tagEntity: _tagEntity!,
        newTag: true,
      ),
    );
  }
}
