// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
AiConfig _$AiConfigFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'inferenceProvider':
      return AiConfigInferenceProvider.fromJson(json);
    case 'model':
      return AiConfigModel.fromJson(json);
    case 'prompt':
      return AiConfigPrompt.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'AiConfig',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$AiConfig {
  String get id;
  String get name;
  DateTime get createdAt;
  DateTime? get updatedAt;
  String? get description;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiConfigCopyWith<AiConfig> get copyWith =>
      _$AiConfigCopyWithImpl<AiConfig>(this as AiConfig, _$identity);

  /// Serializes this AiConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiConfig &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, createdAt, updatedAt, description);
}

/// @nodoc
abstract mixin class $AiConfigCopyWith<$Res> {
  factory $AiConfigCopyWith(AiConfig value, $Res Function(AiConfig) _then) =
      _$AiConfigCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      DateTime createdAt,
      DateTime? updatedAt,
      String? description});
}

/// @nodoc
class _$AiConfigCopyWithImpl<$Res> implements $AiConfigCopyWith<$Res> {
  _$AiConfigCopyWithImpl(this._self, this._then);

  final AiConfig _self;
  final $Res Function(AiConfig) _then;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? description = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiConfig].
extension AiConfigPatterns on AiConfig {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult Function(AiConfigModel value)? model,
    TResult Function(AiConfigPrompt value)? prompt,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AiConfigInferenceProvider() when inferenceProvider != null:
        return inferenceProvider(_that);
      case AiConfigModel() when model != null:
        return model(_that);
      case AiConfigPrompt() when prompt != null:
        return prompt(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigInferenceProvider value)
        inferenceProvider,
    required TResult Function(AiConfigModel value) model,
    required TResult Function(AiConfigPrompt value) prompt,
  }) {
    final _that = this;
    switch (_that) {
      case AiConfigInferenceProvider():
        return inferenceProvider(_that);
      case AiConfigModel():
        return model(_that);
      case AiConfigPrompt():
        return prompt(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult? Function(AiConfigModel value)? model,
    TResult? Function(AiConfigPrompt value)? prompt,
  }) {
    final _that = this;
    switch (_that) {
      case AiConfigInferenceProvider() when inferenceProvider != null:
        return inferenceProvider(_that);
      case AiConfigModel() when model != null:
        return model(_that);
      case AiConfigPrompt() when prompt != null:
        return prompt(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String baseUrl,
            String apiKey,
            String name,
            DateTime createdAt,
            InferenceProviderType inferenceProviderType,
            DateTime? updatedAt,
            String? description)?
        inferenceProvider,
    TResult Function(
            String id,
            String name,
            String providerModelId,
            String inferenceProviderId,
            DateTime createdAt,
            List<Modality> inputModalities,
            List<Modality> outputModalities,
            bool isReasoningModel,
            bool supportsFunctionCalling,
            DateTime? updatedAt,
            String? description,
            int? maxCompletionTokens)?
        model,
    TResult Function(
            String id,
            String name,
            String systemMessage,
            String userMessage,
            String defaultModelId,
            List<String> modelIds,
            DateTime createdAt,
            bool useReasoning,
            List<InputDataType> requiredInputData,
            AiResponseType aiResponseType,
            String? comment,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category,
            bool archived,
            bool trackPreconfigured,
            String? preconfiguredPromptId)?
        prompt,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AiConfigInferenceProvider() when inferenceProvider != null:
        return inferenceProvider(
            _that.id,
            _that.baseUrl,
            _that.apiKey,
            _that.name,
            _that.createdAt,
            _that.inferenceProviderType,
            _that.updatedAt,
            _that.description);
      case AiConfigModel() when model != null:
        return model(
            _that.id,
            _that.name,
            _that.providerModelId,
            _that.inferenceProviderId,
            _that.createdAt,
            _that.inputModalities,
            _that.outputModalities,
            _that.isReasoningModel,
            _that.supportsFunctionCalling,
            _that.updatedAt,
            _that.description,
            _that.maxCompletionTokens);
      case AiConfigPrompt() when prompt != null:
        return prompt(
            _that.id,
            _that.name,
            _that.systemMessage,
            _that.userMessage,
            _that.defaultModelId,
            _that.modelIds,
            _that.createdAt,
            _that.useReasoning,
            _that.requiredInputData,
            _that.aiResponseType,
            _that.comment,
            _that.updatedAt,
            _that.description,
            _that.defaultVariables,
            _that.category,
            _that.archived,
            _that.trackPreconfigured,
            _that.preconfiguredPromptId);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String baseUrl,
            String apiKey,
            String name,
            DateTime createdAt,
            InferenceProviderType inferenceProviderType,
            DateTime? updatedAt,
            String? description)
        inferenceProvider,
    required TResult Function(
            String id,
            String name,
            String providerModelId,
            String inferenceProviderId,
            DateTime createdAt,
            List<Modality> inputModalities,
            List<Modality> outputModalities,
            bool isReasoningModel,
            bool supportsFunctionCalling,
            DateTime? updatedAt,
            String? description,
            int? maxCompletionTokens)
        model,
    required TResult Function(
            String id,
            String name,
            String systemMessage,
            String userMessage,
            String defaultModelId,
            List<String> modelIds,
            DateTime createdAt,
            bool useReasoning,
            List<InputDataType> requiredInputData,
            AiResponseType aiResponseType,
            String? comment,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category,
            bool archived,
            bool trackPreconfigured,
            String? preconfiguredPromptId)
        prompt,
  }) {
    final _that = this;
    switch (_that) {
      case AiConfigInferenceProvider():
        return inferenceProvider(
            _that.id,
            _that.baseUrl,
            _that.apiKey,
            _that.name,
            _that.createdAt,
            _that.inferenceProviderType,
            _that.updatedAt,
            _that.description);
      case AiConfigModel():
        return model(
            _that.id,
            _that.name,
            _that.providerModelId,
            _that.inferenceProviderId,
            _that.createdAt,
            _that.inputModalities,
            _that.outputModalities,
            _that.isReasoningModel,
            _that.supportsFunctionCalling,
            _that.updatedAt,
            _that.description,
            _that.maxCompletionTokens);
      case AiConfigPrompt():
        return prompt(
            _that.id,
            _that.name,
            _that.systemMessage,
            _that.userMessage,
            _that.defaultModelId,
            _that.modelIds,
            _that.createdAt,
            _that.useReasoning,
            _that.requiredInputData,
            _that.aiResponseType,
            _that.comment,
            _that.updatedAt,
            _that.description,
            _that.defaultVariables,
            _that.category,
            _that.archived,
            _that.trackPreconfigured,
            _that.preconfiguredPromptId);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String baseUrl,
            String apiKey,
            String name,
            DateTime createdAt,
            InferenceProviderType inferenceProviderType,
            DateTime? updatedAt,
            String? description)?
        inferenceProvider,
    TResult? Function(
            String id,
            String name,
            String providerModelId,
            String inferenceProviderId,
            DateTime createdAt,
            List<Modality> inputModalities,
            List<Modality> outputModalities,
            bool isReasoningModel,
            bool supportsFunctionCalling,
            DateTime? updatedAt,
            String? description,
            int? maxCompletionTokens)?
        model,
    TResult? Function(
            String id,
            String name,
            String systemMessage,
            String userMessage,
            String defaultModelId,
            List<String> modelIds,
            DateTime createdAt,
            bool useReasoning,
            List<InputDataType> requiredInputData,
            AiResponseType aiResponseType,
            String? comment,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category,
            bool archived,
            bool trackPreconfigured,
            String? preconfiguredPromptId)?
        prompt,
  }) {
    final _that = this;
    switch (_that) {
      case AiConfigInferenceProvider() when inferenceProvider != null:
        return inferenceProvider(
            _that.id,
            _that.baseUrl,
            _that.apiKey,
            _that.name,
            _that.createdAt,
            _that.inferenceProviderType,
            _that.updatedAt,
            _that.description);
      case AiConfigModel() when model != null:
        return model(
            _that.id,
            _that.name,
            _that.providerModelId,
            _that.inferenceProviderId,
            _that.createdAt,
            _that.inputModalities,
            _that.outputModalities,
            _that.isReasoningModel,
            _that.supportsFunctionCalling,
            _that.updatedAt,
            _that.description,
            _that.maxCompletionTokens);
      case AiConfigPrompt() when prompt != null:
        return prompt(
            _that.id,
            _that.name,
            _that.systemMessage,
            _that.userMessage,
            _that.defaultModelId,
            _that.modelIds,
            _that.createdAt,
            _that.useReasoning,
            _that.requiredInputData,
            _that.aiResponseType,
            _that.comment,
            _that.updatedAt,
            _that.description,
            _that.defaultVariables,
            _that.category,
            _that.archived,
            _that.trackPreconfigured,
            _that.preconfiguredPromptId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class AiConfigInferenceProvider implements AiConfig {
  const AiConfigInferenceProvider(
      {required this.id,
      required this.baseUrl,
      required this.apiKey,
      required this.name,
      required this.createdAt,
      required this.inferenceProviderType,
      this.updatedAt,
      this.description,
      final String? $type})
      : $type = $type ?? 'inferenceProvider';
  factory AiConfigInferenceProvider.fromJson(Map<String, dynamic> json) =>
      _$AiConfigInferenceProviderFromJson(json);

  @override
  final String id;
  final String baseUrl;
  final String apiKey;
  @override
  final String name;
  @override
  final DateTime createdAt;
  final InferenceProviderType inferenceProviderType;
  @override
  final DateTime? updatedAt;
  @override
  final String? description;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiConfigInferenceProviderCopyWith<AiConfigInferenceProvider> get copyWith =>
      _$AiConfigInferenceProviderCopyWithImpl<AiConfigInferenceProvider>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiConfigInferenceProviderToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiConfigInferenceProvider &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.inferenceProviderType, inferenceProviderType) ||
                other.inferenceProviderType == inferenceProviderType) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, baseUrl, apiKey, name,
      createdAt, inferenceProviderType, updatedAt, description);
}

