import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'latest_summary_controller.g.dart';

@riverpod
class LatestSummaryController extends _$LatestSummaryController {
  @override
  Future<AiResponseEntry?> build({
    required String id,
  }) async {
    final linked =
        await ref.read(journalRepositoryProvider).getLinkedToEntities(
              linkedTo: id,
            );

    final latestAiEntry =
        linked.whereType<AiResponseEntry>().toList().firstOrNull;

    return latestAiEntry;
  }
}
