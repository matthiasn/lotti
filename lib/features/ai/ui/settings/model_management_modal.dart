import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

// Updated show method to use proper WoltModal pattern with sticky action bar
void showModelManagementModal({
  required BuildContext context,
  required List<String> currentSelectedIds,
  required String currentDefaultId,
  required void Function(List<String> newSelectedIds, String newDefaultId)
      onSave,
  AiConfigPrompt? promptConfig,
}) {
  // Create a stateful wrapper to manage state outside of the modal widget
  final selectedIds = ValueNotifier<Set<String>>(currentSelectedIds.toSet());
  final defaultId = ValueNotifier<String>(currentDefaultId);

  ModalUtils.showMultiPageModal<void>(
    context: context,
    pageListBuilder: (modalContext) {
      return [
        ModalUtils.modalSheetPage(
          context: context,
          padding: EdgeInsets.zero,
          leadingNavBarWidget: ValueListenableBuilder<Set<String>>(
            valueListenable: selectedIds,
            builder: (context, selectedIdsValue, _) {
              final count = selectedIdsValue.length;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: 32,
                  height: 24,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: count > 0
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey('check_icon'),
                              size: 24,
                              color: modalContext.colorScheme.primary,
                            )
                          : Icon(
                              Icons.warning_rounded,
                              key: const ValueKey('warning_icon'),
                              size: 24,
                              color: modalContext.colorScheme.error,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
          titleWidget: ValueListenableBuilder<Set<String>>(
            valueListenable: selectedIds,
            builder: (context, selectedIdsValue, _) {
              final count = selectedIdsValue.length;
              return Text(
                context.messages.modelManagementSelectedCount(count),
                style: modalContext.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                  color: count > 0
                      ? modalContext.colorScheme.onSurface
                      : modalContext.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                ),
              );
            },
          ),
          showCloseButton: true,
          stickyActionBar: SafeArea(
            top: false,
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: selectedIds,
              builder: (context, selectedIdsValue, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: defaultId,
                  builder: (context, defaultIdValue, _) {
                    return _ModelManagementStickyActionBar(
                      selectedIds: selectedIdsValue,
                      defaultId: defaultIdValue,
                      onSave: onSave,
                    );
                  },
                );
              },
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20)
                    .copyWith(bottom: 100),
                child: _ModelManagementContent(
                  currentSelectedIds: currentSelectedIds,
                  currentDefaultId: currentDefaultId,
                  promptConfig: promptConfig,
                  onSelectionChanged: (newSelectedIds, newDefaultId) {
                    selectedIds.value = newSelectedIds;
                    defaultId.value = newDefaultId;
                  },
                ),
              ),
            ],
          ),
        ),
      ];
    },
  );
}

// New sticky action bar widget with premium glassmorphic design
class _ModelManagementStickyActionBar extends ConsumerWidget {
  const _ModelManagementStickyActionBar({
    required this.selectedIds,
    required this.defaultId,
    required this.onSave,
  });

