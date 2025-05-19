// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

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
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
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
            DateTime? updatedAt,
            String? description)
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
            String? category)
        prompt,
  }) =>
      throw _privateConstructorUsedError;
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
  }) =>
      throw _privateConstructorUsedError;
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigInferenceProvider value)
        inferenceProvider,
    required TResult Function(AiConfigModel value) model,
    required TResult Function(AiConfigPrompt value) prompt,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult? Function(AiConfigModel value)? model,
    TResult? Function(AiConfigPrompt value)? prompt,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult Function(AiConfigModel value)? model,
    TResult Function(AiConfigPrompt value)? prompt,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this AiConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiConfigCopyWith<AiConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiConfigCopyWith<$Res> {
  factory $AiConfigCopyWith(AiConfig value, $Res Function(AiConfig) then) =
      _$AiConfigCopyWithImpl<$Res, AiConfig>;
  @useResult
  $Res call(
      {String id,
      String name,
      DateTime createdAt,
      DateTime? updatedAt,
      String? description});
}

/// @nodoc
class _$AiConfigCopyWithImpl<$Res, $Val extends AiConfig>
    implements $AiConfigCopyWith<$Res> {
  _$AiConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiConfigInferenceProviderImplCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory _$$AiConfigInferenceProviderImplCopyWith(
          _$AiConfigInferenceProviderImpl value,
          $Res Function(_$AiConfigInferenceProviderImpl) then) =
      __$$AiConfigInferenceProviderImplCopyWithImpl<$Res>;
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
class __$$AiConfigInferenceProviderImplCopyWithImpl<$Res>
    extends _$AiConfigCopyWithImpl<$Res, _$AiConfigInferenceProviderImpl>
    implements _$$AiConfigInferenceProviderImplCopyWith<$Res> {
  __$$AiConfigInferenceProviderImplCopyWithImpl(
      _$AiConfigInferenceProviderImpl _value,
      $Res Function(_$AiConfigInferenceProviderImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
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
    return _then(_$AiConfigInferenceProviderImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      inferenceProviderType: null == inferenceProviderType
          ? _value.inferenceProviderType
          : inferenceProviderType // ignore: cast_nullable_to_non_nullable
              as InferenceProviderType,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiConfigInferenceProviderImpl implements AiConfigInferenceProvider {
  const _$AiConfigInferenceProviderImpl(
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

  factory _$AiConfigInferenceProviderImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiConfigInferenceProviderImplFromJson(json);

  @override
  final String id;
  @override
  final String baseUrl;
  @override
  final String apiKey;
  @override
  final String name;
  @override
  final DateTime createdAt;
  @override
  final InferenceProviderType inferenceProviderType;
  @override
  final DateTime? updatedAt;
  @override
  final String? description;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AiConfig.inferenceProvider(id: $id, baseUrl: $baseUrl, apiKey: $apiKey, name: $name, createdAt: $createdAt, inferenceProviderType: $inferenceProviderType, updatedAt: $updatedAt, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiConfigInferenceProviderImpl &&
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

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiConfigInferenceProviderImplCopyWith<_$AiConfigInferenceProviderImpl>
      get copyWith => __$$AiConfigInferenceProviderImplCopyWithImpl<
          _$AiConfigInferenceProviderImpl>(this, _$identity);

  @override
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
            DateTime? updatedAt,
            String? description)
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
            String? category)
        prompt,
  }) {
    return inferenceProvider(id, baseUrl, apiKey, name, createdAt,
        inferenceProviderType, updatedAt, description);
  }

  @override
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
  }) {
    return inferenceProvider?.call(id, baseUrl, apiKey, name, createdAt,
        inferenceProviderType, updatedAt, description);
  }

  @override
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
    required TResult orElse(),
  }) {
    if (inferenceProvider != null) {
      return inferenceProvider(id, baseUrl, apiKey, name, createdAt,
          inferenceProviderType, updatedAt, description);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigInferenceProvider value)
        inferenceProvider,
    required TResult Function(AiConfigModel value) model,
    required TResult Function(AiConfigPrompt value) prompt,
  }) {
    return inferenceProvider(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult? Function(AiConfigModel value)? model,
    TResult? Function(AiConfigPrompt value)? prompt,
  }) {
    return inferenceProvider?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult Function(AiConfigModel value)? model,
    TResult Function(AiConfigPrompt value)? prompt,
    required TResult orElse(),
  }) {
    if (inferenceProvider != null) {
      return inferenceProvider(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AiConfigInferenceProviderImplToJson(
      this,
    );
  }
}

abstract class AiConfigInferenceProvider implements AiConfig {
  const factory AiConfigInferenceProvider(
      {required final String id,
      required final String baseUrl,
      required final String apiKey,
      required final String name,
      required final DateTime createdAt,
      required final InferenceProviderType inferenceProviderType,
      final DateTime? updatedAt,
      final String? description}) = _$AiConfigInferenceProviderImpl;

  factory AiConfigInferenceProvider.fromJson(Map<String, dynamic> json) =
      _$AiConfigInferenceProviderImpl.fromJson;

  @override
  String get id;
  String get baseUrl;
  String get apiKey;
  @override
  String get name;
  @override
  DateTime get createdAt;
  InferenceProviderType get inferenceProviderType;
  @override
  DateTime? get updatedAt;
  @override
  String? get description;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiConfigInferenceProviderImplCopyWith<_$AiConfigInferenceProviderImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AiConfigModelImplCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory _$$AiConfigModelImplCopyWith(
          _$AiConfigModelImpl value, $Res Function(_$AiConfigModelImpl) then) =
      __$$AiConfigModelImplCopyWithImpl<$Res>;
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
      DateTime? updatedAt,
      String? description});
}

