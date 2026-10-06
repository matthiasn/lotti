part of 'melious_inference_repository.dart';

/// Model-catalog parsing for Melious: fetching the endpoint's catalogue, turning its payload into known models with capabilities and descriptions, and logging what it returned.
extension _MeliousCatalog on MeliousInferenceRepository {
  Future<List<KnownModel>> _listModelsFromEndpoint({
    required String baseUrl,
    required String apiKey,
    required bool includeMeta,
    required Duration timeout,
  }) async {
    final uri = MeliousInferenceRepository._buildEndpointUri(
      baseUrl,
      'models',
      queryParameters: includeMeta ? const {'include_meta': 'true'} : const {},
    );

    domainLogger.log(
      LogDomain.ai,
      'Fetching Melious model catalog from $uri',
      subDomain: MeliousInferenceRepository._providerName,
    );

    try {
      final response = await httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(timeout);

      domainLogger.log(
        LogDomain.ai,
        'Melious model catalog response from $uri: HTTP '
        '${response.statusCode}',
        subDomain: MeliousInferenceRepository._providerName,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InferenceHttpException(
          provider: _exceptionProvider,
          ModelCatalogMapping.extractErrorMessage(
            response.body,
            response.statusCode,
            providerLabel: 'Melious',
            maxLength: 240,
            ellipsis: '...',
          ),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = switch (decoded) {
        {'data': final List<dynamic> data} => data,
        final List<dynamic> data => data,
        _ => throw const InferenceHttpException(
          provider: _exceptionProvider,
          'Melious model list response must be a JSON object with data[] '
          'or a JSON array',
        ),
      };
      _logCatalogPayload(uri: uri, decoded: decoded, data: data);

      final models = <KnownModel>[];
      for (final (index, item) in data.indexed) {
        try {
          models.add(_knownModelFromCatalogItem(item));
        } on Exception catch (e, stackTrace) {
          domainLogger.error(
            LogDomain.ai,
            e,
            stackTrace: stackTrace,
            subDomain: MeliousInferenceRepository._providerName,
            message:
                'Failed to parse Melious model catalog row #$index from '
                '$uri: ${_catalogItemSummary(item)}',
          );
          rethrow;
        }
      }

      domainLogger.log(
        LogDomain.ai,
        'Mapped ${models.length} Melious catalog rows from $uri',
        subDomain: MeliousInferenceRepository._providerName,
      );
      return models;
    } on InferenceHttpException {
      rethrow;
    } on TimeoutException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Melious model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Melious model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Failed to fetch Melious models: $e',
        originalError: e,
      );
    }
  }

  KnownModel _knownModelFromCatalogItem(Object? item) {
    if (item is String) {
      return _knownModelFromPayload({'id': item});
    }
    if (item is Map<String, dynamic>) {
      return _knownModelFromPayload(item);
    }

    throw const InferenceHttpException(
      provider: _exceptionProvider,
      'Melious model entry must be a JSON object or string id',
    );
  }

  KnownModel _knownModelFromPayload(Map<String, dynamic> model) {
    final providerModelId = model['id'];
    if (providerModelId is! String || providerModelId.trim().isEmpty) {
      throw const InferenceHttpException(
        provider: _exceptionProvider,
        'Melious model entry is missing a string id',
      );
    }

    final metaMap =
        ModelCatalogMapping.asMap(model['_meta']) ??
        ModelCatalogMapping.asMap(model['metadata']) ??
        const <String, dynamic>{};
    final knownModel = _knownMeliousModels[providerModelId];
    if (knownModel != null && metaMap.isEmpty) {
      return knownModel;
    }

    final capabilityMap =
        ModelCatalogMapping.asMap(metaMap['capabilities']) ??
        ModelCatalogMapping.asMap(model['capabilities']) ??
        const <String, dynamic>{};
    final type = _MeliousModelType.from(metaMap['type'] ?? model['type']);

    final inputModalities = _mergedModalities(
      knownModel?.inputModalities,
      metaMap['input_modalities'] ?? model['input_modalities'],
    );
    final outputModalities = _mergedModalities(
      knownModel?.outputModalities,
      metaMap['output_modalities'] ?? model['output_modalities'],
    );

    _applyCapabilityModalities(
      type: type,
      capabilities: capabilityMap,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
    );

    final supportsFunctionCalling =
        knownModel?.supportsFunctionCalling == true ||
        ModelCatalogMapping.truthy(capabilityMap['function_calling']);
    final isReasoningModel =
        knownModel?.isReasoningModel == true ||
        ModelCatalogMapping.truthy(capabilityMap['reasoning']) ||
        ModelCatalogMapping.truthy(capabilityMap['thinking']) ||
        MeliousInferenceRepository._looksLikeReasoningModel(providerModelId);

    return KnownModel(
      providerModelId: providerModelId,
      name:
          knownModel?.name ??
          ModelCatalogMapping.humanizeModelId(
            providerModelId,
            acronyms: MeliousInferenceRepository._modelNameAcronyms,
          ),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
      supportsFunctionCalling: supportsFunctionCalling,
      description: _descriptionFor(
        model: model,
        type: type,
        capabilities: capabilityMap,
      ),
    );
  }

