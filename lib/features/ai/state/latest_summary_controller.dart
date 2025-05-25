import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'latest_summary_controller.g.dart';

@riverpod
class LatestSummaryController extends _$LatestSummaryController {
  LatestSummaryController() {
    listen();
  }

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{aiResponseNotification};

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        _fetch().then((latest) {
          if (latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  @override
  Future<AiResponseEntry?> build({
    required String id,
    required AiResponseType aiResponseType,
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());
    watchedIds
      ..add(id)
      ..add(aiResponseNotification);
    final latestAiEntry = await _fetch();
    return latestAiEntry;
  }

  Future<AiResponseEntry?> _fetch() async {
    final linked = await ref
        .read(journalRepositoryProvider)
        .getLinkedEntities(linkedTo: id);

    return linked
        .whereType<AiResponseEntry>()
        .where((element) => element.data.type == aiResponseType)
        .firstOrNull;
  }

  Future<void> removeActionItem({
    required String title,
  }) async {
    final latestAiEntry = state.valueOrNull;

    if (latestAiEntry == null) {
      return;
    }

    final updated = latestAiEntry.copyWith(
      data: latestAiEntry.data.copyWith(
        suggestedActionItems: latestAiEntry.data.suggestedActionItems
            ?.where((item) => item.title != title)
            .toList(),
      ),
    );

    state = AsyncData(updated);
    await ref.read(journalRepositoryProvider).updateJournalEntity(updated);
  }
}
