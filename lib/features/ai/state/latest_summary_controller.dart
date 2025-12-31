// ignore_for_file: specify_nonobvious_property_types

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
final latestSummaryControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LatestSummaryController, AiResponseEntry?, LatestSummaryParams>(
  LatestSummaryController.new,
);

class LatestSummaryController extends AsyncNotifier<AiResponseEntry?> {
  LatestSummaryController(this._params);

  final LatestSummaryParams _params;
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{aiResponseNotification};

  String get id => _params.id;
  AiResponseType get aiResponseType => _params.aiResponseType;

  @override
  Future<AiResponseEntry?> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    watchedIds
      ..add(id)
      ..add(aiResponseNotification);
    _listen();
    return _fetch();
  }

  void _listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        _fetch().then((latest) {
          if (ref.mounted && latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
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