  void _applyCapabilityModalities({
    required _MeliousModelType type,
    required Map<String, dynamic> capabilities,
    required List<Modality> inputModalities,
    required List<Modality> outputModalities,
  }) {
    switch (type) {
      case _MeliousModelType.chat:
      case _MeliousModelType.unknown:
        ModelCatalogMapping.addUniqueModality(inputModalities, Modality.text);
        ModelCatalogMapping.addUniqueModality(outputModalities, Modality.text);
      case _MeliousModelType.audio:
        ModelCatalogMapping.addUniqueModality(inputModalities, Modality.audio);
        ModelCatalogMapping.addUniqueModality(outputModalities, Modality.text);
      case _MeliousModelType.image:
        ModelCatalogMapping.addUniqueModality(inputModalities, Modality.text);
        ModelCatalogMapping.addUniqueModality(outputModalities, Modality.image);
      case _MeliousModelType.embeddings:
      case _MeliousModelType.rerank:
        ModelCatalogMapping.addUniqueModality(inputModalities, Modality.text);
        ModelCatalogMapping.addUniqueModality(outputModalities, Modality.text);
    }

    if (ModelCatalogMapping.truthy(capabilities['vision'])) {
      ModelCatalogMapping.addUniqueModality(inputModalities, Modality.image);
    }
    if (ModelCatalogMapping.truthy(capabilities['audio_input']) ||
        ModelCatalogMapping.truthy(capabilities['supports_audio']) ||
        ModelCatalogMapping.truthy(capabilities['transcription']) ||
        ModelCatalogMapping.truthy(capabilities['translation']) ||
        ModelCatalogMapping.truthy(capabilities['diarization'])) {
      ModelCatalogMapping.addUniqueModality(inputModalities, Modality.audio);
      ModelCatalogMapping.addUniqueModality(outputModalities, Modality.text);
    }
    if (ModelCatalogMapping.truthy(capabilities['text_to_image'])) {
      ModelCatalogMapping.addUniqueModality(inputModalities, Modality.text);
      ModelCatalogMapping.addUniqueModality(outputModalities, Modality.image);
    }
    if (ModelCatalogMapping.truthy(capabilities['image_to_image'])) {
      ModelCatalogMapping.addUniqueModality(inputModalities, Modality.image);
      ModelCatalogMapping.addUniqueModality(outputModalities, Modality.image);
    }
  }

  static List<Modality> _mergedModalities(
    List<Modality>? knownModalities,
    Object? rawModalities,
  ) {
    final out = <Modality>[];
    for (final modality in knownModalities ?? const <Modality>[]) {
      ModelCatalogMapping.addUniqueModality(out, modality);
    }
    for (final modality in ModelCatalogMapping.modalitiesFrom(rawModalities)) {
      ModelCatalogMapping.addUniqueModality(out, modality);
    }
    return out;
  }