/// @nodoc
class __$$AiConfigModelImplCopyWithImpl<$Res>
    extends _$AiConfigCopyWithImpl<$Res, _$AiConfigModelImpl>
    implements _$$AiConfigModelImplCopyWith<$Res> {
  __$$AiConfigModelImplCopyWithImpl(
      _$AiConfigModelImpl _value, $Res Function(_$AiConfigModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? providerModelId = null,
    Object? inferenceProviderId = null,
    Object? createdAt = null,
    Object? inputModalities = null,
    Object? outputModalities = null,
    Object? isReasoningModel = null,
    Object? updatedAt = freezed,
    Object? description = freezed,
  }) {
    return _then(_$AiConfigModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      providerModelId: null == providerModelId
          ? _value.providerModelId
          : providerModelId // ignore: cast_nullable_to_non_nullable
              as String,
      inferenceProviderId: null == inferenceProviderId
          ? _value.inferenceProviderId
          : inferenceProviderId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      inputModalities: null == inputModalities
          ? _value._inputModalities
          : inputModalities // ignore: cast_nullable_to_non_nullable
              as List<Modality>,
      outputModalities: null == outputModalities
          ? _value._outputModalities
          : outputModalities // ignore: cast_nullable_to_non_nullable
              as List<Modality>,
      isReasoningModel: null == isReasoningModel
          ? _value.isReasoningModel
          : isReasoningModel // ignore: cast_nullable_to_non_nullable
              as bool,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiConfigModelImpl implements AiConfigModel {
  const _$AiConfigModelImpl(
      {required this.id,
      required this.name,
      required this.providerModelId,
      required this.inferenceProviderId,
      required this.createdAt,
      required final List<Modality> inputModalities,
      required final List<Modality> outputModalities,
      required this.isReasoningModel,
      this.updatedAt,
      this.description,
      final String? $type})
      : _inputModalities = inputModalities,
        _outputModalities = outputModalities,
        $type = $type ?? 'model';

  factory _$AiConfigModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiConfigModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String providerModelId;
  @override
  final String inferenceProviderId;
  @override
  final DateTime createdAt;
  final List<Modality> _inputModalities;
  @override
  List<Modality> get inputModalities {
    if (_inputModalities is EqualUnmodifiableListView) return _inputModalities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_inputModalities);
  }

  final List<Modality> _outputModalities;
  @override
  List<Modality> get outputModalities {
    if (_outputModalities is EqualUnmodifiableListView)
      return _outputModalities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_outputModalities);
  }

  @override
  final bool isReasoningModel;
  @override
  final DateTime? updatedAt;
  @override
  final String? description;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AiConfig.model(id: $id, name: $name, providerModelId: $providerModelId, inferenceProviderId: $inferenceProviderId, createdAt: $createdAt, inputModalities: $inputModalities, outputModalities: $outputModalities, isReasoningModel: $isReasoningModel, updatedAt: $updatedAt, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiConfigModelImpl &&
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
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.description, description) ||
                other.description == description));
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
      updatedAt,
      description);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiConfigModelImplCopyWith<_$AiConfigModelImpl> get copyWith =>
      __$$AiConfigModelImplCopyWithImpl<_$AiConfigModelImpl>(this, _$identity);

  @override
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
            DateTime? updatedAt,
            String? description)
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
            String? category)
        prompt,
  }) {
    return model(
        id,
        name,
        providerModelId,
        inferenceProviderId,
        createdAt,
        inputModalities,
        outputModalities,
        isReasoningModel,
        updatedAt,
        description);
  }

  @override
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
  }) {
    return model?.call(
        id,
        name,
        providerModelId,
        inferenceProviderId,
        createdAt,
        inputModalities,
        outputModalities,
        isReasoningModel,
        updatedAt,
        description);
  }

  @override
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
    required TResult orElse(),
  }) {
    if (model != null) {
      return model(
          id,
          name,
          providerModelId,
          inferenceProviderId,
          createdAt,
          inputModalities,
          outputModalities,
          isReasoningModel,
          updatedAt,
          description);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigInferenceProvider value)
        inferenceProvider,
    required TResult Function(AiConfigModel value) model,
    required TResult Function(AiConfigPrompt value) prompt,
  }) {
    return model(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult? Function(AiConfigModel value)? model,
    TResult? Function(AiConfigPrompt value)? prompt,
  }) {
    return model?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult Function(AiConfigModel value)? model,
    TResult Function(AiConfigPrompt value)? prompt,
    required TResult orElse(),
  }) {
    if (model != null) {
      return model(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AiConfigModelImplToJson(
      this,
    );
  }
}

abstract class AiConfigModel implements AiConfig {
  const factory AiConfigModel(
      {required final String id,
      required final String name,
      required final String providerModelId,
      required final String inferenceProviderId,
      required final DateTime createdAt,
      required final List<Modality> inputModalities,
      required final List<Modality> outputModalities,
      required final bool isReasoningModel,
      final DateTime? updatedAt,
      final String? description}) = _$AiConfigModelImpl;

  factory AiConfigModel.fromJson(Map<String, dynamic> json) =
      _$AiConfigModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  String get providerModelId;
  String get inferenceProviderId;
  @override
  DateTime get createdAt;
  List<Modality> get inputModalities;
  List<Modality> get outputModalities;
  bool get isReasoningModel;
  @override
  DateTime? get updatedAt;
  @override
  String? get description;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiConfigModelImplCopyWith<_$AiConfigModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AiConfigPromptImplCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory _$$AiConfigPromptImplCopyWith(_$AiConfigPromptImpl value,
          $Res Function(_$AiConfigPromptImpl) then) =
      __$$AiConfigPromptImplCopyWithImpl<$Res>;
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
      String? category});
}

