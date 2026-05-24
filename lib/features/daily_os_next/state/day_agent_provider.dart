import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';

/// Resolves the [DayAgentInterface] the UI talks to.
///
/// Currently always returns [MockDayAgent]. When the real
/// `DayAgentWorkflow` lands (see
/// `docs/implementation_plans/2026-05-25_day_agent_layer.md`) this
/// provider switches to the real binding; the UI does not change.
///
/// Tests override this provider with their own implementation via
/// `ProviderScope(overrides: [...])`.
final dayAgentProvider = Provider<DayAgentInterface>((ref) {
  return MockDayAgent();
});
