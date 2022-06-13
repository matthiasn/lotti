import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/tags/tag_edit_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateTagPage extends StatefulWidget {
  final String tagType;

  const CreateTagPage({
    Key? key,
    @PathParam() required this.tagType,
  }) : super(key: key);

  @override
  State<CreateTagPage> createState() => _CreateTagPageState();
}

class _CreateTagPageState extends State<CreateTagPage> {
  TagEntity? _tagEntity;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    debugPrint(widget.tagType);
    if (widget.tagType == 'TAG') {
      _tagEntity = TagEntity.genericTag(
        id: uuid.v1(),
        vectorClock: null,
        createdAt: now,
        updatedAt: now,
        private: false,
        tag: '',
      );
    }
    if (widget.tagType == 'PERSON') {
      _tagEntity = TagEntity.personTag(
        id: uuid.v1(),
        vectorClock: null,
        createdAt: now,
        updatedAt: now,
        private: false,
        tag: '',
      );
    }
    if (widget.tagType == 'STORY') {
      _tagEntity = TagEntity.storyTag(
        id: uuid.v1(),
        vectorClock: null,
        createdAt: now,
        updatedAt: now,
        private: false,
        tag: '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tagEntity == null) {
      return const EmptyScaffoldWithTitle('');
    }
    return TagEditPage(tagEntity: _tagEntity!);
  }
}
