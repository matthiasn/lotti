import 'dart:async';

import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'action_item_suggestions_prompt.g.dart';

@riverpod
class ActionItemSuggestionsPromptController
    extends _$ActionItemSuggestionsPromptController {
  ActionItemSuggestionsPromptController() {
    listen();
  }

  final watchedIds = <String>{};
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        final prompt = await _buildPrompt(id: id);
        state = AsyncData(prompt);
      }
    });
  }

  @override
  Future<String?> build({
    required String id,
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());

    final links = await ref.watch(journalRepositoryProvider).getLinksFromId(id);
    watchedIds
      ..add(id)
      ..addAll(links.map((link) => link.toId));

    final prompt = await _buildPrompt(id: id);
    return prompt;
  }

  Future<String?> _buildPrompt({required String id}) async {
    return ref.read(aiInputRepositoryProvider).buildPrompt(
          id: id,
          aiResponseType: actionItemSuggestions,
        );
  }
}
