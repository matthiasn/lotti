import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('Profile automation providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(
            MockAiConfigRepository(),
          ),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          agentTemplateServiceProvider.overrideWithValue(
            MockAgentTemplateService(),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('profileResolverProvider constructs a ProfileResolver', () {
      final resolver = container.read(profileResolverProvider);
      expect(resolver, isA<ProfileResolver>());
    });

    test(
      'profileAutomationResolverProvider constructs a '
      'ProfileAutomationResolver',
      () {
        final resolver = container.read(profileAutomationResolverProvider);
        expect(resolver, isA<ProfileAutomationResolver>());
      },
    );

    test(
      'profileAutomationServiceProvider constructs a '
      'ProfileAutomationService',
      () {
        final service = container.read(profileAutomationServiceProvider);
        expect(service, isA<ProfileAutomationService>());
      },
    );
  });
}
