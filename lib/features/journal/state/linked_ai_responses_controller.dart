// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// Controller for fetching AI responses linked to a specific entry (e.g., audio).
///
/// This is used to display nested AI responses under audio entries in the task view,
/// showing generated prompts and other AI responses directly where they are relevant.
final linkedAiResponsesControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LinkedAiResponsesController, List<AiResponseEntry>, String>(
      LinkedAiResponsesController.new,
    );

class LinkedAiResponsesController extends AsyncNotifier<List<AiResponseEntry>> {
  LinkedAiResponsesController(this.entryId);

  final String entryId;
  StreamSubscription<Set<String>>? _updateSubscription;
  late final UpdateNotifications _updateNotifications;
  final _watchedIds = <String>{};

  @override
  Future<List<AiResponseEntry>> build() async {
    _updateNotifications = ref.read(updateNotificationsProvider);
    ref.onDispose(() => _updateSubscription?.cancel());
    _listen();
    final results = await _fetch();
    _watchedIds.add(entryId);
    return results;
  }

  void _listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) async {
      if (affectedIds.contains(entryId) ||
          affectedIds.intersection(_watchedIds).isNotEmpty) {
        try {
          final latest = await _fetch();
          if (!_listEquals(latest, state.value)) {
            state = AsyncData(latest);
          }
        } catch (e) {
          // Keep previous state on error rather than transitioning to error state
        }
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

  Future<List<AiResponseEntry>> _fetch() async {
    final journalRepository = ref.read(journalRepositoryProvider);

    // Get all links FROM this entry (audio links TO ai responses)
    // Link structure: fromId=audio, toId=aiResponse
    final links = await journalRepository.getLinksFromId(entryId);
    if (links.isEmpty) return const <AiResponseEntry>[];

    // One bulk fetch instead of N parallel single-id reads. The previous
    // `Future.wait(links.map(byId))` was a textbook N+1 — every link
    // queued through the read pool and the cluster showed up as ~12
    // single-id selects all reporting the same elapsed time in the
    // super-slow log because they unblocked together.
    final entities = await journalRepository.getJournalEntitiesByIds(
      links.map((link) => link.toId),
    );

    // Filter for non-deleted AI responses and track their IDs
    final aiResponses = <AiResponseEntry>[];
    for (final entity in entities) {
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

/// The entry AI responses hang off, and the task it is shown in.
typedef TaskScopedAiResponsesParams = ({String entryId, String taskId});

/// The AI responses nested under an entry, as they belong in the task the
/// entry is shown in.
///
/// A coding prompt belongs to the task it was generated for — that task links
/// to it — and is also linked back from the recording or note it was made
/// from. A recording can sit in more than one task, a task and its follow-up
/// being the usual pair, and then every prompt made from it hangs off it in
/// both. Shown unscoped, Task A's prompt appears inside Task B, and two runs
/// started close together look swapped. From inside a task, a coding prompt
/// another task owns is left out; one no task owns stays, as does every
/// response about the entry itself (transcripts, analyses, summaries), which
/// reads the same in any task. An entry shown on its own reads
/// [linkedAiResponsesControllerProvider] directly: there everything it carries
/// is its own.
final taskScopedAiResponsesProvider = FutureProvider.autoDispose
    .family<List<AiResponseEntry>, TaskScopedAiResponsesParams>(
      (ref, params) async {
        final responses = await ref.watch(
          linkedAiResponsesControllerProvider(params.entryId).future,
        );
        final taskId = params.taskId;
        final promptIds = {
          for (final response in responses)
            if (response.data.type == AiResponseType.promptGeneration)
              response.meta.id,
        };
        if (promptIds.isEmpty) return responses;

        final owners = await ref
            .read(journalRepositoryProvider)
            .getParentTaskIds(promptIds);
        return responses.where((response) {
          final ownerTasks = owners[response.meta.id];
          return ownerTasks == null || ownerTasks.contains(taskId);
        }).toList();
      },
    );