/// @nodoc
abstract mixin class $AiConfigInferenceProviderCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory $AiConfigInferenceProviderCopyWith(AiConfigInferenceProvider value,
          $Res Function(AiConfigInferenceProvider) _then) =
      _$AiConfigInferenceProviderCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String baseUrl,
      String apiKey,
      String name,
      DateTime createdAt,
      InferenceProviderType inferenceProviderType,
      DateTime? updatedAt,
      String? description});
}

/// @nodoc
class _$AiConfigInferenceProviderCopyWithImpl<$Res>
    implements $AiConfigInferenceProviderCopyWith<$Res> {
  _$AiConfigInferenceProviderCopyWithImpl(this._self, this._then);

  final AiConfigInferenceProvider _self;
  final $Res Function(AiConfigInferenceProvider) _then;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? name = null,
    Object? createdAt = null,
    Object? inferenceProviderType = null,
    Object? updatedAt = freezed,
    Object? description = freezed,
  }) {
    return _then(AiConfigInferenceProvider(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: null == baseUrl
          ? _self.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _self.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      inferenceProviderType: null == inferenceProviderType
          ? _self.inferenceProviderType
          : inferenceProviderType // ignore: cast_nullable_to_non_nullable
              as InferenceProviderType,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AiConfigModel implements AiConfig {
  const AiConfigModel(
      {required this.id,
      required this.name,
      required this.providerModelId,
      required this.inferenceProviderId,
      required this.createdAt,
      required final List<Modality> inputModalities,
      required final List<Modality> outputModalities,
      required this.isReasoningModel,
      this.supportsFunctionCalling = false,
      this.updatedAt,
      this.description,
      this.maxCompletionTokens,
      final String? $type})
      : _inputModalities = inputModalities,
        _outputModalities = outputModalities,
        $type = $type ?? 'model';
  factory AiConfigModel.fromJson(Map<String, dynamic> json) =>
      _$AiConfigModelFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final String providerModelId;
  final String inferenceProviderId;
  @override
  final DateTime createdAt;
  final List<Modality> _inputModalities;
  List<Modality> get inputModalities {
    if (_inputModalities is EqualUnmodifiableListView) return _inputModalities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_inputModalities);
  }

  final List<Modality> _outputModalities;
  List<Modality> get outputModalities {
    if (_outputModalities is EqualUnmodifiableListView)
      return _outputModalities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_outputModalities);
  }

  final bool isReasoningModel;
  @JsonKey()
  final bool supportsFunctionCalling;
  @override
  final DateTime? updatedAt;
  @override
  final String? description;
  final int? maxCompletionTokens;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiConfigModelCopyWith<AiConfigModel> get copyWith =>
      _$AiConfigModelCopyWithImpl<AiConfigModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiConfigModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiConfigModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.providerModelId, providerModelId) ||
                other.providerModelId == providerModelId) &&
            (identical(other.inferenceProviderId, inferenceProviderId) ||
                other.inferenceProviderId == inferenceProviderId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality()
                .equals(other._inputModalities, _inputModalities) &&
            const DeepCollectionEquality()
                .equals(other._outputModalities, _outputModalities) &&
            (identical(other.isReasoningModel, isReasoningModel) ||
                other.isReasoningModel == isReasoningModel) &&
            (identical(
                    other.supportsFunctionCalling, supportsFunctionCalling) ||
                other.supportsFunctionCalling == supportsFunctionCalling) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.maxCompletionTokens, maxCompletionTokens) ||
                other.maxCompletionTokens == maxCompletionTokens));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      providerModelId,
      inferenceProviderId,
      createdAt,
      const DeepCollectionEquality().hash(_inputModalities),
      const DeepCollectionEquality().hash(_outputModalities),
      isReasoningModel,
      supportsFunctionCalling,
      updatedAt,
      description,
      maxCompletionTokens);
}

