import 'package:a2ui_core/a2ui_core.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/services/domain_logging.dart';

/// Routes the actions of evolution surfaces to the evolution chat logic.
///
/// Listens on the processor's `onAction` and dispatches each
/// [A2uiRendererAction] to its registered callback. What the user chose
/// travels in the action's `context`.
class GenUiEventHandler {
  GenUiEventHandler({
    required this.processor,
    required this._domainLogger,
  });

  final EvolutionSurfaces processor;

  /// Receives the failures of malformed surface events.
  final DomainLogger _domainLogger;

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

  Subscription? _subscription;

  /// Start listening for surface actions. Idempotent: cancels any existing
  /// subscription before creating a new one.
  void listen() {
    _subscription?.unsubscribe();
    _subscription = processor.model.onAction.subscribe(_handleAction);
  }

  void _handleAction(A2uiRendererAction action) {
    try {
      final surfaceId = action.surfaceId;
      switch (action.name) {
        case 'proposal_approved' || 'proposal_rejected':
          onProposalAction?.call(surfaceId, action.name);
        case 'soul_proposal_approved' || 'soul_proposal_rejected':
          onSoulProposalAction?.call(surfaceId, action.name);
        case 'ratings_submitted':
          if (action.context['ratings'] case final Map<Object?, Object?> raw) {
            onRatingsSubmitted?.call(surfaceId, {
              for (final MapEntry(:key, :value) in raw.entries)
                '$key': value is num ? value.toInt() : 0,
            });
          }
        case 'ab_comparison_submitted':
          if (_chosen(action) case final value?) {
            onABComparisonSubmitted?.call(surfaceId, value);
          }
        case 'binary_choice_submitted':
          if (_chosen(action) case final value?) {
            onBinaryChoiceSubmitted?.call(surfaceId, value);
          }
      }
    } catch (e, s) {
      // A callback's own failure must not break the surface's event stream.
      // The action's context is the user's choice — model-written text — so
      // only the error is logged, without its source.
      _domainLogger.error(
        LogDomain.agentWorkflow,
        DomainLogger.withoutSource(e),
        stackTrace: s,
        subDomain: 'GenUiEventHandler',
        message: 'Failed to handle surface action ${action.name}',
        errorType: e.runtimeType,
      );
    }
  }

  /// The non-blank `value` the user chose, or null.
  static String? _chosen(A2uiRendererAction action) =>
      switch (action.context['value']) {
        final String value when value.trim().isNotEmpty => value.trim(),
        _ => null,
      };

  /// Stop listening and clean up.
  void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
  }
}
