import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

void main() {
  group('AiSettingsFilterState', () {
    test('initial state has correct default values', () {
      final state = AiSettingsFilterState.initial();

      expect(state.searchQuery, isEmpty);
      expect(state.selectedProviders, isEmpty);
      expect(state.selectedCapabilities, isEmpty);
      expect(state.reasoningFilter, isFalse);
      expect(state.selectedResponseTypes, isEmpty);
      expect(state.activeTab, AiSettingsTab.providers);
    });

    test('copyWith updates only specified fields', () {
      final initialState = AiSettingsFilterState.initial();

      final updatedState = initialState.copyWith(
        searchQuery: 'test query',
        reasoningFilter: true,
      );

      expect(updatedState.searchQuery, 'test query');
      expect(updatedState.reasoningFilter, isTrue);
      expect(updatedState.selectedProviders, isEmpty);
      expect(updatedState.selectedCapabilities, isEmpty);
      expect(updatedState.activeTab, AiSettingsTab.providers);
    });

    test('hasModelFilters returns true when model-specific filters are set',
        () {
      expect(
        AiSettingsFilterState.initial().hasModelFilters,
        isFalse,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(searchQuery: 'test')
            .hasModelFilters,
        isFalse,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(selectedProviders: {'provider1'}).hasModelFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(selectedCapabilities: {Modality.image}).hasModelFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(reasoningFilter: true)
            .hasModelFilters,
        isTrue,
      );
    });

    test('resetModelFilters preserves search query but clears model filters',
        () {
      const state = AiSettingsFilterState(
        searchQuery: 'test',
        selectedProviders: {'provider1'},
        selectedCapabilities: {Modality.image},
        reasoningFilter: true,
        activeTab: AiSettingsTab.models,
      );

      final resetState = state.resetModelFilters();

      expect(resetState.searchQuery, 'test'); // Should preserve
      expect(resetState.selectedProviders, isEmpty);
      expect(resetState.selectedCapabilities, isEmpty);
      expect(resetState.reasoningFilter, isFalse);
      expect(resetState.activeTab, AiSettingsTab.models); // Should preserve
    });

    test('can update provider selection', () {
      final state = AiSettingsFilterState.initial();

      final updatedState = state.copyWith(
        selectedProviders: {'provider1', 'provider2'},
      );

      expect(updatedState.selectedProviders, {'provider1', 'provider2'});
    });

    test('can update capability selection', () {
      final state = AiSettingsFilterState.initial();

      final updatedState = state.copyWith(
        selectedCapabilities: {Modality.image, Modality.audio},
      );

      expect(
          updatedState.selectedCapabilities, {Modality.image, Modality.audio});
    });

    test('supports all tab types', () {
      for (final tab in AiSettingsTab.values) {
        final state = AiSettingsFilterState.initial().copyWith(activeTab: tab);
        expect(state.activeTab, tab);
      }
    });

    test('can update response type selection', () {
      final state = AiSettingsFilterState.initial();

      final updatedState = state.copyWith(
        selectedResponseTypes: {
          AiResponseType.taskSummary,
          AiResponseType.imageAnalysis,
        },
      );

      expect(updatedState.selectedResponseTypes, {
        AiResponseType.taskSummary,
        AiResponseType.imageAnalysis,
      });
    });

    test('hasPromptFilters returns true when prompt-specific filters are set',
        () {
      expect(
        AiSettingsFilterState.initial().hasPromptFilters,
        isFalse,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(searchQuery: 'test')
            .hasPromptFilters,
        isFalse,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(selectedProviders: {'provider1'}).hasPromptFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial().copyWith(selectedResponseTypes: {
          AiResponseType.taskSummary
        }).hasPromptFilters,
        isTrue,
      );
    });

    test(
        'hasActiveFilters returns correct value based on active tab and filters',
        () {
      // Providers tab - never has active filters
      expect(
        AiSettingsFilterState.initial()
            .copyWith(activeTab: AiSettingsTab.providers)
            .hasActiveFilters,
        isFalse,
      );

      // Models tab - has active filters when model filters set
      expect(
        AiSettingsFilterState.initial().copyWith(
          activeTab: AiSettingsTab.models,
          selectedCapabilities: {Modality.image},
        ).hasActiveFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(activeTab: AiSettingsTab.models)
            .hasActiveFilters,
        isFalse,
      );

      // Prompts tab - has active filters when prompt filters set
      expect(
        AiSettingsFilterState.initial().copyWith(
          activeTab: AiSettingsTab.prompts,
          selectedResponseTypes: {AiResponseType.imageAnalysis},
        ).hasActiveFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(activeTab: AiSettingsTab.prompts)
            .hasActiveFilters,
        isFalse,
      );
    });

    test('resetPromptFilters preserves search query but clears prompt filters',
        () {
      const state = AiSettingsFilterState(
        searchQuery: 'test',
        selectedProviders: {'provider1'},
        selectedResponseTypes: {
          AiResponseType.taskSummary,
          AiResponseType.imageAnalysis,
        },
        activeTab: AiSettingsTab.prompts,
      );

      final resetState = state.resetPromptFilters();

      expect(resetState.searchQuery, 'test'); // Should preserve
      expect(resetState.selectedProviders, isEmpty);
      expect(resetState.selectedResponseTypes, isEmpty);
      expect(resetState.activeTab, AiSettingsTab.prompts); // Should preserve
    });

    test('resetCurrentTabFilters resets correct filters based on active tab',
        () {
      // Test on Models tab
      const modelState = AiSettingsFilterState(
        searchQuery: 'test',
        selectedProviders: {'provider1'},
        selectedCapabilities: {Modality.image},
        reasoningFilter: true,
        activeTab: AiSettingsTab.models,
      );

      final resetModelState = modelState.resetCurrentTabFilters();
      expect(resetModelState.selectedProviders, isEmpty);
      expect(resetModelState.selectedCapabilities, isEmpty);
      expect(resetModelState.reasoningFilter, isFalse);
      expect(resetModelState.searchQuery, 'test'); // Preserved

      // Test on Prompts tab
      const promptState = AiSettingsFilterState(
        searchQuery: 'test',
        selectedProviders: {'provider1'},
        selectedResponseTypes: {AiResponseType.taskSummary},
        activeTab: AiSettingsTab.prompts,
      );

      final resetPromptState = promptState.resetCurrentTabFilters();
      expect(resetPromptState.selectedProviders, isEmpty);
      expect(resetPromptState.selectedResponseTypes, isEmpty);
      expect(resetPromptState.searchQuery, 'test'); // Preserved

      // Test on Providers tab (should not change anything)
      const providerState = AiSettingsFilterState(
        searchQuery: 'test',
        selectedProviders: {'provider1'},
      );

      final resetProviderState = providerState.resetCurrentTabFilters();
      expect(resetProviderState.selectedProviders,
          {'provider1'}); // Should NOT be reset
    });
  });

  group('AiSettingsTab', () {
    test('has correct display names', () {
      expect(AiSettingsTab.providers.displayName, 'Providers');
      expect(AiSettingsTab.models.displayName, 'Models');
      expect(AiSettingsTab.prompts.displayName, 'Prompts');
    });

    test('contains expected tab values', () {
      expect(AiSettingsTab.values, hasLength(3));
      expect(AiSettingsTab.values, contains(AiSettingsTab.providers));
      expect(AiSettingsTab.values, contains(AiSettingsTab.models));
      expect(AiSettingsTab.values, contains(AiSettingsTab.prompts));
    });
  });
}
