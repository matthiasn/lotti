import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Takes over a tap on the AI action before any skill runs.
///
/// Returns true when it handled the tap, in which case the action does not
/// open. [retry] re-runs the original action, for an interceptor that first
/// sets something up (a real provider in the demo world) and then lets the
/// user carry on.
typedef AiActionInterceptor =
    Future<bool> Function(BuildContext context, {required VoidCallback retry});

/// The interceptor for the AI action, or null to let every tap through.
///
/// The composition root wires the demo world's real-AI nudge, so the AI
/// feature offers the seam without depending on the demo or onboarding
/// features.
final aiActionInterceptorProvider = Provider<AiActionInterceptor?>(
  (ref) => null,
  name: 'aiActionInterceptorProvider',
);
