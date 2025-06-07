import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/sliver_show_case_title_bar.dart';

enum AiSettingsTab { providers, models, prompts }

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Model-specific filters
  final Set<String> _selectedProviders = {};
  final Set<Modality> _selectedCapabilities = {};
  bool _reasoningFilter = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverShowCaseTitleBar(title: 'AI Settings'),
          SliverToBoxAdapter(
            child: _buildTabBarWithSearch(),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProvidersTab(),
                _buildModelsTab(),
                _buildPromptsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarWithSearch() {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(
                  Icons.search,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _searchController.clear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ),
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: context.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(2),
              labelColor: context.colorScheme.onPrimary,
              unselectedLabelColor: context.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              dividerColor: Colors.transparent,
              onTap: (index) {
                // Clear filters when switching tabs
                setState(() {
                  _selectedProviders.clear();
                  _selectedCapabilities.clear();
                  _reasoningFilter = false;
                });
              },
              tabs: const [
                Tab(text: 'Providers'),
                Tab(text: 'Models'),
                Tab(text: 'Prompts'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Filters for Models tab
          if (_tabController.index == 1) _buildModelFilters(),
        ],
      ),
    );
  }

  Widget _buildModelFilters() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Filter
            _buildProviderFilter(),

            const SizedBox(height: 12),

            // Capability Filters
            _buildCapabilityFilters(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderFilter() {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider),
    );

    return providersAsync.when(
      data: (providers) {
        final providerConfigs =
            providers.whereType<AiConfigInferenceProvider>().toList();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              'Providers:',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            ...providerConfigs.map((provider) {
              final isSelected = _selectedProviders.contains(provider.id);
              return FilterChip(
                label: Text(provider.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedProviders.add(provider.id);
                    } else {
                      _selectedProviders.remove(provider.id);
                    }
                  });
                },
                backgroundColor: context.colorScheme.surfaceContainerHighest,
                selectedColor: context.colorScheme.primaryContainer,
                checkmarkColor: context.colorScheme.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.colorScheme.onSurfaceVariant,
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCapabilityFilters() {
    final capabilities = [
      (Modality.image, Icons.visibility, 'Vision'),
      (Modality.audio, Icons.hearing, 'Audio'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          'Capabilities:',
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        ...capabilities.map((capability) {
          final (modality, icon, label) = capability;
          final isSelected = _selectedCapabilities.contains(modality);
          return FilterChip(
            avatar: Icon(icon, size: 16),
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedCapabilities.add(modality);
                } else {
                  _selectedCapabilities.remove(modality);
                }
              });
            },
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            selectedColor: context.colorScheme.primaryContainer,
            checkmarkColor: context.colorScheme.primary,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurfaceVariant,
            ),
          );
        }),

        // Reasoning filter
        FilterChip(
          avatar: const Icon(Icons.psychology, size: 16),
          label: const Text('Reasoning'),
          selected: _reasoningFilter,
          onSelected: (selected) {
            setState(() {
              _reasoningFilter = selected;
            });
          },
          backgroundColor: context.colorScheme.surfaceContainerHighest,
          selectedColor: context.colorScheme.primaryContainer,
          checkmarkColor: context.colorScheme.primary,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _reasoningFilter
                ? context.colorScheme.primary
                : context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProvidersTab() {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider),
    );

    return _buildConfigList<AiConfigInferenceProvider>(
      configsAsync: providersAsync,
      filterFunction: _filterProviders,
      navigationPath: '/settings/advanced/ai/api_keys',
      emptyMessage: 'No AI providers configured',
      emptyIcon: Icons.hub,
    );
  }

  Widget _buildModelsTab() {
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );

    return _buildConfigList<AiConfigModel>(
      configsAsync: modelsAsync,
      filterFunction: _filterModels,
      navigationPath: '/settings/advanced/ai/models',
      emptyMessage: 'No AI models configured',
      emptyIcon: Icons.smart_toy,
      showCapabilities: true,
    );
  }

  Widget _buildPromptsTab() {
    final promptsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.prompt),
    );

    return _buildConfigList<AiConfigPrompt>(
      configsAsync: promptsAsync,
      filterFunction: _filterPrompts,
      navigationPath: '/settings/advanced/ai/prompts',
      emptyMessage: 'No AI prompts configured',
      emptyIcon: Icons.text_snippet,
    );
  }

  Widget _buildConfigList<T extends AiConfig>({
    required AsyncValue<List<AiConfig>> configsAsync,
    required List<T> Function(List<T>) filterFunction,
    required String navigationPath,
    required String emptyMessage,
    required IconData emptyIcon,
    bool showCapabilities = false,
  }) {
    return configsAsync.when(
      data: (configs) {
        final typedConfigs = configs.whereType<T>().toList();
        final filteredConfigs = filterFunction(typedConfigs);

        if (filteredConfigs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  emptyIcon,
                  size: 64,
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredConfigs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final config = filteredConfigs[index];
            return AiConfigCard(
              config: config,
              showCapabilities: showCapabilities,
              onTap: () => _navigateToDetail(config),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load configurations\n$error',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AiConfigInferenceProvider> _filterProviders(
      List<AiConfigInferenceProvider> providers) {
    return providers.where((provider) {
      if (_searchQuery.isNotEmpty) {
        final matchesSearch =
            provider.name.toLowerCase().contains(_searchQuery) ||
                (provider.description?.toLowerCase().contains(_searchQuery) ??
                    false);
        if (!matchesSearch) return false;
      }
      return true;
    }).toList();
  }

  List<AiConfigModel> _filterModels(List<AiConfigModel> models) {
    return models.where((model) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = model.name.toLowerCase().contains(_searchQuery) ||
            (model.description?.toLowerCase().contains(_searchQuery) ?? false);
        if (!matchesSearch) return false;
      }

      // Provider filter
      if (_selectedProviders.isNotEmpty) {
        if (!_selectedProviders.contains(model.inferenceProviderId)) {
          return false;
        }
      }

      // Capability filters
      if (_selectedCapabilities.isNotEmpty) {
        if (!_selectedCapabilities.every(
            (capability) => model.inputModalities.contains(capability))) {
          return false;
        }
      }

      // Reasoning filter
      if (_reasoningFilter && !model.isReasoningModel) {
        return false;
      }

      return true;
    }).toList();
  }

  List<AiConfigPrompt> _filterPrompts(List<AiConfigPrompt> prompts) {
    return prompts.where((prompt) {
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = prompt.name
                .toLowerCase()
                .contains(_searchQuery) ||
            (prompt.description?.toLowerCase().contains(_searchQuery) ?? false);
        if (!matchesSearch) return false;
      }
      return true;
    }).toList();
  }

  void _navigateToDetail(AiConfig config) {
    if (config is AiConfigInferenceProvider) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => InferenceProviderEditPage(
            configId: config.id,
          ),
        ),
      );
    } else if (config is AiConfigModel) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => InferenceModelEditPage(
            configId: config.id,
          ),
        ),
      );
    } else if (config is AiConfigPrompt) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PromptEditPage(
            configId: config.id,
          ),
        ),
      );
    }
  }
}
