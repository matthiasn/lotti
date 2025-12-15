import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'linked_ai_responses_controller.g.dart';

/// Controller for fetching AI responses linked to a specific entry (e.g., audio).
///
/// This is used to display nested AI responses under audio entries in the task view,
/// showing generated prompts and other AI responses directly where they are relevant.
@riverpod
class LinkedAiResponsesController extends _$LinkedAiResponsesController {
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final _watchedIds = <String>{};

  void _listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.contains(entryId) ||
          affectedIds.intersection(_watchedIds).isNotEmpty) {
        _fetch().then((latest) {
          if (!_listEquals(latest, state.value)) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  bool _listEquals(List<AiResponseEntry>? a, List<AiResponseEntry>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].meta.id != b[i].meta.id ||
          a[i].meta.updatedAt != b[i].meta.updatedAt) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<List<AiResponseEntry>> build({
    required String entryId,
  }) async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final results = await _fetch();
    _listen();
    return results;
  }

  Future<List<AiResponseEntry>> _fetch() async {
    final journalRepository = ref.read(journalRepositoryProvider);

    // Get all links FROM this entry (audio links TO ai responses)
    // Link structure: fromId=audio, toId=aiResponse
    final links = await journalRepository.getLinksFromId(entryId);

    // Clear and rebuild watched IDs to avoid stale references
    _watchedIds
      ..clear()
      ..add(entryId);

    // Fetch each linked entity and filter for AI responses
    final aiResponses = <AiResponseEntry>[];
    for (final link in links) {
      final entity = await journalRepository.getJournalEntityById(link.toId);
      if (entity is AiResponseEntry && entity.meta.deletedAt == null) {
        aiResponses.add(entity);
        _watchedIds.add(entity.meta.id);
      }
    }

    // Sort by date (newest first)
    aiResponses.sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

    return aiResponses;
  }
}
