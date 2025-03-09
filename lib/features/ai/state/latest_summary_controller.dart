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

@Riverpod(keepAlive: true)
class ChecklistItemSuggestionsController
    extends _$ChecklistItemSuggestionsController {
  Set<String> alreadyCreated = {};

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

    final response = latestAiEntry?.data.response ?? '';

    final checklistItems = exp
        .allMatches(response.replaceAll('*', ''))
        .map((e) {
          final title = e.group(1);
          if (title != null) {
            return ChecklistItemData(
              title: title.replaceAll(RegExp('[-.,"*]'), '').trim(),
              isChecked: false,
              linkedChecklists: [],
            );
          }
        })
        .nonNulls
        .where((e) => !alreadyCreated.contains(e.title))
        .toList();

    return checklistItems;
  }

  void notifyCreatedChecklistItem({
    required String title,
  }) {
    alreadyCreated.add(title);
    ref.invalidateSelf();
  }
}