/// @nodoc
class __$$AiConfigPromptImplCopyWithImpl<$Res>
    extends _$AiConfigCopyWithImpl<$Res, _$AiConfigPromptImpl>
    implements _$$AiConfigPromptImplCopyWith<$Res> {
  __$$AiConfigPromptImplCopyWithImpl(
      _$AiConfigPromptImpl _value, $Res Function(_$AiConfigPromptImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
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
  }) {
    return _then(_$AiConfigPromptImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      systemMessage: null == systemMessage
          ? _value.systemMessage
          : systemMessage // ignore: cast_nullable_to_non_nullable
              as String,
      userMessage: null == userMessage
          ? _value.userMessage
          : userMessage // ignore: cast_nullable_to_non_nullable
              as String,
      defaultModelId: null == defaultModelId
          ? _value.defaultModelId
          : defaultModelId // ignore: cast_nullable_to_non_nullable
              as String,
      modelIds: null == modelIds
          ? _value._modelIds
          : modelIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      useReasoning: null == useReasoning
          ? _value.useReasoning
          : useReasoning // ignore: cast_nullable_to_non_nullable
              as bool,
      requiredInputData: null == requiredInputData
          ? _value._requiredInputData
          : requiredInputData // ignore: cast_nullable_to_non_nullable
              as List<InputDataType>,
      aiResponseType: null == aiResponseType
          ? _value.aiResponseType
          : aiResponseType // ignore: cast_nullable_to_non_nullable
              as AiResponseType,
      comment: freezed == comment
          ? _value.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      defaultVariables: freezed == defaultVariables
          ? _value._defaultVariables
          : defaultVariables // ignore: cast_nullable_to_non_nullable
              as Map<String, String>?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiConfigPromptImpl implements AiConfigPrompt {
  const _$AiConfigPromptImpl(
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
      final String? $type})
      : _modelIds = modelIds,
        _requiredInputData = requiredInputData,
        _defaultVariables = defaultVariables,
        $type = $type ?? 'prompt';

  factory _$AiConfigPromptImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiConfigPromptImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String systemMessage;
  @override
  final String userMessage;
  @override
  final String defaultModelId;
  final List<String> _modelIds;
  @override
  List<String> get modelIds {
    if (_modelIds is EqualUnmodifiableListView) return _modelIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_modelIds);
  }

  @override
  final DateTime createdAt;
  @override
  final bool useReasoning;
  final List<InputDataType> _requiredInputData;
  @override
  List<InputDataType> get requiredInputData {
    if (_requiredInputData is EqualUnmodifiableListView)
      return _requiredInputData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requiredInputData);
  }

  @override
  final AiResponseType aiResponseType;
  @override
  final String? comment;
  @override
  final DateTime? updatedAt;
  @override
  final String? description;
  final Map<String, String>? _defaultVariables;
  @override
  Map<String, String>? get defaultVariables {
    final value = _defaultVariables;
    if (value == null) return null;
    if (_defaultVariables is EqualUnmodifiableMapView) return _defaultVariables;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? category;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AiConfig.prompt(id: $id, name: $name, systemMessage: $systemMessage, userMessage: $userMessage, defaultModelId: $defaultModelId, modelIds: $modelIds, createdAt: $createdAt, useReasoning: $useReasoning, requiredInputData: $requiredInputData, aiResponseType: $aiResponseType, comment: $comment, updatedAt: $updatedAt, description: $description, defaultVariables: $defaultVariables, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiConfigPromptImpl &&
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
                other.category == category));
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
      category);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiConfigPromptImplCopyWith<_$AiConfigPromptImpl> get copyWith =>
      __$$AiConfigPromptImplCopyWithImpl<_$AiConfigPromptImpl>(
          this, _$identity);

  @override
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
            DateTime? updatedAt,
            String? description)
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
            String? category)
        prompt,
  }) {
    return prompt(
        id,
        name,
        systemMessage,
        userMessage,
        defaultModelId,
        modelIds,
        createdAt,
        useReasoning,
        requiredInputData,
        aiResponseType,
        comment,
        updatedAt,
        description,
        defaultVariables,
        category);
  }

  @override
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
  }) {
    return prompt?.call(
        id,
        name,
        systemMessage,
        userMessage,
        defaultModelId,
        modelIds,
        createdAt,
        useReasoning,
        requiredInputData,
        aiResponseType,
        comment,
        updatedAt,
        description,
        defaultVariables,
        category);
  }

  @override
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
            DateTime? updatedAt,
            String? description)?
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
            String? category)?
        prompt,
    required TResult orElse(),
  }) {
    if (prompt != null) {
      return prompt(
          id,
          name,
          systemMessage,
          userMessage,
          defaultModelId,
          modelIds,
          createdAt,
          useReasoning,
          requiredInputData,
          aiResponseType,
          comment,
          updatedAt,
          description,
          defaultVariables,
          category);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigInferenceProvider value)
        inferenceProvider,
    required TResult Function(AiConfigModel value) model,
    required TResult Function(AiConfigPrompt value) prompt,
  }) {
    return prompt(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult? Function(AiConfigModel value)? model,
    TResult? Function(AiConfigPrompt value)? prompt,
  }) {
    return prompt?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigInferenceProvider value)? inferenceProvider,
    TResult Function(AiConfigModel value)? model,
    TResult Function(AiConfigPrompt value)? prompt,
    required TResult orElse(),
  }) {
    if (prompt != null) {
      return prompt(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AiConfigPromptImplToJson(
      this,
    );
  }
}

abstract class AiConfigPrompt implements AiConfig {
  const factory AiConfigPrompt(
      {required final String id,
      required final String name,
      required final String systemMessage,
      required final String userMessage,
      required final String defaultModelId,
      required final List<String> modelIds,
      required final DateTime createdAt,
      required final bool useReasoning,
      required final List<InputDataType> requiredInputData,
      required final AiResponseType aiResponseType,
      final String? comment,
      final DateTime? updatedAt,
      final String? description,
      final Map<String, String>? defaultVariables,
      final String? category}) = _$AiConfigPromptImpl;

  factory AiConfigPrompt.fromJson(Map<String, dynamic> json) =
      _$AiConfigPromptImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  String get systemMessage;
  String get userMessage;
  String get defaultModelId;
  List<String> get modelIds;
  @override
  DateTime get createdAt;
  bool get useReasoning;
  List<InputDataType> get requiredInputData;
  AiResponseType get aiResponseType;
  String? get comment;
  @override
  DateTime? get updatedAt;
  @override
  String? get description;
  Map<String, String>? get defaultVariables;
  String? get category;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiConfigPromptImplCopyWith<_$AiConfigPromptImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
