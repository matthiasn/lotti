import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

void main() {
  group('AiSettingsFilterState', () {
    test('initial state has correct default values', () {
      final state = AiSettingsFilterState.initial();

      expect(state.searchQuery, isEmpty);
      expect(state.selectedProviders, isEmpty);
      expect(state.selectedCapabilities, isEmpty);
      expect(state.reasoningFilter, isFalse);
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

    test('hasActiveFilters returns true when filters are set', () {
      expect(
        AiSettingsFilterState.initial().hasActiveFilters,
        isFalse,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(searchQuery: 'test')
            .hasActiveFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(selectedProviders: {'provider1'}).hasActiveFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(selectedCapabilities: {Modality.image}).hasActiveFilters,
        isTrue,
      );

      expect(
        AiSettingsFilterState.initial()
            .copyWith(reasoningFilter: true)
            .hasActiveFilters,
        isTrue,
      );
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

    test('resetFilters returns state with all filters cleared', () {
      const state = AiSettingsFilterState(
        searchQuery: 'test',
        selectedProviders: {'provider1'},
        selectedCapabilities: {Modality.image},
        reasoningFilter: true,
        activeTab: AiSettingsTab.models,
      );

      final resetState = state.resetFilters();

      expect(resetState.searchQuery, isEmpty);
      expect(resetState.selectedProviders, isEmpty);
      expect(resetState.selectedCapabilities, isEmpty);
      expect(resetState.reasoningFilter, isFalse);
      expect(resetState.activeTab, AiSettingsTab.models); // Should preserve tab
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