  final Set<String> selectedIds;
  final String defaultId;
  final void Function(List<String> newSelectedIds, String newDefaultId) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: LottiTertiaryButton(
                  label: context.messages.cancelButton,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: LottiPrimaryButton(
                  onPressed: (selectedIds.isNotEmpty &&
                          defaultId.isNotEmpty &&
                          selectedIds.contains(defaultId))
                      ? () {
                          onSave(selectedIds.toList(), defaultId);
                          Navigator.of(context).pop();
                        }
                      : null,
                  label: context.messages.saveButtonLabel,
                  icon: Icons.save_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New content widget that handles the scrollable part
class _ModelManagementContent extends ConsumerStatefulWidget {
  const _ModelManagementContent({
    required this.currentSelectedIds,
    required this.currentDefaultId,
    required this.onSelectionChanged,
    this.promptConfig,
  });

  final List<String> currentSelectedIds;
  final String currentDefaultId;
  final AiConfigPrompt? promptConfig;
  final void Function(Set<String> newSelectedIds, String newDefaultId)
      onSelectionChanged;

  @override
  ConsumerState<_ModelManagementContent> createState() =>
      _ModelManagementContentState();
}

class _ModelManagementContentState
    extends ConsumerState<_ModelManagementContent> {
  late Set<String> _selectedIds;
  late String _defaultId;
  String? _selectedProviderId; // null = show all

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.currentSelectedIds.toSet();
    _defaultId = widget.currentDefaultId;
  }

  void _updateSelection() {
    widget.onSelectionChanged(Set<String>.from(_selectedIds), _defaultId);
  }

  List<String> _getUniqueProviderIds(List<AiConfigModel> models) {
    return models.map((m) => m.inferenceProviderId).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final allModelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );

    return allModelsAsync.when(
      data: (allModels) {
        final allModelConfigs = allModels.whereType<AiConfigModel>().toList();

        // Filter models based on prompt requirements if promptConfig is provided
        final modelConfigs = widget.promptConfig != null
            ? allModelConfigs
                .where(
                  (model) => isModelSuitableForPrompt(
                    model: model,
                    prompt: widget.promptConfig!,
                  ),
                )
                .toList()
            : allModelConfigs;

        if (modelConfigs.isEmpty) {
          final message = widget.promptConfig != null
              ? context.messages.aiConfigNoSuitableModelsAvailable
              : context.messages.aiConfigNoModelsAvailable;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 64,
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final uniqueProviderIds = _getUniqueProviderIds(modelConfigs);

        // Apply provider filter to models
        final displayedModels = _selectedProviderId == null
            ? modelConfigs
            : modelConfigs
                .where((m) => m.inferenceProviderId == _selectedProviderId)
                .toList();

        // Build the models list with fixed height container
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider filter chips row with horizontal scroll
                if (uniqueProviderIds.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // "All" chip
                        FilterChip(
                          label: Text(context.messages.tasksLabelFilterAll),
                          selected: _selectedProviderId == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedProviderId = null;
                            });
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: context
                              .colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.5),
                          selectedColor: context.colorScheme.primaryContainer
                              .withValues(alpha: 0.7),
                          checkmarkColor:
                              context.colorScheme.onPrimaryContainer,
                          side: BorderSide(
                            color: _selectedProviderId == null
                                ? context.colorScheme.primary
                                    .withValues(alpha: 0.8)
                                : context.colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: _selectedProviderId == null
                                ? context.colorScheme.onPrimaryContainer
                                : context.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Provider chips
                        ...uniqueProviderIds.map((providerId) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ProviderFilterChip(
                              providerId: providerId,
                              isSelected: _selectedProviderId == providerId,
                              onTap: () {
                                setState(() {
                                  _selectedProviderId = providerId;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // Add 10px spacing above the first card (only if no filter chips)
                if (uniqueProviderIds.length <= 1) const SizedBox(height: 10),
                // Models list with enhanced styling
                ...displayedModels.map((model) {
                  final isSelected = _selectedIds.contains(model.id);
                  final isDefault = _defaultId == model.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ModelCard(
                      model: model,
                      isSelected: isSelected,
                      isDefault: isDefault,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(model.id);
                            if (isDefault) {
                              _defaultId = _selectedIds.isNotEmpty
                                  ? _selectedIds.first
                                  : '';
                            }
                          } else {
                            _selectedIds.add(model.id);
                            if (_selectedIds.length == 1 ||
                                _defaultId.isEmpty) {
                              _defaultId = model.id;
                            }
                          }
                          _updateSelection();
                        });
                      },
                      onSetDefault: isSelected
                          ? () {
                              setState(() {
                                _defaultId = model.id;
                                _updateSelection();
                              });
                            }
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: context.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  context.messages.aiConfigFailedToLoadModelsGeneric,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
    this.onSetDefault,
  });

  final AiConfigModel model;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback? onSetDefault;

  IconData _getModelIcon() {
    final modelName = model.name.toLowerCase();
    if (modelName.contains('gpt')) return Icons.psychology;
    if (modelName.contains('claude')) return Icons.auto_awesome;
    if (modelName.contains('gemini')) return Icons.diamond;
    if (modelName.contains('opus')) return Icons.workspace_premium;
    if (modelName.contains('sonnet')) return Icons.edit_note;
    if (modelName.contains('haiku')) return Icons.flash_on;
    return Icons.smart_toy;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        elevation: isSelected ? 2 : 0,
        shadowColor: context.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : context.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? context.colorScheme.primary.withValues(alpha: 0.5)
                    : context.colorScheme.surface,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? context.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.colorScheme.outline.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 12,
                          color: context.colorScheme.onPrimary,
                        )
                      : null,
                ),

                const SizedBox(width: 10),

                // Model icon with premium container
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.7),
                        context.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getModelIcon(),
                    size: 18,
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(width: 10),

                // Model info with enhanced typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Model name and default badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.name,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    context.colorScheme.primary,
                                    context.colorScheme.primary
                                        .withValues(alpha: 0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                context.messages.promptDefaultModelBadge,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Provider name with refined styling
                      _CompactProviderName(
                          providerId: model.inferenceProviderId),

                      // Description with better typography
                      if (model.description != null &&
                          model.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          model.description!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontSize: 11,
                            height: 1.3,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Set as default button with enhanced design
                if (isSelected && !isDefault) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onSetDefault,
                    icon: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colorScheme.primaryContainer,
                            context.colorScheme.primaryContainer
                                .withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.colorScheme.primary
                                .withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: context.colorScheme.primary,
                      ),
                    ),
                    tooltip: 'Set as default',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class ProviderFilterChip extends ConsumerWidget {
  const ProviderFilterChip({
    required this.providerId,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String providerId;
  final bool isSelected;
  final VoidCallback onTap;

  /// Get unique color for each provider type that works in both themes
  Color _getProviderColor(
      InferenceProviderType type, BuildContext context, bool isDark) {
    switch (type) {
      case InferenceProviderType.anthropic:
        return isDark
            ? const Color(0xFFD4A574)
            : const Color(0xFFB8864E); // Warm bronze
      case InferenceProviderType.openAi:
        return isDark
            ? const Color(0xFF6BCF7F)
            : const Color(0xFF4CAF50); // Green
      case InferenceProviderType.gemini:
        return isDark
            ? const Color(0xFF73B6F5)
            : const Color(0xFF2196F3); // Blue
      case InferenceProviderType.ollama:
        return isDark
            ? const Color(0xFFFF9F68)
            : const Color(0xFFFF7043); // Orange
      case InferenceProviderType.openRouter:
        return isDark
            ? const Color(0xFF4ECDC4)
            : const Color(0xFF00BCD4); // Teal
      case InferenceProviderType.genericOpenAi:
        return isDark
            ? const Color(0xFFA78BFA)
            : const Color(0xFF9C27B0); // Purple
      case InferenceProviderType.nebiusAiStudio:
        return isDark
            ? const Color(0xFFF06292)
            : const Color(0xFFE91E63); // Pink
      case InferenceProviderType.whisper:
        return isDark
            ? const Color(0xFFFF8A65)
            : const Color(0xFFFF5722); // Deep Orange
      case InferenceProviderType.gemma3n:
        return isDark
            ? const Color(0xFF81C784)
            : const Color(0xFF66BB6A); // Light Green
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(aiConfigByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) return const SizedBox.shrink();
        if (provider is! AiConfigInferenceProvider) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final providerColor = _getProviderColor(
          provider.inferenceProviderType,
          context,
          isDark,
        );

        final backgroundColor = isSelected
            ? providerColor.withValues(alpha: isDark ? 0.35 : 0.22)
            : providerColor.withValues(alpha: isDark ? 0.25 : 0.15);
        final borderColor = isSelected
            ? providerColor.withValues(alpha: 0.55)
            : providerColor.withValues(alpha: 0.35);
        final textColor = isDark ? Colors.white : Colors.black;

        return FilterChip(
          selected: isSelected,
          onSelected: (_) => onTap(),
          label: Text(provider.name),
          avatar: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  providerColor,
                  providerColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: providerColor.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          checkmarkColor: textColor,
          backgroundColor: backgroundColor,
          selectedColor: backgroundColor,
          side: BorderSide(
            color: borderColor,
            width: 1.5,
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: textColor,
          ),
          showCheckmark: isSelected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CompactProviderName extends ConsumerWidget {
  const _CompactProviderName({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(aiConfigByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        final providerName = provider?.name ?? 'Unknown';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            providerName,
            style: context.textTheme.bodySmall?.copyWith(
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              fontSize: 10,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Loading...',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Error',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error.withValues(alpha: 0.8),
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
