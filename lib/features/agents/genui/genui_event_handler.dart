import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:genui/genui.dart';

/// Routes GenUI surface events to the evolution chat logic.
///
/// Listens on [A2uiMessageProcessor.onSubmit] for [UserUiInteractionMessage]s
/// and dispatches them to registered callbacks.
class GenUiEventHandler {
  GenUiEventHandler({required this.processor});

  final A2uiMessageProcessor processor;

  /// Called when the user taps approve or reject on a proposal surface.
  ///
  /// The `action` parameter is the event name: `proposal_approved` or
  /// `proposal_rejected`.
  void Function(String surfaceId, String action)? onProposalAction;

  /// Called when the user submits category ratings.
  void Function(String surfaceId, Map<String, int> ratings)? onRatingsSubmitted;

  StreamSubscription<UserUiInteractionMessage>? _subscription;

  /// Start listening for surface events. Idempotent: cancels any existing
  /// subscription before creating a new one.
  void listen() {
    _subscription?.cancel();
    _subscription = processor.onSubmit.listen(_handleEvent);
  }

  void _handleEvent(UserUiInteractionMessage message) {
    try {
      final decoded = jsonDecode(message.text);
      if (decoded is! Map<String, dynamic>) return;
      final userActionRaw = decoded['userAction'];
      if (userActionRaw is! Map<String, dynamic>) return;
      if (userActionRaw['isAction'] != true) return;

      final action = UserActionEvent.fromMap(userActionRaw);
      final name = action.name;
      if (name == 'proposal_approved' || name == 'proposal_rejected') {
        onProposalAction?.call(action.surfaceId, name);
      } else if (name == 'ratings_submitted') {
        final ratingsJson = action.sourceComponentId;
        try {
          final decoded = jsonDecode(ratingsJson);
          if (decoded is Map<String, dynamic>) {
            final ratings = decoded.map(
              (k, v) => MapEntry(k, v is num ? v.toInt() : 0),
            );
            onRatingsSubmitted?.call(action.surfaceId, ratings);
          }
        } catch (_) {
          // Ignore malformed ratings JSON.
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to handle GenUI event',
        name: 'GenUiEventHandler',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Stop listening and clean up.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
