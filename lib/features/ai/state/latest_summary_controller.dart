import 'dart:async';

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
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
  final watchedIds = <String>{};

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
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());
    watchedIds.add(id);
    final latestAiEntry = await _fetch();
    return latestAiEntry;
  }

  Future<AiResponseEntry?> _fetch() async {
    final linked = await ref
        .read(journalRepositoryProvider)
        .getLinkedEntities(linkedTo: id);

    return linked.whereType<AiResponseEntry>().toList().firstOrNull;
  }
}

@riverpod
class ChecklistItemSuggestionsController
    extends _$ChecklistItemSuggestionsController {
  @override
  Future<List<ChecklistItemData>> build({
    required String id,
  }) async {
    final latestAiEntry =
        await ref.watch(latestSummaryControllerProvider(id: id).future);

    final exp = RegExp(
      r'TODO:\s(.+)',
      multiLine: true,
    );

    final checklistItems = exp
        .allMatches(latestAiEntry?.data.response ?? '')
        .map((e) {
          final title = e.group(1);
          if (title != null) {
            return ChecklistItemData(
              title: title.replaceAll(RegExp('[,"]'), ''),
              isChecked: false,
              linkedChecklists: [],
            );
          }
        })
        .nonNulls
        .toList();

    return checklistItems;
  }
}
