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
    case 'apiKey':
      return AiConfigApiKey.fromJson(json);
    case 'promptTemplate':
      return AiConfigPromptTemplate.fromJson(json);

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
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String baseUrl,
            String apiKey,
            String name,
            DateTime createdAt,
            DateTime? updatedAt,
            String? comment)
        apiKey,
    required TResult Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)
        promptTemplate,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String baseUrl, String apiKey, String name,
            DateTime createdAt, DateTime? updatedAt, String? comment)?
        apiKey,
    TResult? Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)?
        promptTemplate,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String baseUrl, String apiKey, String name,
            DateTime createdAt, DateTime? updatedAt, String? comment)?
        apiKey,
    TResult Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)?
        promptTemplate,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigApiKey value) apiKey,
    required TResult Function(AiConfigPromptTemplate value) promptTemplate,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigApiKey value)? apiKey,
    TResult? Function(AiConfigPromptTemplate value)? promptTemplate,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigApiKey value)? apiKey,
    TResult Function(AiConfigPromptTemplate value)? promptTemplate,
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
  $Res call({String id, String name, DateTime createdAt, DateTime? updatedAt});
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiConfigApiKeyImplCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory _$$AiConfigApiKeyImplCopyWith(_$AiConfigApiKeyImpl value,
          $Res Function(_$AiConfigApiKeyImpl) then) =
      __$$AiConfigApiKeyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String baseUrl,
      String apiKey,
      String name,
      DateTime createdAt,
      DateTime? updatedAt,
      String? comment});
}

/// @nodoc
class __$$AiConfigApiKeyImplCopyWithImpl<$Res>
    extends _$AiConfigCopyWithImpl<$Res, _$AiConfigApiKeyImpl>
    implements _$$AiConfigApiKeyImplCopyWith<$Res> {
  __$$AiConfigApiKeyImplCopyWithImpl(
      _$AiConfigApiKeyImpl _value, $Res Function(_$AiConfigApiKeyImpl) _then)
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
    Object? updatedAt = freezed,
    Object? comment = freezed,
  }) {
    return _then(_$AiConfigApiKeyImpl(
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
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      comment: freezed == comment
          ? _value.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiConfigApiKeyImpl implements AiConfigApiKey {
  const _$AiConfigApiKeyImpl(
      {required this.id,
      required this.baseUrl,
      required this.apiKey,
      required this.name,
      required this.createdAt,
      this.updatedAt,
      this.comment,
      final String? $type})
      : $type = $type ?? 'apiKey';

  factory _$AiConfigApiKeyImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiConfigApiKeyImplFromJson(json);

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
  final DateTime? updatedAt;
  @override
  final String? comment;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'AiConfig.apiKey(id: $id, baseUrl: $baseUrl, apiKey: $apiKey, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, comment: $comment)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiConfigApiKeyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.comment, comment) || other.comment == comment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, baseUrl, apiKey, name, createdAt, updatedAt, comment);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiConfigApiKeyImplCopyWith<_$AiConfigApiKeyImpl> get copyWith =>
      __$$AiConfigApiKeyImplCopyWithImpl<_$AiConfigApiKeyImpl>(
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
            DateTime? updatedAt,
            String? comment)
        apiKey,
    required TResult Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)
        promptTemplate,
  }) {
    return apiKey(
        id, baseUrl, this.apiKey, name, createdAt, updatedAt, comment);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String baseUrl, String apiKey, String name,
            DateTime createdAt, DateTime? updatedAt, String? comment)?
        apiKey,
    TResult? Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)?
        promptTemplate,
  }) {
    return apiKey?.call(
        id, baseUrl, this.apiKey, name, createdAt, updatedAt, comment);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String baseUrl, String apiKey, String name,
            DateTime createdAt, DateTime? updatedAt, String? comment)?
        apiKey,
    TResult Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)?
        promptTemplate,
    required TResult orElse(),
  }) {
    if (apiKey != null) {
      return apiKey(
          id, baseUrl, this.apiKey, name, createdAt, updatedAt, comment);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigApiKey value) apiKey,
    required TResult Function(AiConfigPromptTemplate value) promptTemplate,
  }) {
    return apiKey(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigApiKey value)? apiKey,
    TResult? Function(AiConfigPromptTemplate value)? promptTemplate,
  }) {
    return apiKey?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigApiKey value)? apiKey,
    TResult Function(AiConfigPromptTemplate value)? promptTemplate,
    required TResult orElse(),
  }) {
    if (apiKey != null) {
      return apiKey(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AiConfigApiKeyImplToJson(
      this,
    );
  }
}

abstract class AiConfigApiKey implements AiConfig {
  const factory AiConfigApiKey(
      {required final String id,
      required final String baseUrl,
      required final String apiKey,
      required final String name,
      required final DateTime createdAt,
      final DateTime? updatedAt,
      final String? comment}) = _$AiConfigApiKeyImpl;

  factory AiConfigApiKey.fromJson(Map<String, dynamic> json) =
      _$AiConfigApiKeyImpl.fromJson;

  @override
  String get id;
  String get baseUrl;
  String get apiKey;
  @override
  String get name;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;
  String? get comment;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiConfigApiKeyImplCopyWith<_$AiConfigApiKeyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AiConfigPromptTemplateImplCopyWith<$Res>
    implements $AiConfigCopyWith<$Res> {
  factory _$$AiConfigPromptTemplateImplCopyWith(
          _$AiConfigPromptTemplateImpl value,
          $Res Function(_$AiConfigPromptTemplateImpl) then) =
      __$$AiConfigPromptTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String template,
      DateTime createdAt,
      DateTime? updatedAt,
      String? description,
      Map<String, String>? defaultVariables,
      String? category});
}

