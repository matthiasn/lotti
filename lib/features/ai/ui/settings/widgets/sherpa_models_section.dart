import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Explicit device-local downloads, separate from synced model configurations.
class SherpaModelsSection extends StatefulWidget {
  const SherpaModelsSection({required this.providerId, super.key});

  final String providerId;

  @override
  State<SherpaModelsSection> createState() => _SherpaModelsSectionState();
}

class _SherpaModelsSectionState extends State<SherpaModelsSection> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _family;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(SherpaModel model) {
    if (_family != null && model.family != _family) return false;
    final searchable = [
      model.name,
      model.id,
      model.family,
      model.publisher,
      for (final code in model.languageCodes) ...[
        code,
        SupportedLanguage.fromCode(code)?.name ?? code,
        _languageName(context, code),
      ],
    ].join(' ').toLowerCase();
    return _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every(searchable.contains);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final families = sherpaModels.map((model) => model.family).toSet().toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.messages.sherpaModelCatalogTitle,
          style: tokens.typography.styles.subtitle.subtitle1,
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(context.messages.sherpaProviderDescription),
        SizedBox(height: tokens.spacing.step4),
        AiSettingsSearchBar(
          key: const ValueKey('sherpa-model-catalog-search'),
          controller: _searchController,
          hintText: context.messages.aiProfileModelPickerSearchHint,
          isCompact: true,
          onChanged: (value) => setState(() => _query = value),
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemDropdown(
          key: const ValueKey('sherpa-model-family'),
          label: context.messages.sherpaModelFamily,
          inputLabel: _family ?? context.messages.sherpaAllFamilies,
          size: DesignSystemDropdownSize.small,
          items: [
            DesignSystemDropdownItem(
              id: '',
              label: context.messages.sherpaAllFamilies,
              selected: _family == null,
            ),
            for (final family in families)
              DesignSystemDropdownItem(
                id: family,
                label: family,
                selected: family == _family,
              ),
          ],
          onItemPressed: (item) =>
              setState(() => _family = item.id.isEmpty ? null : item.id),
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          context.messages.sherpaCatalogMatches(
            sherpaModels.where(_matches).length,
            sherpaModels.length,
          ),
          style: tokens.typography.styles.body.bodySmall,
        ),
        SizedBox(height: tokens.spacing.step3),
        if (!sherpaModels.any(_matches))
          Text(context.messages.filterSelectionNoMatches),
        DesignSystemGroupedList(
          padding: EdgeInsets.zero,
          children: [
            for (final model in sherpaModels)
              _ModelDownload(
                key: ValueKey('sherpa-model-${model.id}'),
                model: model,
                providerId: widget.providerId,
                matchesQuery: _matches(model),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModelDownload extends ConsumerStatefulWidget {
  const _ModelDownload({
    required this.model,
    required this.providerId,
    required this.matchesQuery,
    super.key,
  });

  final bool matchesQuery;
  final SherpaModel model;
  final String providerId;

  @override
  ConsumerState<_ModelDownload> createState() => _ModelDownloadState();
}

enum _ModelOperation { installing, removing, configuring }

class _ModelDownloadState extends ConsumerState<_ModelDownload> {
  late Future<bool> _installed;
  double? _progress;
  _ModelOperation? _operation;
  bool get _busy => _operation != null;
  bool _failed = false;
  bool _configurationFailed = false;
  bool _configurationMissing = false;

  @override
  void initState() {
    super.initState();
    _installed = _loadInstallation();
  }

  Future<bool> _loadInstallation() async {
    final models = ref.read(sherpaModelRepositoryProvider);
    final installed = await models.isInstalled(widget.model.id);
    if (installed && mounted) {
      final configs = ref.read(aiConfigRepositoryProvider);
      try {
        final existing = await configs.getConfigsByType(AiConfigType.model);
        if (mounted) {
          _configurationMissing = !existing.whereType<AiConfigModel>().any(
            (model) =>
                model.inferenceProviderId == widget.providerId &&
                model.providerModelId == widget.model.id,
          );
        }
      } catch (_) {
        if (mounted) _configurationFailed = true;
      }
    }
    return installed;
  }

  Future<void> _download() async {
    if (_busy) return;
    final models = ref.read(sherpaModelRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final configs = ref.read(aiConfigRepositoryProvider);
    setState(() {
      _operation = _ModelOperation.installing;
      _progress = 0;
      _failed = false;
      _configurationFailed = false;
    });
    try {
      await models.install(
        widget.model.id,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) {
        setState(() {
          _installed = Future.value(true);
        });
      }
      await _modelsChanged(container);
      await _saveConfiguration(configs);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _progress = null;
          _operation = null;
        });
      }
    }
  }

  /// Retry the synced configuration independently of verified device files.
  Future<void> _retryConfiguration() async {
    if (_busy) return;
    final configs = ref.read(aiConfigRepositoryProvider);
    setState(() {
      _operation = _ModelOperation.configuring;
      _failed = false;
    });
    await _saveConfiguration(configs);
    if (mounted) setState(() => _operation = null);
  }

  Future<void> _saveConfiguration(AiConfigRepository configs) async {
    try {
      // A synced row may already exist. Re-create only a missing/deleted row,
      // so downloading does not rewrite its profile references or user edits.
      final existing = await configs.getConfigsByType(AiConfigType.model);
      if (!existing.whereType<AiConfigModel>().any(
        (model) =>
            model.inferenceProviderId == widget.providerId &&
            model.providerModelId == widget.model.id,
      )) {
        final known = sherpaSpeechModels.firstWhere(
          (model) => model.providerModelId == widget.model.id,
        );
        await configs.saveConfig(
          known.toAiConfigModel(
            id: generateModelId(
              widget.providerId,
              widget.model.id,
            ),
            inferenceProviderId: widget.providerId,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _configurationFailed = false;
          _configurationMissing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _configurationFailed = true);
    }
  }

  Future<void> _modelsChanged(ProviderContainer container) async {
    try {
      container.invalidate(sherpaInstalledModelIdsProvider);
      await getIt<SyncNodeProfileBroadcaster>().broadcastIfChanged();
    } catch (error, stackTrace) {
      // A sync failure does not undo a successful local file operation.
      developer.log(
        'Failed to advertise updated speech capability',
        name: 'SherpaModelsSection',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    final models = ref.read(sherpaModelRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _operation = _ModelOperation.removing;
      _failed = false;
    });
    try {
      await models.remove(widget.model.id);
      await _modelsChanged(container);
      if (mounted) {
        setState(() {
          _installed = Future.value(false);
          _configurationFailed = false;
          _configurationMissing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sherpaInstalledModelIdsProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before != null &&
          after != null &&
          before.contains(widget.model.id) != after.contains(widget.model.id)) {
        setState(() {
          _installed = _loadInstallation();
        });
      }
    });
    final tokens = context.designTokens;
    final messages = context.messages;
    final numberFormat = NumberFormat.decimalPattern(messages.localeName);
    final metadata = widget.model.bytes >= 1000000000
        ? messages.sherpaModelSizeGB(
            NumberFormat(
              '0.00',
              messages.localeName,
            ).format(widget.model.bytes / 1000000000),
          )
        : messages.sherpaModelSizeMB(
            numberFormat.format((widget.model.bytes / 1000000).ceil()),
          );
    return Visibility(
      visible: widget.matchesQuery || _busy || _failed || _configurationFailed,
      maintainState: true,
      child: FutureBuilder<bool>(
        future: _installed,
        builder: (context, snapshot) => Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: tokens.spacing.step4,
                runSpacing: tokens.spacing.step3,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.model.name,
                        style: tokens.typography.styles.subtitle.subtitle2,
                      ),
                      if (widget.model.languageCodes.isNotEmpty &&
                          widget.model.languageCodes.length <= 5) ...[
                        SizedBox(height: tokens.spacing.step2),
                        Text(
                          widget.model.languageCodes
                              .map((code) => _languageName(context, code))
                              .join(' · '),
                          style: tokens.typography.styles.body.bodySmall,
                        ),
                      ],
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        metadata,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                  if (_progress != null)
                    const SizedBox.shrink()
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    const DesignSystemSpinner(
                      size: IconSizes.s,
                      strokeWidth: BorderWidths.emphasis,
                    )
                  else if (snapshot.data ?? false)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: tokens.spacing.step2,
                      children: [
                        Text(
                          messages.sherpaModelInstalled,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                        if (_configurationMissing && !_configurationFailed)
                          DesignSystemButton(
                            label: messages.aiProviderDetailAddModelButton,
                            variant: DesignSystemButtonVariant.outlined,
                            isLoading:
                                _operation == _ModelOperation.configuring,
                            onPressed: _busy ? null : _retryConfiguration,
                          ),
                        DesignSystemIconAction(
                          icon: LottiIcons.delete,
                          tooltip: messages.sherpaDeleteModel(
                            widget.model.name,
                          ),
                          isBusy: _operation == _ModelOperation.removing,
                          onPressed: _busy ? null : _remove,
                        ),
                      ],
                    )
                  else
                    DesignSystemButton(
                      label: messages.sherpaDownloadAction,
                      semanticsLabel: messages.sherpaDownloadModel(
                        widget.model.name,
                      ),
                      leadingIcon: LottiIcons.download,
                      variant: DesignSystemButtonVariant.outlined,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      onPressed: _download,
                    ),
                ],
              ),
              if (_progress != null) ...[
                SizedBox(height: tokens.spacing.step3),
                DesignSystemProgressBar(
                  value: _progress!,
                  label: messages.sherpaInstallingModel,
                  semanticsLabel: messages.sherpaDownloadModel(
                    widget.model.name,
                  ),
                  progressText: NumberFormat.percentPattern(
                    messages.localeName,
                  ).format(_progress!.clamp(0, 1)),
                ),
              ],
              if (_configurationFailed) ...[
                SizedBox(height: tokens.spacing.step3),
                Text(
                  messages.sherpaModelConfigurationError,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DesignSystemButton(
                    label: messages.aiProviderConnectionRetryButton,
                    isLoading: _operation == _ModelOperation.configuring,
                    variant: DesignSystemButtonVariant.tertiary,
                    onPressed: _busy ? null : _retryConfiguration,
                  ),
                ),
              ],
              if (_failed || snapshot.hasError) ...[
                SizedBox(height: tokens.spacing.step3),
                Text(
                  messages.sherpaModelError,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _languageName(BuildContext context, String code) => code == 'yue'
    ? context.messages.sherpaLanguageCantonese
    : SupportedLanguage.fromCode(code)?.localizedName(context) ?? code;