/// @nodoc
abstract mixin class $AiConfigModelCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory $AiConfigModelCopyWith(
          AiConfigModel value, $Res Function(AiConfigModel) _then) =
      _$AiConfigModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String providerModelId,
      String inferenceProviderId,
      DateTime createdAt,
      List<Modality> inputModalities,
      List<Modality> outputModalities,
      bool isReasoningModel,
      bool supportsFunctionCalling,
      DateTime? updatedAt,
      String? description,
      int? maxCompletionTokens});
}

/// @nodoc
class _$AiConfigModelCopyWithImpl<$Res>
    implements $AiConfigModelCopyWith<$Res> {
  _$AiConfigModelCopyWithImpl(this._self, this._then);

  final AiConfigModel _self;
  final $Res Function(AiConfigModel) _then;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? providerModelId = null,
    Object? inferenceProviderId = null,
    Object? createdAt = null,
    Object? inputModalities = null,
    Object? outputModalities = null,
    Object? isReasoningModel = null,
    Object? supportsFunctionCalling = null,
    Object? updatedAt = freezed,
    Object? description = freezed,
    Object? maxCompletionTokens = freezed,
  }) {
    return _then(AiConfigModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      providerModelId: null == providerModelId
          ? _self.providerModelId
          : providerModelId // ignore: cast_nullable_to_non_nullable
              as String,
      inferenceProviderId: null == inferenceProviderId
          ? _self.inferenceProviderId
          : inferenceProviderId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      inputModalities: null == inputModalities
          ? _self._inputModalities
          : inputModalities // ignore: cast_nullable_to_non_nullable
              as List<Modality>,
      outputModalities: null == outputModalities
          ? _self._outputModalities
          : outputModalities // ignore: cast_nullable_to_non_nullable
              as List<Modality>,
      isReasoningModel: null == isReasoningModel
          ? _self.isReasoningModel
          : isReasoningModel // ignore: cast_nullable_to_non_nullable
              as bool,
      supportsFunctionCalling: null == supportsFunctionCalling
          ? _self.supportsFunctionCalling
          : supportsFunctionCalling // ignore: cast_nullable_to_non_nullable
              as bool,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      maxCompletionTokens: freezed == maxCompletionTokens
          ? _self.maxCompletionTokens
          : maxCompletionTokens // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AiConfigPrompt implements AiConfig {
  const AiConfigPrompt(
      {required this.id,
      required this.name,
      required this.systemMessage,
      required this.userMessage,
      required this.defaultModelId,
      required final List<String> modelIds,
      required this.createdAt,
      required this.useReasoning,
      required final List<InputDataType> requiredInputData,
      required this.aiResponseType,
      this.comment,
      this.updatedAt,
      this.description,
      final Map<String, String>? defaultVariables,
      this.category,
      this.archived = false,
      this.trackPreconfigured = false,
      this.preconfiguredPromptId,
      final String? $type})
      : _modelIds = modelIds,
        _requiredInputData = requiredInputData,
        _defaultVariables = defaultVariables,
        $type = $type ?? 'prompt';
  factory AiConfigPrompt.fromJson(Map<String, dynamic> json) =>
      _$AiConfigPromptFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final String systemMessage;
  final String userMessage;
  final String defaultModelId;
  final List<String> _modelIds;
  List<String> get modelIds {
    if (_modelIds is EqualUnmodifiableListView) return _modelIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_modelIds);
  }

  @override
  final DateTime createdAt;
  final bool useReasoning;
  final List<InputDataType> _requiredInputData;
  List<InputDataType> get requiredInputData {
    if (_requiredInputData is EqualUnmodifiableListView)
      return _requiredInputData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requiredInputData);
  }

  final AiResponseType aiResponseType;
  final String? comment;
  @override
  final DateTime? updatedAt;
  @override
  final String? description;
  final Map<String, String>? _defaultVariables;
  Map<String, String>? get defaultVariables {
    final value = _defaultVariables;
    if (value == null) return null;
    if (_defaultVariables is EqualUnmodifiableMapView) return _defaultVariables;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final String? category;
  @JsonKey()
  final bool archived;
  @JsonKey()
  final bool trackPreconfigured;
  final String? preconfiguredPromptId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiConfigPromptCopyWith<AiConfigPrompt> get copyWith =>
      _$AiConfigPromptCopyWithImpl<AiConfigPrompt>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiConfigPromptToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiConfigPrompt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.systemMessage, systemMessage) ||
                other.systemMessage == systemMessage) &&
            (identical(other.userMessage, userMessage) ||
                other.userMessage == userMessage) &&
            (identical(other.defaultModelId, defaultModelId) ||
                other.defaultModelId == defaultModelId) &&
            const DeepCollectionEquality().equals(other._modelIds, _modelIds) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.useReasoning, useReasoning) ||
                other.useReasoning == useReasoning) &&
            const DeepCollectionEquality()
                .equals(other._requiredInputData, _requiredInputData) &&
            (identical(other.aiResponseType, aiResponseType) ||
                other.aiResponseType == aiResponseType) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._defaultVariables, _defaultVariables) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.archived, archived) ||
                other.archived == archived) &&
            (identical(other.trackPreconfigured, trackPreconfigured) ||
                other.trackPreconfigured == trackPreconfigured) &&
            (identical(other.preconfiguredPromptId, preconfiguredPromptId) ||
                other.preconfiguredPromptId == preconfiguredPromptId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      systemMessage,
      userMessage,
      defaultModelId,
      const DeepCollectionEquality().hash(_modelIds),
      createdAt,
      useReasoning,
      const DeepCollectionEquality().hash(_requiredInputData),
      aiResponseType,
      comment,
      updatedAt,
      description,
      const DeepCollectionEquality().hash(_defaultVariables),
      category,
      archived,
      trackPreconfigured,
      preconfiguredPromptId);
}