  String _descriptionFor({
    required Map<String, dynamic> model,
    required _MeliousModelType type,
    required Map<String, dynamic> capabilities,
  }) {
    final parts = <String>['Melious ${type.label} model.'];

    final ownedBy = model['owned_by'];
    if (ownedBy is String && ownedBy.trim().isNotEmpty) {
      parts.add('Owned by ${ownedBy.trim()}.');
    }

    final metaMap =
        ModelCatalogMapping.asMap(model['_meta']) ??
        ModelCatalogMapping.asMap(model['metadata']) ??
        const <String, dynamic>{};
    final contextLength = ModelCatalogMapping.integerValue(
      metaMap['context_length'],
    );
    if (contextLength != null) {
      parts.add('Context: $contextLength tokens.');
    }

    final featureLabels = <String>[
      if (ModelCatalogMapping.truthy(capabilities['vision'])) 'vision',
      if (ModelCatalogMapping.truthy(capabilities['audio_input']) ||
          ModelCatalogMapping.truthy(capabilities['supports_audio']))
        'audio input',
      if (ModelCatalogMapping.truthy(capabilities['transcription']))
        'transcription',
      if (ModelCatalogMapping.truthy(capabilities['translation']))
        'translation',
      if (ModelCatalogMapping.truthy(capabilities['diarization']))
        'diarization',
      if (ModelCatalogMapping.truthy(capabilities['text_to_image']))
        'text to image',
      if (ModelCatalogMapping.truthy(capabilities['image_to_image']))
        'image to image',
      if (ModelCatalogMapping.truthy(capabilities['reasoning'])) 'reasoning',
      if (ModelCatalogMapping.truthy(capabilities['thinking'])) 'thinking',
      if (ModelCatalogMapping.truthy(capabilities['function_calling'])) 'tools',
      if (ModelCatalogMapping.truthy(capabilities['structured_output']))
        'structured output',
      if (ModelCatalogMapping.truthy(capabilities['json_schema']))
        'JSON schema',
      if (ModelCatalogMapping.truthy(capabilities['code_generation']))
        'code generation',
      if (ModelCatalogMapping.truthy(capabilities['computer_use']))
        'computer use',
      if (ModelCatalogMapping.truthy(capabilities['lora'])) 'LoRA',
      if (ModelCatalogMapping.truthy(capabilities['streaming'])) 'streaming',
    ];
    if (featureLabels.isNotEmpty) {
      parts.add('Features: ${featureLabels.join(', ')}.');
    }

    return parts.join(' ');
  }

  void _logCatalogPayload({
    required Uri uri,
    required Object? decoded,
    required List<dynamic> data,
  }) {
    final shape = switch (decoded) {
      final Map<String, dynamic> map => 'object keys=${map.keys.join(',')}',
      final List<dynamic> _ => 'array',
      // Unreachable: callers only invoke this after the catalog shape switch
      // has already narrowed `decoded` to a map-with-data or a list. Required
      // for switch exhaustiveness over Object?.
      _ => decoded.runtimeType.toString(), // coverage:ignore-line
    };
    domainLogger.log(
      LogDomain.ai,
      'Melious model catalog payload from $uri: shape=$shape, '
      'count=${data.length}',
      subDomain: MeliousInferenceRepository._providerName,
    );

    final ids = data
        .map(MeliousInferenceRepository._catalogItemIdForLog)
        .toList(growable: false);
    const chunkSize = 25;
    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, ids.length);
      domainLogger.log(
        LogDomain.ai,
        'Melious model catalog IDs ${start + 1}-$end/${ids.length}: '
        '${ids.sublist(start, end).join(', ')}',
        subDomain: MeliousInferenceRepository._providerName,
      );
    }
  }

  static String _catalogItemSummary(Object? item) {
    if (item is String) return item;
    if (item is Map<String, dynamic>) {
      final id = item['id'] ?? item['name'];
      final meta =
          ModelCatalogMapping.asMap(item['_meta']) ??
          ModelCatalogMapping.asMap(item['metadata']);
      final capabilities =
          ModelCatalogMapping.asMap(meta?['capabilities']) ??
          ModelCatalogMapping.asMap(item['capabilities']);
      return [
        if (id is String) 'id=$id' else 'id=<missing>',
        'keys=${item.keys.join(',')}',
        if (meta != null) 'metaKeys=${meta.keys.join(',')}',
        if (capabilities != null)
          'capabilityKeys=${capabilities.keys.join(',')}',
      ].join('; ');
    }
    return '<${item.runtimeType}>';
  }
}
