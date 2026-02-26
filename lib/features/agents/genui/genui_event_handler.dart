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

  StreamSubscription<UserUiInteractionMessage>? _subscription;

  /// Start listening for surface events. Idempotent: cancels any existing
  /// subscription before creating a new one.
  void listen() {
    _subscription?.cancel();
    _subscription = processor.onSubmit.listen(_handleEvent);
  }

  void _handleEvent(UserUiInteractionMessage message) {
    try {
      final json = jsonDecode(message.text) as Map<String, dynamic>;
      final userAction = json['userAction'] as Map<String, dynamic>?;
      if (userAction == null) return;

      final action = UserActionEvent.fromMap(userAction);
      final isAction = userAction['isAction'] as bool? ?? false;
      if (!isAction) return;

      final name = action.name;
      if (name == 'proposal_approved' || name == 'proposal_rejected') {
        onProposalAction?.call(action.surfaceId, name);
      }
    } catch (e, s) {
      developer.log(
        'Failed to handle GenUI event: ${message.text}',
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
