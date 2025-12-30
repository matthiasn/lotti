import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Record type for latest summary controller parameters.
typedef LatestSummaryParams = ({String id, AiResponseType aiResponseType});

/// Provider for the latest AI summary controller.
final AutoDisposeAsyncNotifierProviderFamily<LatestSummaryController,
        AiResponseEntry?, LatestSummaryParams> latestSummaryControllerProvider =
    AsyncNotifierProvider.autoDispose
        .family<LatestSummaryController, AiResponseEntry?, LatestSummaryParams>(
  LatestSummaryController.new,
);

class LatestSummaryController extends AutoDisposeFamilyAsyncNotifier<
    AiResponseEntry?, LatestSummaryParams> {
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{aiResponseNotification};

  String get id => arg.id;
  AiResponseType get aiResponseType => arg.aiResponseType;

  void _listen() {
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
  Future<AiResponseEntry?> build(LatestSummaryParams arg) async {
    ref.onDispose(() => _updateSubscription?.cancel());
    watchedIds
      ..add(id)
      ..add(aiResponseNotification);
    _listen();
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
}
