// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'speech_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$SpeechSettingsState {
  Set<String> get availableModels => throw _privateConstructorUsedError;
  Set<String> get downloadedModels => throw _privateConstructorUsedError;
  String? get selectedModel => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SpeechSettingsStateCopyWith<SpeechSettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpeechSettingsStateCopyWith<$Res> {
  factory $SpeechSettingsStateCopyWith(
          SpeechSettingsState value, $Res Function(SpeechSettingsState) then) =
      _$SpeechSettingsStateCopyWithImpl<$Res, SpeechSettingsState>;
  @useResult
  $Res call(
      {Set<String> availableModels,
      Set<String> downloadedModels,
      String? selectedModel});
}

/// @nodoc
class _$SpeechSettingsStateCopyWithImpl<$Res, $Val extends SpeechSettingsState>
    implements $SpeechSettingsStateCopyWith<$Res> {
  _$SpeechSettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? availableModels = null,
    Object? downloadedModels = null,
    Object? selectedModel = freezed,
  }) {
    return _then(_value.copyWith(
      availableModels: null == availableModels
          ? _value.availableModels
          : availableModels // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      downloadedModels: null == downloadedModels
          ? _value.downloadedModels
          : downloadedModels // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedModel: freezed == selectedModel
          ? _value.selectedModel
          : selectedModel // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_SpeechSettingsStateCopyWith<$Res>
    implements $SpeechSettingsStateCopyWith<$Res> {
  factory _$$_SpeechSettingsStateCopyWith(_$_SpeechSettingsState value,
          $Res Function(_$_SpeechSettingsState) then) =
      __$$_SpeechSettingsStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Set<String> availableModels,
      Set<String> downloadedModels,
      String? selectedModel});
}

/// @nodoc
class __$$_SpeechSettingsStateCopyWithImpl<$Res>
    extends _$SpeechSettingsStateCopyWithImpl<$Res, _$_SpeechSettingsState>
    implements _$$_SpeechSettingsStateCopyWith<$Res> {
  __$$_SpeechSettingsStateCopyWithImpl(_$_SpeechSettingsState _value,
      $Res Function(_$_SpeechSettingsState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? availableModels = null,
    Object? downloadedModels = null,
    Object? selectedModel = freezed,
  }) {
    return _then(_$_SpeechSettingsState(
      availableModels: null == availableModels
          ? _value._availableModels
          : availableModels // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      downloadedModels: null == downloadedModels
          ? _value._downloadedModels
          : downloadedModels // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedModel: freezed == selectedModel
          ? _value.selectedModel
          : selectedModel // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$_SpeechSettingsState implements _SpeechSettingsState {
  _$_SpeechSettingsState(
      {required final Set<String> availableModels,
      required final Set<String> downloadedModels,
      this.selectedModel})
      : _availableModels = availableModels,
        _downloadedModels = downloadedModels;

  final Set<String> _availableModels;
  @override
  Set<String> get availableModels {
    if (_availableModels is EqualUnmodifiableSetView) return _availableModels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_availableModels);
  }

  final Set<String> _downloadedModels;
  @override
  Set<String> get downloadedModels {
    if (_downloadedModels is EqualUnmodifiableSetView) return _downloadedModels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_downloadedModels);
  }

  @override
  final String? selectedModel;

  @override
  String toString() {
    return 'SpeechSettingsState(availableModels: $availableModels, downloadedModels: $downloadedModels, selectedModel: $selectedModel)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_SpeechSettingsState &&
            const DeepCollectionEquality()
                .equals(other._availableModels, _availableModels) &&
            const DeepCollectionEquality()
                .equals(other._downloadedModels, _downloadedModels) &&
            (identical(other.selectedModel, selectedModel) ||
                other.selectedModel == selectedModel));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_availableModels),
      const DeepCollectionEquality().hash(_downloadedModels),
      selectedModel);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SpeechSettingsStateCopyWith<_$_SpeechSettingsState> get copyWith =>
      __$$_SpeechSettingsStateCopyWithImpl<_$_SpeechSettingsState>(
          this, _$identity);
}

abstract class _SpeechSettingsState implements SpeechSettingsState {
  factory _SpeechSettingsState(
      {required final Set<String> availableModels,
      required final Set<String> downloadedModels,
      final String? selectedModel}) = _$_SpeechSettingsState;

  @override
  Set<String> get availableModels;
  @override
  Set<String> get downloadedModels;
  @override
  String? get selectedModel;
  @override
  @JsonKey(ignore: true)
  _$$_SpeechSettingsStateCopyWith<_$_SpeechSettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}
