// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cloud_inference_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CloudInferenceConfig _$CloudInferenceConfigFromJson(Map<String, dynamic> json) {
  return _CloudInferenceConfig.fromJson(json);
}

/// @nodoc
mixin _$CloudInferenceConfig {
  String get baseUrl => throw _privateConstructorUsedError;
  String get apiKey => throw _privateConstructorUsedError;
  String get geminiApiKey => throw _privateConstructorUsedError;

  /// Serializes this CloudInferenceConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CloudInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CloudInferenceConfigCopyWith<CloudInferenceConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CloudInferenceConfigCopyWith<$Res> {
  factory $CloudInferenceConfigCopyWith(CloudInferenceConfig value,
          $Res Function(CloudInferenceConfig) then) =
      _$CloudInferenceConfigCopyWithImpl<$Res, CloudInferenceConfig>;
  @useResult
  $Res call({String baseUrl, String apiKey, String geminiApiKey});
}

/// @nodoc
class _$CloudInferenceConfigCopyWithImpl<$Res,
        $Val extends CloudInferenceConfig>
    implements $CloudInferenceConfigCopyWith<$Res> {
  _$CloudInferenceConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CloudInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? geminiApiKey = null,
  }) {
    return _then(_value.copyWith(
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      geminiApiKey: null == geminiApiKey
          ? _value.geminiApiKey
          : geminiApiKey // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CloudInferenceConfigImplCopyWith<$Res>
    implements $CloudInferenceConfigCopyWith<$Res> {
  factory _$$CloudInferenceConfigImplCopyWith(_$CloudInferenceConfigImpl value,
          $Res Function(_$CloudInferenceConfigImpl) then) =
      __$$CloudInferenceConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String baseUrl, String apiKey, String geminiApiKey});
}

/// @nodoc
class __$$CloudInferenceConfigImplCopyWithImpl<$Res>
    extends _$CloudInferenceConfigCopyWithImpl<$Res, _$CloudInferenceConfigImpl>
    implements _$$CloudInferenceConfigImplCopyWith<$Res> {
  __$$CloudInferenceConfigImplCopyWithImpl(_$CloudInferenceConfigImpl _value,
      $Res Function(_$CloudInferenceConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of CloudInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseUrl = null,
    Object? apiKey = null,
    Object? geminiApiKey = null,
  }) {
    return _then(_$CloudInferenceConfigImpl(
      baseUrl: null == baseUrl
          ? _value.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _value.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      geminiApiKey: null == geminiApiKey
          ? _value.geminiApiKey
          : geminiApiKey // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CloudInferenceConfigImpl implements _CloudInferenceConfig {
  const _$CloudInferenceConfigImpl(
      {required this.baseUrl,
      required this.apiKey,
      required this.geminiApiKey});

  factory _$CloudInferenceConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$CloudInferenceConfigImplFromJson(json);

  @override
  final String baseUrl;
  @override
  final String apiKey;
  @override
  final String geminiApiKey;

  @override
  String toString() {
    return 'CloudInferenceConfig(baseUrl: $baseUrl, apiKey: $apiKey, geminiApiKey: $geminiApiKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CloudInferenceConfigImpl &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.geminiApiKey, geminiApiKey) ||
                other.geminiApiKey == geminiApiKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, baseUrl, apiKey, geminiApiKey);

  /// Create a copy of CloudInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CloudInferenceConfigImplCopyWith<_$CloudInferenceConfigImpl>
      get copyWith =>
          __$$CloudInferenceConfigImplCopyWithImpl<_$CloudInferenceConfigImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CloudInferenceConfigImplToJson(
      this,
    );
  }
}

abstract class _CloudInferenceConfig implements CloudInferenceConfig {
  const factory _CloudInferenceConfig(
      {required final String baseUrl,
      required final String apiKey,
      required final String geminiApiKey}) = _$CloudInferenceConfigImpl;

  factory _CloudInferenceConfig.fromJson(Map<String, dynamic> json) =
      _$CloudInferenceConfigImpl.fromJson;

  @override
  String get baseUrl;
  @override
  String get apiKey;
  @override
  String get geminiApiKey;

  /// Create a copy of CloudInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CloudInferenceConfigImplCopyWith<_$CloudInferenceConfigImpl>
      get copyWith => throw _privateConstructorUsedError;
}