/// @nodoc
abstract mixin class $AiConfigPromptCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory $AiConfigPromptCopyWith(
          AiConfigPrompt value, $Res Function(AiConfigPrompt) _then) =
      _$AiConfigPromptCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String systemMessage,
      String userMessage,
      String defaultModelId,
      List<String> modelIds,
      DateTime createdAt,
      bool useReasoning,
      List<InputDataType> requiredInputData,
      AiResponseType aiResponseType,
      String? comment,
      DateTime? updatedAt,
      String? description,
      Map<String, String>? defaultVariables,
      String? category,
      bool archived,
      bool trackPreconfigured,
      String? preconfiguredPromptId});
}

/// @nodoc
class _$AiConfigPromptCopyWithImpl<$Res>
    implements $AiConfigPromptCopyWith<$Res> {
  _$AiConfigPromptCopyWithImpl(this._self, this._then);

  final AiConfigPrompt _self;
  final $Res Function(AiConfigPrompt) _then;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? systemMessage = null,
    Object? userMessage = null,
    Object? defaultModelId = null,
    Object? modelIds = null,
    Object? createdAt = null,
    Object? useReasoning = null,
    Object? requiredInputData = null,
    Object? aiResponseType = null,
    Object? comment = freezed,
    Object? updatedAt = freezed,
    Object? description = freezed,
    Object? defaultVariables = freezed,
    Object? category = freezed,
    Object? archived = null,
    Object? trackPreconfigured = null,
    Object? preconfiguredPromptId = freezed,
  }) {
    return _then(AiConfigPrompt(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      systemMessage: null == systemMessage
          ? _self.systemMessage
          : systemMessage // ignore: cast_nullable_to_non_nullable
              as String,
      userMessage: null == userMessage
          ? _self.userMessage
          : userMessage // ignore: cast_nullable_to_non_nullable
              as String,
      defaultModelId: null == defaultModelId
          ? _self.defaultModelId
          : defaultModelId // ignore: cast_nullable_to_non_nullable
              as String,
      modelIds: null == modelIds
          ? _self._modelIds
          : modelIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      useReasoning: null == useReasoning
          ? _self.useReasoning
          : useReasoning // ignore: cast_nullable_to_non_nullable
              as bool,
      requiredInputData: null == requiredInputData
          ? _self._requiredInputData
          : requiredInputData // ignore: cast_nullable_to_non_nullable
              as List<InputDataType>,
      aiResponseType: null == aiResponseType
          ? _self.aiResponseType
          : aiResponseType // ignore: cast_nullable_to_non_nullable
              as AiResponseType,
      comment: freezed == comment
          ? _self.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      defaultVariables: freezed == defaultVariables
          ? _self._defaultVariables
          : defaultVariables // ignore: cast_nullable_to_non_nullable
              as Map<String, String>?,
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      archived: null == archived
          ? _self.archived
          : archived // ignore: cast_nullable_to_non_nullable
              as bool,
      trackPreconfigured: null == trackPreconfigured
          ? _self.trackPreconfigured
          : trackPreconfigured // ignore: cast_nullable_to_non_nullable
              as bool,
      preconfiguredPromptId: freezed == preconfiguredPromptId
          ? _self.preconfiguredPromptId
          : preconfiguredPromptId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
