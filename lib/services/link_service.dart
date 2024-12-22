import 'package:flutter/services.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tags/repository/tags_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';

class LinkService {
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final TagsService _tagsService = getIt<TagsService>();
  final JournalDb _journalDb = getIt<JournalDb>();

  String? _linkToId;
  String? _linkFromId;

  Future<void> createLink() async {
    if (_linkFromId != null && _linkToId != null) {
      await HapticFeedback.heavyImpact();

      await _persistenceLogic.createLink(
        fromId: _linkFromId!,
        toId: _linkToId!,
      );

      final linkedFrom = await _journalDb.journalEntityById(_linkFromId!);
      final linkedTagIds = linkedFrom?.meta.tagIds;
      final storyTags = _tagsService.getFilteredStoryTagIds(linkedTagIds);

      await TagsRepository.addTags(
        journalEntityId: _linkToId!,
        addedTagIds: storyTags,
      );

      await Future<void>.delayed(const Duration(minutes: 2)).then((_) {
        _linkFromId = null;
        _linkToId = null;
      });
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  void linkTo(String linkToId) {
    _linkToId = linkToId;
    createLink();
  }

  void linkFrom(String linkFromId) {
    _linkFromId = linkFromId;
    createLink();
  }
}
