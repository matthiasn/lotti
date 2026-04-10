import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:genui/genui.dart';

/// Routes GenUI surface events to the evolution chat logic.
///
/// Listens on [SurfaceController.onSubmit] for [ChatMessage]s containing
/// [UiInteractionPart]s and dispatches them to registered callbacks.
class GenUiEventHandler {
  GenUiEventHandler({required this.processor});

  final SurfaceController processor;

  /// Called when the user taps approve or reject on a skill proposal surface.
  ///
  /// The `action` parameter is the event name: `proposal_approved` or
  /// `proposal_rejected`.
  void Function(String surfaceId, String action)? onProposalAction;

  /// Called when the user taps approve or reject on a soul proposal surface.
  ///
  /// The `action` parameter is the event name: `soul_proposal_approved` or
  /// `soul_proposal_rejected`.
  void Function(String surfaceId, String action)? onSoulProposalAction;

  /// Called when the user submits category ratings.
  void Function(String surfaceId, Map<String, int> ratings)? onRatingsSubmitted;

  /// Called when the user submits a binary choice surface.
  void Function(String surfaceId, String value)? onBinaryChoiceSubmitted;

  /// Called when the user picks an option in an A/B comparison surface.
  void Function(String surfaceId, String value)? onABComparisonSubmitted;

  StreamSubscription<ChatMessage>? _subscription;

  /// Start listening for surface events. Idempotent: cancels any existing
  /// subscription before creating a new one.
  void listen() {
    _subscription?.cancel();
    _subscription = processor.onSubmit.listen(_handleEvent);
  }

  void _handleEvent(ChatMessage message) {
    try {
      for (final interactionPart in message.parts.uiInteractionParts) {
        _processInteraction(interactionPart.interaction);
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

  void _processInteraction(String interaction) {
    try {
      final decoded = jsonDecode(interaction);
      if (decoded is! Map<String, dynamic>) return;
      final actionRaw = decoded['action'];
      if (actionRaw is! Map<String, dynamic>) return;

      final action = UserActionEvent.fromMap(actionRaw);
      final name = action.name;
      if (name == 'proposal_approved' || name == 'proposal_rejected') {
        onProposalAction?.call(action.surfaceId, name);
      } else if (name == 'soul_proposal_approved' ||
          name == 'soul_proposal_rejected') {
        onSoulProposalAction?.call(action.surfaceId, name);
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
        } catch (e, s) {
          developer.log(
            'Failed to parse ratings JSON: $ratingsJson',
            name: 'GenUiEventHandler',
            error: e,
            stackTrace: s,
          );
        }
      } else if (name == 'ab_comparison_submitted') {
        final payloadJson = action.sourceComponentId;
        try {
          final decoded = jsonDecode(payloadJson);
          if (decoded is Map<String, dynamic>) {
            final value = decoded['value'];
            if (value is String && value.trim().isNotEmpty) {
              onABComparisonSubmitted?.call(action.surfaceId, value.trim());
            }
          }
        } catch (e, s) {
          developer.log(
            'Failed to parse AB comparison JSON: $payloadJson',
            name: 'GenUiEventHandler',
            error: e,
            stackTrace: s,
          );
        }
      } else if (name == 'binary_choice_submitted') {
        final payloadJson = action.sourceComponentId;
        try {
          final decoded = jsonDecode(payloadJson);
          if (decoded is Map<String, dynamic>) {
            final value = decoded['value'];
            if (value is String && value.trim().isNotEmpty) {
              onBinaryChoiceSubmitted?.call(action.surfaceId, value.trim());
            }
          }
        } catch (e, s) {
          developer.log(
            'Failed to parse binary choice JSON: $payloadJson',
            name: 'GenUiEventHandler',
            error: e,
            stackTrace: s,
          );
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to process GenUI interaction',
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
