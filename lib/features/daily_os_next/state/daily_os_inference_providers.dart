import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';

/// Whether a configured inference endpoint is on this device or remote.
enum DailyOsInferenceEndpointKind { onDevice, remote }

/// Classifies the actual configured endpoint used by a provider.
///
/// Provider brands are intentionally irrelevant. A loopback endpoint is local
/// even for a generic OpenAI-compatible provider, while a remotely hosted
/// Ollama endpoint is remote.
DailyOsInferenceEndpointKind dailyOsInferenceEndpointKind(
  AiConfigInferenceProvider provider,
) {
  if (provider.inferenceProviderType == InferenceProviderType.mlxAudio) {
    return DailyOsInferenceEndpointKind.onDevice;
  }

  final uri = Uri.tryParse(provider.baseUrl.trim());
  final host = uri?.host.toLowerCase();
  if (host == 'localhost' || host == '::1' || _isIpv4Loopback(host)) {
    return DailyOsInferenceEndpointKind.onDevice;
  }
  return DailyOsInferenceEndpointKind.remote;
}

bool _isIpv4Loopback(String? host) {
  if (host == null) return false;
  final parts = host.split('.');
  if (parts.length != 4 || parts.any((part) => int.tryParse(part) == null)) {
    return false;
  }
  return int.parse(parts.first) == 127;
}

/// Setup facts used by the Daily OS surface to make missing configuration
/// discoverable without replacing already rendered day content during reloads.
class DailyOsSetupStatus {
  const DailyOsSetupStatus({
    required this.hasInferenceRoute,
    required this.hasPreferredName,
  });

  final bool hasInferenceRoute;
  final bool hasPreferredName;

  bool get needsAttention => !hasInferenceRoute || !hasPreferredName;
}

final FutureProvider<DailyOsSetupStatus> dailyOsSetupStatusProvider =
    FutureProvider<DailyOsSetupStatus>(
      (ref) async {
        final routeReadyFuture = ref.watch(
          dailyOsOnboardingProviderReadyProvider.future,
        );
        final templateFuture = ref.watch(
          agentTemplateProvider(dayAgentTemplateId).future,
        );
        final preferences = ref.watch(dailyOsPreferencesControllerProvider);
        final routeReady = await routeReadyFuture;
        final templateEntity = await templateFuture;
        final template = templateEntity?.mapOrNull(
          agentTemplate: (value) => value,
        );

        return DailyOsSetupStatus(
          hasInferenceRoute: routeReady && template?.profileId != null,
          hasPreferredName: preferences.hasUserName,
        );
      },
      name: 'dailyOsSetupStatusProvider',
    );
