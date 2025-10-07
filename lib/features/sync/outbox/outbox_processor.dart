// ignore_for_file: one_member_abstracts, sort_constructors_first

import 'dart:convert';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/services/logging_service.dart';

abstract class OutboxMessageSender {
  Future<bool> send(SyncMessage message);
}

class OutboxProcessingResult {
  const OutboxProcessingResult._({this.nextDelay});

  final Duration? nextDelay;

  static const OutboxProcessingResult none = OutboxProcessingResult._();

  factory OutboxProcessingResult.schedule(Duration delay) =>
      OutboxProcessingResult._(nextDelay: delay);

  bool get shouldSchedule => nextDelay != null;
}

class OutboxProcessor {
  final OutboxRepository _repository;
  final OutboxMessageSender _messageSender;
  final LoggingService _loggingService;
  final int batchSize;
  final Duration retryDelay;
  final Duration errorDelay;

  OutboxProcessor({
    required OutboxRepository repository,
    required OutboxMessageSender messageSender,
    required LoggingService loggingService,
    int? batchSizeOverride,
    Duration? retryDelayOverride,
    Duration? errorDelayOverride,
  })  : _repository = repository,
        _messageSender = messageSender,
        _loggingService = loggingService,
        batchSize = batchSizeOverride ?? 10,
        retryDelay = retryDelayOverride ?? const Duration(seconds: 5),
        errorDelay = errorDelayOverride ?? const Duration(seconds: 15);

  Future<OutboxProcessingResult> processQueue() async {
    final pendingItems = await _repository.fetchPending(limit: batchSize);
    if (pendingItems.isEmpty) {
      return OutboxProcessingResult.none;
    }

    final nextItem = pendingItems.first;
    _loggingService.captureEvent(
      'trying ${nextItem.subject} ',
      domain: 'OUTBOX',
      subDomain: 'sendNext()',
    );

    try {
      final syncMessage = _decodeMessage(nextItem);
      final success = await _messageSender.send(syncMessage);

      if (!success) {
        await _repository.markRetry(nextItem);
        return OutboxProcessingResult.schedule(retryDelay);
      }

      await _repository.markSent(nextItem);
      _loggingService.captureEvent(
        '${nextItem.subject} done',
        domain: 'OUTBOX',
        subDomain: 'sendNext()',
      );

      final hasMore = pendingItems.length > 1;
      if (hasMore) {
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      return OutboxProcessingResult.none;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      await _repository.markRetry(nextItem);
      return OutboxProcessingResult.schedule(errorDelay);
    }
  }

  SyncMessage _decodeMessage(OutboxItem item) {
    final jsonMap = json.decode(item.message) as Map<String, dynamic>;
    return SyncMessage.fromJson(jsonMap);
  }
}
