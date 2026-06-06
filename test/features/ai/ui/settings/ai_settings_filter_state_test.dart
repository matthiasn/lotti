import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    test(
      'hasModelFilters returns true when model-specific filters are set',
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
              .copyWith(selectedProviders: {'provider1'})
              .hasModelFilters,
          isTrue,
        );

        expect(
          AiSettingsFilterState.initial()
              .copyWith(selectedCapabilities: {Modality.image})
              .hasModelFilters,
          isTrue,
        );

        expect(
          AiSettingsFilterState.initial()
              .copyWith(reasoningFilter: true)
              .hasModelFilters,
          isTrue,
        );
      },
    );

    test(
      'resetModelFilters preserves search query but clears model filters',
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
      },
    );

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

      expect(updatedState.selectedCapabilities, {
        Modality.image,
        Modality.audio,
      });
    });

    test('supports all tab types', () {
      for (final tab in AiSettingsTab.values) {
        final state = AiSettingsFilterState.initial().copyWith(activeTab: tab);
        expect(state.activeTab, tab);
      }
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
          AiSettingsFilterState.initial()
              .copyWith(
                activeTab: AiSettingsTab.models,
                selectedCapabilities: {Modality.image},
              )
              .hasActiveFilters,
          isTrue,
        );

        expect(
          AiSettingsFilterState.initial()
              .copyWith(activeTab: AiSettingsTab.models)
              .hasActiveFilters,
          isFalse,
        );

        // Profiles tab - never has active filters
        expect(
          AiSettingsFilterState.initial()
              .copyWith(activeTab: AiSettingsTab.profiles)
              .hasActiveFilters,
          isFalse,
        );
      },
    );

    test(
      'resetCurrentTabFilters resets correct filters based on active tab',
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

        // Test on Providers tab (should not change anything)
        const providerState = AiSettingsFilterState(
          searchQuery: 'test',
          selectedProviders: {'provider1'},
        );

        final resetProviderState = providerState.resetCurrentTabFilters();
        expect(resetProviderState.selectedProviders, {
          'provider1',
        }); // Should NOT be reset

        // Test on Profiles tab (should not change anything)
        const profileState = AiSettingsFilterState(
          searchQuery: 'test',
          selectedProviders: {'provider1'},
          activeTab: AiSettingsTab.profiles,
        );

        final resetProfileState = profileState.resetCurrentTabFilters();
        expect(resetProfileState.selectedProviders, {
          'provider1',
        }); // Should NOT be reset
      },
    );
  });

  group('AiSettingsTab', () {
    test('has correct display names', () {
      expect(AiSettingsTab.providers.displayName, 'Providers');
      expect(AiSettingsTab.models.displayName, 'Models');
      expect(AiSettingsTab.profiles.displayName, 'Profiles');
    });

    test('contains expected tab values', () {
      expect(AiSettingsTab.values, hasLength(3));
      expect(AiSettingsTab.values, contains(AiSettingsTab.providers));
      expect(AiSettingsTab.values, contains(AiSettingsTab.models));
      expect(AiSettingsTab.values, contains(AiSettingsTab.profiles));
    });
  });

  group('AiSettingsFilterStateX properties', () {
    glados.Glados(
      glados.any.filterStateScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('filter invariants hold for any generated state', (scenario) {
      final state = scenario.state;

      // resetModelFilters always clears the model filters and preserves
      // the search query and active tab.
      final reset = state.resetModelFilters();
      expect(reset.hasModelFilters, isFalse, reason: '$state');
      expect(reset.searchQuery, state.searchQuery);
      expect(reset.activeTab, state.activeTab);

      // hasActiveFilters can only be true on the models tab, and there it
      // is exactly hasModelFilters.
      if (state.hasActiveFilters) {
        expect(state.activeTab, AiSettingsTab.models, reason: '$state');
      }
      if (state.activeTab == AiSettingsTab.models) {
        expect(state.hasActiveFilters, state.hasModelFilters);
      } else {
        expect(state.hasActiveFilters, isFalse);
      }

      // resetCurrentTabFilters: identity on non-models tabs, equal to
      // resetModelFilters on the models tab — and idempotent either way.
      final tabReset = state.resetCurrentTabFilters();
      if (state.activeTab == AiSettingsTab.models) {
        expect(tabReset, state.resetModelFilters());
      } else {
        expect(tabReset, same(state));
      }
      expect(tabReset.resetCurrentTabFilters(), tabReset);
    }, tags: 'glados');
  });
}

/// Deterministic filter-state scenario derived from (seed, tab) ints.
class _FilterStateScenario {
  _FilterStateScenario(int seed, int tabIndex) {
    final providers = <String>{
      for (var i = 0; i < seed % 4; i++) 'provider-${(seed + i) % 7}',
    };
    final capabilities = <Modality>{
      for (var i = 0; i < (seed ~/ 4) % (Modality.values.length + 1); i++)
        Modality.values[(seed + i) % Modality.values.length],
    };
    state = AiSettingsFilterState(
      searchQuery: seed.isEven ? '' : 'query-$seed',
      selectedProviders: providers,
      selectedCapabilities: capabilities,
      reasoningFilter: seed % 3 == 0,
      activeTab: AiSettingsTab.values[tabIndex % AiSettingsTab.values.length],
    );
  }

  late final AiSettingsFilterState state;
}

extension _AnyFilterState on glados.Any {
  glados.Generator<_FilterStateScenario> get filterStateScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 1 << 16),
        glados.IntAnys(this).intInRange(0, 3),
        _FilterStateScenario.new,
      );
}