/// @nodoc
class __$$AiConfigPromptTemplateImplCopyWithImpl<$Res>
    extends _$AiConfigCopyWithImpl<$Res, _$AiConfigPromptTemplateImpl>
    implements _$$AiConfigPromptTemplateImplCopyWith<$Res> {
  __$$AiConfigPromptTemplateImplCopyWithImpl(
      _$AiConfigPromptTemplateImpl _value,
      $Res Function(_$AiConfigPromptTemplateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? template = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? description = freezed,
    Object? defaultVariables = freezed,
    Object? category = freezed,
  }) {
    return _then(_$AiConfigPromptTemplateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      template: null == template
          ? _value.template
          : template // ignore: cast_nullable_to_non_nullable
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
class _$AiConfigPromptTemplateImpl implements AiConfigPromptTemplate {
  const _$AiConfigPromptTemplateImpl(
      {required this.id,
      required this.name,
      required this.template,
      required this.createdAt,
      this.updatedAt,
      this.description,
      final Map<String, String>? defaultVariables,
      this.category,
      final String? $type})
      : _defaultVariables = defaultVariables,
        $type = $type ?? 'promptTemplate';

  factory _$AiConfigPromptTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiConfigPromptTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String template;
  @override
  final DateTime createdAt;
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
    return 'AiConfig.promptTemplate(id: $id, name: $name, template: $template, createdAt: $createdAt, updatedAt: $updatedAt, description: $description, defaultVariables: $defaultVariables, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiConfigPromptTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.template, template) ||
                other.template == template) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
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
      template,
      createdAt,
      updatedAt,
      description,
      const DeepCollectionEquality().hash(_defaultVariables),
      category);

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiConfigPromptTemplateImplCopyWith<_$AiConfigPromptTemplateImpl>
      get copyWith => __$$AiConfigPromptTemplateImplCopyWithImpl<
          _$AiConfigPromptTemplateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String baseUrl,
            String apiKey,
            String name,
            DateTime createdAt,
            DateTime? updatedAt,
            String? comment)
        apiKey,
    required TResult Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)
        promptTemplate,
  }) {
    return promptTemplate(id, name, template, createdAt, updatedAt, description,
        defaultVariables, category);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String baseUrl, String apiKey, String name,
            DateTime createdAt, DateTime? updatedAt, String? comment)?
        apiKey,
    TResult? Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)?
        promptTemplate,
  }) {
    return promptTemplate?.call(id, name, template, createdAt, updatedAt,
        description, defaultVariables, category);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String baseUrl, String apiKey, String name,
            DateTime createdAt, DateTime? updatedAt, String? comment)?
        apiKey,
    TResult Function(
            String id,
            String name,
            String template,
            DateTime createdAt,
            DateTime? updatedAt,
            String? description,
            Map<String, String>? defaultVariables,
            String? category)?
        promptTemplate,
    required TResult orElse(),
  }) {
    if (promptTemplate != null) {
      return promptTemplate(id, name, template, createdAt, updatedAt,
          description, defaultVariables, category);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AiConfigApiKey value) apiKey,
    required TResult Function(AiConfigPromptTemplate value) promptTemplate,
  }) {
    return promptTemplate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AiConfigApiKey value)? apiKey,
    TResult? Function(AiConfigPromptTemplate value)? promptTemplate,
  }) {
    return promptTemplate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AiConfigApiKey value)? apiKey,
    TResult Function(AiConfigPromptTemplate value)? promptTemplate,
    required TResult orElse(),
  }) {
    if (promptTemplate != null) {
      return promptTemplate(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$AiConfigPromptTemplateImplToJson(
      this,
    );
  }
}

abstract class AiConfigPromptTemplate implements AiConfig {
  const factory AiConfigPromptTemplate(
      {required final String id,
      required final String name,
      required final String template,
      required final DateTime createdAt,
      final DateTime? updatedAt,
      final String? description,
      final Map<String, String>? defaultVariables,
      final String? category}) = _$AiConfigPromptTemplateImpl;

  factory AiConfigPromptTemplate.fromJson(Map<String, dynamic> json) =
      _$AiConfigPromptTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  String get template;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;
  String? get description;
  Map<String, String>? get defaultVariables;
  String? get category;

  /// Create a copy of AiConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiConfigPromptTemplateImplCopyWith<_$AiConfigPromptTemplateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
