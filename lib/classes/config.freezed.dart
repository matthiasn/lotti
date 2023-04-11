// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

ImapConfig _$ImapConfigFromJson(Map<String, dynamic> json) {
  return _ImapConfig.fromJson(json);
}

/// @nodoc
mixin _$ImapConfig {
  String get host => throw _privateConstructorUsedError;
  String get folder => throw _privateConstructorUsedError;
  String get userName => throw _privateConstructorUsedError;
  String get password => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ImapConfigCopyWith<ImapConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImapConfigCopyWith<$Res> {
  factory $ImapConfigCopyWith(
          ImapConfig value, $Res Function(ImapConfig) then) =
      _$ImapConfigCopyWithImpl<$Res, ImapConfig>;
  @useResult
  $Res call(
      {String host, String folder, String userName, String password, int port});
}

/// @nodoc
class _$ImapConfigCopyWithImpl<$Res, $Val extends ImapConfig>
    implements $ImapConfigCopyWith<$Res> {
  _$ImapConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? folder = null,
    Object? userName = null,
    Object? password = null,
    Object? port = null,
  }) {
    return _then(_value.copyWith(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _value.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
      userName: null == userName
          ? _value.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_ImapConfigCopyWith<$Res>
    implements $ImapConfigCopyWith<$Res> {
  factory _$$_ImapConfigCopyWith(
          _$_ImapConfig value, $Res Function(_$_ImapConfig) then) =
      __$$_ImapConfigCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String host, String folder, String userName, String password, int port});
}

/// @nodoc
class __$$_ImapConfigCopyWithImpl<$Res>
    extends _$ImapConfigCopyWithImpl<$Res, _$_ImapConfig>
    implements _$$_ImapConfigCopyWith<$Res> {
  __$$_ImapConfigCopyWithImpl(
      _$_ImapConfig _value, $Res Function(_$_ImapConfig) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? folder = null,
    Object? userName = null,
    Object? password = null,
    Object? port = null,
  }) {
    return _then(_$_ImapConfig(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _value.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
      userName: null == userName
          ? _value.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_ImapConfig implements _ImapConfig {
  _$_ImapConfig(
      {required this.host,
      required this.folder,
      required this.userName,
      required this.password,
      required this.port});

  factory _$_ImapConfig.fromJson(Map<String, dynamic> json) =>
      _$$_ImapConfigFromJson(json);

  @override
  final String host;
  @override
  final String folder;
  @override
  final String userName;
  @override
  final String password;
  @override
  final int port;

  @override
  String toString() {
    return 'ImapConfig(host: $host, folder: $folder, userName: $userName, password: $password, port: $port)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ImapConfig &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.folder, folder) || other.folder == folder) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.port, port) || other.port == port));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, host, folder, userName, password, port);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ImapConfigCopyWith<_$_ImapConfig> get copyWith =>
      __$$_ImapConfigCopyWithImpl<_$_ImapConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_ImapConfigToJson(
      this,
    );
  }
}

abstract class _ImapConfig implements ImapConfig {
  factory _ImapConfig(
      {required final String host,
      required final String folder,
      required final String userName,
      required final String password,
      required final int port}) = _$_ImapConfig;

  factory _ImapConfig.fromJson(Map<String, dynamic> json) =
      _$_ImapConfig.fromJson;

  @override
  String get host;
  @override
  String get folder;
  @override
  String get userName;
  @override
  String get password;
  @override
  int get port;
  @override
  @JsonKey(ignore: true)
  _$$_ImapConfigCopyWith<_$_ImapConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

SyncConfig _$SyncConfigFromJson(Map<String, dynamic> json) {
  return _SyncConfig.fromJson(json);
}

/// @nodoc
mixin _$SyncConfig {
  ImapConfig get imapConfig => throw _privateConstructorUsedError;
  String get sharedSecret => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SyncConfigCopyWith<SyncConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncConfigCopyWith<$Res> {
  factory $SyncConfigCopyWith(
          SyncConfig value, $Res Function(SyncConfig) then) =
      _$SyncConfigCopyWithImpl<$Res, SyncConfig>;
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class _$SyncConfigCopyWithImpl<$Res, $Val extends SyncConfig>
    implements $SyncConfigCopyWith<$Res> {
  _$SyncConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_value.copyWith(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      sharedSecret: null == sharedSecret
          ? _value.sharedSecret
          : sharedSecret // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_value.imapConfig, (value) {
      return _then(_value.copyWith(imapConfig: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_SyncConfigCopyWith<$Res>
    implements $SyncConfigCopyWith<$Res> {
  factory _$$_SyncConfigCopyWith(
          _$_SyncConfig value, $Res Function(_$_SyncConfig) then) =
      __$$_SyncConfigCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  @override
  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$$_SyncConfigCopyWithImpl<$Res>
    extends _$SyncConfigCopyWithImpl<$Res, _$_SyncConfig>
    implements _$$_SyncConfigCopyWith<$Res> {
  __$$_SyncConfigCopyWithImpl(
      _$_SyncConfig _value, $Res Function(_$_SyncConfig) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_$_SyncConfig(
      imapConfig: null == imapConfig
          ? _value.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      sharedSecret: null == sharedSecret
          ? _value.sharedSecret
          : sharedSecret // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_SyncConfig implements _SyncConfig {
  _$_SyncConfig({required this.imapConfig, required this.sharedSecret});

  factory _$_SyncConfig.fromJson(Map<String, dynamic> json) =>
      _$$_SyncConfigFromJson(json);

  @override
  final ImapConfig imapConfig;
  @override
  final String sharedSecret;

  @override
  String toString() {
    return 'SyncConfig(imapConfig: $imapConfig, sharedSecret: $sharedSecret)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_SyncConfig &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig) &&
            (identical(other.sharedSecret, sharedSecret) ||
                other.sharedSecret == sharedSecret));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, sharedSecret);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SyncConfigCopyWith<_$_SyncConfig> get copyWith =>
      __$$_SyncConfigCopyWithImpl<_$_SyncConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_SyncConfigToJson(
      this,
    );
  }
}

abstract class _SyncConfig implements SyncConfig {
  factory _SyncConfig(
      {required final ImapConfig imapConfig,
      required final String sharedSecret}) = _$_SyncConfig;

  factory _SyncConfig.fromJson(Map<String, dynamic> json) =
      _$_SyncConfig.fromJson;

  @override
  ImapConfig get imapConfig;
  @override
  String get sharedSecret;
  @override
  @JsonKey(ignore: true)
  _$$_SyncConfigCopyWith<_$_SyncConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

StyleConfig _$StyleConfigFromJson(Map<String, dynamic> json) {
  return _StyleConfig.fromJson(json);
}

/// @nodoc
mixin _$StyleConfig {
  @ColorConverter()
  Color get tagColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get tagTextColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get personTagColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get storyTagColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get privateTagColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get starredGold => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get selectedChoiceChipColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get selectedChoiceChipTextColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get unselectedChoiceChipColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get unselectedChoiceChipTextColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get activeAudioControl => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get audioMeterBar => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get audioMeterTooHotBar => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get audioMeterPeakedBar => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get private => throw _privateConstructorUsedError; // new colors
  @ColorConverter()
  Color get negspace => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get primaryTextColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get secondaryTextColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get primaryColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get primaryColorLight => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get hover => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get alarm => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get cardColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get chartTextColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get textEditorBackground => throw _privateConstructorUsedError;
  Brightness get keyboardAppearance => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $StyleConfigCopyWith<StyleConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StyleConfigCopyWith<$Res> {
  factory $StyleConfigCopyWith(
          StyleConfig value, $Res Function(StyleConfig) then) =
      _$StyleConfigCopyWithImpl<$Res, StyleConfig>;
  @useResult
  $Res call(
      {@ColorConverter() Color tagColor,
      @ColorConverter() Color tagTextColor,
      @ColorConverter() Color personTagColor,
      @ColorConverter() Color storyTagColor,
      @ColorConverter() Color privateTagColor,
      @ColorConverter() Color starredGold,
      @ColorConverter() Color selectedChoiceChipColor,
      @ColorConverter() Color selectedChoiceChipTextColor,
      @ColorConverter() Color unselectedChoiceChipColor,
      @ColorConverter() Color unselectedChoiceChipTextColor,
      @ColorConverter() Color activeAudioControl,
      @ColorConverter() Color audioMeterBar,
      @ColorConverter() Color audioMeterTooHotBar,
      @ColorConverter() Color audioMeterPeakedBar,
      @ColorConverter() Color private,
      @ColorConverter() Color negspace,
      @ColorConverter() Color primaryTextColor,
      @ColorConverter() Color secondaryTextColor,
      @ColorConverter() Color primaryColor,
      @ColorConverter() Color primaryColorLight,
      @ColorConverter() Color hover,
      @ColorConverter() Color alarm,
      @ColorConverter() Color cardColor,
      @ColorConverter() Color chartTextColor,
      @ColorConverter() Color textEditorBackground,
      Brightness keyboardAppearance});
}

/// @nodoc
class _$StyleConfigCopyWithImpl<$Res, $Val extends StyleConfig>
    implements $StyleConfigCopyWith<$Res> {
  _$StyleConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagColor = null,
    Object? tagTextColor = null,
    Object? personTagColor = null,
    Object? storyTagColor = null,
    Object? privateTagColor = null,
    Object? starredGold = null,
    Object? selectedChoiceChipColor = null,
    Object? selectedChoiceChipTextColor = null,
    Object? unselectedChoiceChipColor = null,
    Object? unselectedChoiceChipTextColor = null,
    Object? activeAudioControl = null,
    Object? audioMeterBar = null,
    Object? audioMeterTooHotBar = null,
    Object? audioMeterPeakedBar = null,
    Object? private = null,
    Object? negspace = null,
    Object? primaryTextColor = null,
    Object? secondaryTextColor = null,
    Object? primaryColor = null,
    Object? primaryColorLight = null,
    Object? hover = null,
    Object? alarm = null,
    Object? cardColor = null,
    Object? chartTextColor = null,
    Object? textEditorBackground = null,
    Object? keyboardAppearance = null,
  }) {
    return _then(_value.copyWith(
      tagColor: null == tagColor
          ? _value.tagColor
          : tagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      tagTextColor: null == tagTextColor
          ? _value.tagTextColor
          : tagTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      personTagColor: null == personTagColor
          ? _value.personTagColor
          : personTagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      storyTagColor: null == storyTagColor
          ? _value.storyTagColor
          : storyTagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      privateTagColor: null == privateTagColor
          ? _value.privateTagColor
          : privateTagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      starredGold: null == starredGold
          ? _value.starredGold
          : starredGold // ignore: cast_nullable_to_non_nullable
              as Color,
      selectedChoiceChipColor: null == selectedChoiceChipColor
          ? _value.selectedChoiceChipColor
          : selectedChoiceChipColor // ignore: cast_nullable_to_non_nullable
              as Color,
      selectedChoiceChipTextColor: null == selectedChoiceChipTextColor
          ? _value.selectedChoiceChipTextColor
          : selectedChoiceChipTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      unselectedChoiceChipColor: null == unselectedChoiceChipColor
          ? _value.unselectedChoiceChipColor
          : unselectedChoiceChipColor // ignore: cast_nullable_to_non_nullable
              as Color,
      unselectedChoiceChipTextColor: null == unselectedChoiceChipTextColor
          ? _value.unselectedChoiceChipTextColor
          : unselectedChoiceChipTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      activeAudioControl: null == activeAudioControl
          ? _value.activeAudioControl
          : activeAudioControl // ignore: cast_nullable_to_non_nullable
              as Color,
      audioMeterBar: null == audioMeterBar
          ? _value.audioMeterBar
          : audioMeterBar // ignore: cast_nullable_to_non_nullable
              as Color,
      audioMeterTooHotBar: null == audioMeterTooHotBar
          ? _value.audioMeterTooHotBar
          : audioMeterTooHotBar // ignore: cast_nullable_to_non_nullable
              as Color,
      audioMeterPeakedBar: null == audioMeterPeakedBar
          ? _value.audioMeterPeakedBar
          : audioMeterPeakedBar // ignore: cast_nullable_to_non_nullable
              as Color,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as Color,
      negspace: null == negspace
          ? _value.negspace
          : negspace // ignore: cast_nullable_to_non_nullable
              as Color,
      primaryTextColor: null == primaryTextColor
          ? _value.primaryTextColor
          : primaryTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      secondaryTextColor: null == secondaryTextColor
          ? _value.secondaryTextColor
          : secondaryTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      primaryColor: null == primaryColor
          ? _value.primaryColor
          : primaryColor // ignore: cast_nullable_to_non_nullable
              as Color,
      primaryColorLight: null == primaryColorLight
          ? _value.primaryColorLight
          : primaryColorLight // ignore: cast_nullable_to_non_nullable
              as Color,
      hover: null == hover
          ? _value.hover
          : hover // ignore: cast_nullable_to_non_nullable
              as Color,
      alarm: null == alarm
          ? _value.alarm
          : alarm // ignore: cast_nullable_to_non_nullable
              as Color,
      cardColor: null == cardColor
          ? _value.cardColor
          : cardColor // ignore: cast_nullable_to_non_nullable
              as Color,
      chartTextColor: null == chartTextColor
          ? _value.chartTextColor
          : chartTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      textEditorBackground: null == textEditorBackground
          ? _value.textEditorBackground
          : textEditorBackground // ignore: cast_nullable_to_non_nullable
              as Color,
      keyboardAppearance: null == keyboardAppearance
          ? _value.keyboardAppearance
          : keyboardAppearance // ignore: cast_nullable_to_non_nullable
              as Brightness,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_StyleConfigCopyWith<$Res>
    implements $StyleConfigCopyWith<$Res> {
  factory _$$_StyleConfigCopyWith(
          _$_StyleConfig value, $Res Function(_$_StyleConfig) then) =
      __$$_StyleConfigCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@ColorConverter() Color tagColor,
      @ColorConverter() Color tagTextColor,
      @ColorConverter() Color personTagColor,
      @ColorConverter() Color storyTagColor,
      @ColorConverter() Color privateTagColor,
      @ColorConverter() Color starredGold,
      @ColorConverter() Color selectedChoiceChipColor,
      @ColorConverter() Color selectedChoiceChipTextColor,
      @ColorConverter() Color unselectedChoiceChipColor,
      @ColorConverter() Color unselectedChoiceChipTextColor,
      @ColorConverter() Color activeAudioControl,
      @ColorConverter() Color audioMeterBar,
      @ColorConverter() Color audioMeterTooHotBar,
      @ColorConverter() Color audioMeterPeakedBar,
      @ColorConverter() Color private,
      @ColorConverter() Color negspace,
      @ColorConverter() Color primaryTextColor,
      @ColorConverter() Color secondaryTextColor,
      @ColorConverter() Color primaryColor,
      @ColorConverter() Color primaryColorLight,
      @ColorConverter() Color hover,
      @ColorConverter() Color alarm,
      @ColorConverter() Color cardColor,
      @ColorConverter() Color chartTextColor,
      @ColorConverter() Color textEditorBackground,
      Brightness keyboardAppearance});
}

/// @nodoc
class __$$_StyleConfigCopyWithImpl<$Res>
    extends _$StyleConfigCopyWithImpl<$Res, _$_StyleConfig>
    implements _$$_StyleConfigCopyWith<$Res> {
  __$$_StyleConfigCopyWithImpl(
      _$_StyleConfig _value, $Res Function(_$_StyleConfig) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagColor = null,
    Object? tagTextColor = null,
    Object? personTagColor = null,
    Object? storyTagColor = null,
    Object? privateTagColor = null,
    Object? starredGold = null,
    Object? selectedChoiceChipColor = null,
    Object? selectedChoiceChipTextColor = null,
    Object? unselectedChoiceChipColor = null,
    Object? unselectedChoiceChipTextColor = null,
    Object? activeAudioControl = null,
    Object? audioMeterBar = null,
    Object? audioMeterTooHotBar = null,
    Object? audioMeterPeakedBar = null,
    Object? private = null,
    Object? negspace = null,
    Object? primaryTextColor = null,
    Object? secondaryTextColor = null,
    Object? primaryColor = null,
    Object? primaryColorLight = null,
    Object? hover = null,
    Object? alarm = null,
    Object? cardColor = null,
    Object? chartTextColor = null,
    Object? textEditorBackground = null,
    Object? keyboardAppearance = null,
  }) {
    return _then(_$_StyleConfig(
      tagColor: null == tagColor
          ? _value.tagColor
          : tagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      tagTextColor: null == tagTextColor
          ? _value.tagTextColor
          : tagTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      personTagColor: null == personTagColor
          ? _value.personTagColor
          : personTagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      storyTagColor: null == storyTagColor
          ? _value.storyTagColor
          : storyTagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      privateTagColor: null == privateTagColor
          ? _value.privateTagColor
          : privateTagColor // ignore: cast_nullable_to_non_nullable
              as Color,
      starredGold: null == starredGold
          ? _value.starredGold
          : starredGold // ignore: cast_nullable_to_non_nullable
              as Color,
      selectedChoiceChipColor: null == selectedChoiceChipColor
          ? _value.selectedChoiceChipColor
          : selectedChoiceChipColor // ignore: cast_nullable_to_non_nullable
              as Color,
      selectedChoiceChipTextColor: null == selectedChoiceChipTextColor
          ? _value.selectedChoiceChipTextColor
          : selectedChoiceChipTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      unselectedChoiceChipColor: null == unselectedChoiceChipColor
          ? _value.unselectedChoiceChipColor
          : unselectedChoiceChipColor // ignore: cast_nullable_to_non_nullable
              as Color,
      unselectedChoiceChipTextColor: null == unselectedChoiceChipTextColor
          ? _value.unselectedChoiceChipTextColor
          : unselectedChoiceChipTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      activeAudioControl: null == activeAudioControl
          ? _value.activeAudioControl
          : activeAudioControl // ignore: cast_nullable_to_non_nullable
              as Color,
      audioMeterBar: null == audioMeterBar
          ? _value.audioMeterBar
          : audioMeterBar // ignore: cast_nullable_to_non_nullable
              as Color,
      audioMeterTooHotBar: null == audioMeterTooHotBar
          ? _value.audioMeterTooHotBar
          : audioMeterTooHotBar // ignore: cast_nullable_to_non_nullable
              as Color,
      audioMeterPeakedBar: null == audioMeterPeakedBar
          ? _value.audioMeterPeakedBar
          : audioMeterPeakedBar // ignore: cast_nullable_to_non_nullable
              as Color,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as Color,
      negspace: null == negspace
          ? _value.negspace
          : negspace // ignore: cast_nullable_to_non_nullable
              as Color,
      primaryTextColor: null == primaryTextColor
          ? _value.primaryTextColor
          : primaryTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      secondaryTextColor: null == secondaryTextColor
          ? _value.secondaryTextColor
          : secondaryTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      primaryColor: null == primaryColor
          ? _value.primaryColor
          : primaryColor // ignore: cast_nullable_to_non_nullable
              as Color,
      primaryColorLight: null == primaryColorLight
          ? _value.primaryColorLight
          : primaryColorLight // ignore: cast_nullable_to_non_nullable
              as Color,
      hover: null == hover
          ? _value.hover
          : hover // ignore: cast_nullable_to_non_nullable
              as Color,
      alarm: null == alarm
          ? _value.alarm
          : alarm // ignore: cast_nullable_to_non_nullable
              as Color,
      cardColor: null == cardColor
          ? _value.cardColor
          : cardColor // ignore: cast_nullable_to_non_nullable
              as Color,
      chartTextColor: null == chartTextColor
          ? _value.chartTextColor
          : chartTextColor // ignore: cast_nullable_to_non_nullable
              as Color,
      textEditorBackground: null == textEditorBackground
          ? _value.textEditorBackground
          : textEditorBackground // ignore: cast_nullable_to_non_nullable
              as Color,
      keyboardAppearance: null == keyboardAppearance
          ? _value.keyboardAppearance
          : keyboardAppearance // ignore: cast_nullable_to_non_nullable
              as Brightness,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_StyleConfig implements _StyleConfig {
  _$_StyleConfig(
      {@ColorConverter() required this.tagColor,
      @ColorConverter() required this.tagTextColor,
      @ColorConverter() required this.personTagColor,
      @ColorConverter() required this.storyTagColor,
      @ColorConverter() required this.privateTagColor,
      @ColorConverter() required this.starredGold,
      @ColorConverter() required this.selectedChoiceChipColor,
      @ColorConverter() required this.selectedChoiceChipTextColor,
      @ColorConverter() required this.unselectedChoiceChipColor,
      @ColorConverter() required this.unselectedChoiceChipTextColor,
      @ColorConverter() required this.activeAudioControl,
      @ColorConverter() required this.audioMeterBar,
      @ColorConverter() required this.audioMeterTooHotBar,
      @ColorConverter() required this.audioMeterPeakedBar,
      @ColorConverter() required this.private,
      @ColorConverter() required this.negspace,
      @ColorConverter() required this.primaryTextColor,
      @ColorConverter() required this.secondaryTextColor,
      @ColorConverter() required this.primaryColor,
      @ColorConverter() required this.primaryColorLight,
      @ColorConverter() required this.hover,
      @ColorConverter() required this.alarm,
      @ColorConverter() required this.cardColor,
      @ColorConverter() required this.chartTextColor,
      @ColorConverter() required this.textEditorBackground,
      required this.keyboardAppearance});

  factory _$_StyleConfig.fromJson(Map<String, dynamic> json) =>
      _$$_StyleConfigFromJson(json);

  @override
  @ColorConverter()
  final Color tagColor;
  @override
  @ColorConverter()
  final Color tagTextColor;
  @override
  @ColorConverter()
  final Color personTagColor;
  @override
  @ColorConverter()
  final Color storyTagColor;
  @override
  @ColorConverter()
  final Color privateTagColor;
  @override
  @ColorConverter()
  final Color starredGold;
  @override
  @ColorConverter()
  final Color selectedChoiceChipColor;
  @override
  @ColorConverter()
  final Color selectedChoiceChipTextColor;
  @override
  @ColorConverter()
  final Color unselectedChoiceChipColor;
  @override
  @ColorConverter()
  final Color unselectedChoiceChipTextColor;
  @override
  @ColorConverter()
  final Color activeAudioControl;
  @override
  @ColorConverter()
  final Color audioMeterBar;
  @override
  @ColorConverter()
  final Color audioMeterTooHotBar;
  @override
  @ColorConverter()
  final Color audioMeterPeakedBar;
  @override
  @ColorConverter()
  final Color private;
// new colors
  @override
  @ColorConverter()
  final Color negspace;
  @override
  @ColorConverter()
  final Color primaryTextColor;
  @override
  @ColorConverter()
  final Color secondaryTextColor;
  @override
  @ColorConverter()
  final Color primaryColor;
  @override
  @ColorConverter()
  final Color primaryColorLight;
  @override
  @ColorConverter()
  final Color hover;
  @override
  @ColorConverter()
  final Color alarm;
  @override
  @ColorConverter()
  final Color cardColor;
  @override
  @ColorConverter()
  final Color chartTextColor;
  @override
  @ColorConverter()
  final Color textEditorBackground;
  @override
  final Brightness keyboardAppearance;

  @override
  String toString() {
    return 'StyleConfig(tagColor: $tagColor, tagTextColor: $tagTextColor, personTagColor: $personTagColor, storyTagColor: $storyTagColor, privateTagColor: $privateTagColor, starredGold: $starredGold, selectedChoiceChipColor: $selectedChoiceChipColor, selectedChoiceChipTextColor: $selectedChoiceChipTextColor, unselectedChoiceChipColor: $unselectedChoiceChipColor, unselectedChoiceChipTextColor: $unselectedChoiceChipTextColor, activeAudioControl: $activeAudioControl, audioMeterBar: $audioMeterBar, audioMeterTooHotBar: $audioMeterTooHotBar, audioMeterPeakedBar: $audioMeterPeakedBar, private: $private, negspace: $negspace, primaryTextColor: $primaryTextColor, secondaryTextColor: $secondaryTextColor, primaryColor: $primaryColor, primaryColorLight: $primaryColorLight, hover: $hover, alarm: $alarm, cardColor: $cardColor, chartTextColor: $chartTextColor, textEditorBackground: $textEditorBackground, keyboardAppearance: $keyboardAppearance)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_StyleConfig &&
            (identical(other.tagColor, tagColor) ||
                other.tagColor == tagColor) &&
            (identical(other.tagTextColor, tagTextColor) ||
                other.tagTextColor == tagTextColor) &&
            (identical(other.personTagColor, personTagColor) ||
                other.personTagColor == personTagColor) &&
            (identical(other.storyTagColor, storyTagColor) ||
                other.storyTagColor == storyTagColor) &&
            (identical(other.privateTagColor, privateTagColor) ||
                other.privateTagColor == privateTagColor) &&
            (identical(other.starredGold, starredGold) ||
                other.starredGold == starredGold) &&
            (identical(other.selectedChoiceChipColor, selectedChoiceChipColor) ||
                other.selectedChoiceChipColor == selectedChoiceChipColor) &&
            (identical(other.selectedChoiceChipTextColor, selectedChoiceChipTextColor) ||
                other.selectedChoiceChipTextColor ==
                    selectedChoiceChipTextColor) &&
            (identical(other.unselectedChoiceChipColor, unselectedChoiceChipColor) ||
                other.unselectedChoiceChipColor == unselectedChoiceChipColor) &&
            (identical(other.unselectedChoiceChipTextColor, unselectedChoiceChipTextColor) ||
                other.unselectedChoiceChipTextColor ==
                    unselectedChoiceChipTextColor) &&
            (identical(other.activeAudioControl, activeAudioControl) ||
                other.activeAudioControl == activeAudioControl) &&
            (identical(other.audioMeterBar, audioMeterBar) ||
                other.audioMeterBar == audioMeterBar) &&
            (identical(other.audioMeterTooHotBar, audioMeterTooHotBar) ||
                other.audioMeterTooHotBar == audioMeterTooHotBar) &&
            (identical(other.audioMeterPeakedBar, audioMeterPeakedBar) ||
                other.audioMeterPeakedBar == audioMeterPeakedBar) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.negspace, negspace) ||
                other.negspace == negspace) &&
            (identical(other.primaryTextColor, primaryTextColor) ||
                other.primaryTextColor == primaryTextColor) &&
            (identical(other.secondaryTextColor, secondaryTextColor) ||
                other.secondaryTextColor == secondaryTextColor) &&
            (identical(other.primaryColor, primaryColor) ||
                other.primaryColor == primaryColor) &&
            (identical(other.primaryColorLight, primaryColorLight) ||
                other.primaryColorLight == primaryColorLight) &&
            (identical(other.hover, hover) || other.hover == hover) &&
            (identical(other.alarm, alarm) || other.alarm == alarm) &&
            (identical(other.cardColor, cardColor) ||
                other.cardColor == cardColor) &&
            (identical(other.chartTextColor, chartTextColor) ||
                other.chartTextColor == chartTextColor) &&
            (identical(other.textEditorBackground, textEditorBackground) ||
                other.textEditorBackground == textEditorBackground) &&
            (identical(other.keyboardAppearance, keyboardAppearance) ||
                other.keyboardAppearance == keyboardAppearance));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        tagColor,
        tagTextColor,
        personTagColor,
        storyTagColor,
        privateTagColor,
        starredGold,
        selectedChoiceChipColor,
        selectedChoiceChipTextColor,
        unselectedChoiceChipColor,
        unselectedChoiceChipTextColor,
        activeAudioControl,
        audioMeterBar,
        audioMeterTooHotBar,
        audioMeterPeakedBar,
        private,
        negspace,
        primaryTextColor,
        secondaryTextColor,
        primaryColor,
        primaryColorLight,
        hover,
        alarm,
        cardColor,
        chartTextColor,
        textEditorBackground,
        keyboardAppearance
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_StyleConfigCopyWith<_$_StyleConfig> get copyWith =>
      __$$_StyleConfigCopyWithImpl<_$_StyleConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_StyleConfigToJson(
      this,
    );
  }
}

abstract class _StyleConfig implements StyleConfig {
  factory _StyleConfig(
      {@ColorConverter() required final Color tagColor,
      @ColorConverter() required final Color tagTextColor,
      @ColorConverter() required final Color personTagColor,
      @ColorConverter() required final Color storyTagColor,
      @ColorConverter() required final Color privateTagColor,
      @ColorConverter() required final Color starredGold,
      @ColorConverter() required final Color selectedChoiceChipColor,
      @ColorConverter() required final Color selectedChoiceChipTextColor,
      @ColorConverter() required final Color unselectedChoiceChipColor,
      @ColorConverter() required final Color unselectedChoiceChipTextColor,
      @ColorConverter() required final Color activeAudioControl,
      @ColorConverter() required final Color audioMeterBar,
      @ColorConverter() required final Color audioMeterTooHotBar,
      @ColorConverter() required final Color audioMeterPeakedBar,
      @ColorConverter() required final Color private,
      @ColorConverter() required final Color negspace,
      @ColorConverter() required final Color primaryTextColor,
      @ColorConverter() required final Color secondaryTextColor,
      @ColorConverter() required final Color primaryColor,
      @ColorConverter() required final Color primaryColorLight,
      @ColorConverter() required final Color hover,
      @ColorConverter() required final Color alarm,
      @ColorConverter() required final Color cardColor,
      @ColorConverter() required final Color chartTextColor,
      @ColorConverter() required final Color textEditorBackground,
      required final Brightness keyboardAppearance}) = _$_StyleConfig;

  factory _StyleConfig.fromJson(Map<String, dynamic> json) =
      _$_StyleConfig.fromJson;

  @override
  @ColorConverter()
  Color get tagColor;
  @override
  @ColorConverter()
  Color get tagTextColor;
  @override
  @ColorConverter()
  Color get personTagColor;
  @override
  @ColorConverter()
  Color get storyTagColor;
  @override
  @ColorConverter()
  Color get privateTagColor;
  @override
  @ColorConverter()
  Color get starredGold;
  @override
  @ColorConverter()
  Color get selectedChoiceChipColor;
  @override
  @ColorConverter()
  Color get selectedChoiceChipTextColor;
  @override
  @ColorConverter()
  Color get unselectedChoiceChipColor;
  @override
  @ColorConverter()
  Color get unselectedChoiceChipTextColor;
  @override
  @ColorConverter()
  Color get activeAudioControl;
  @override
  @ColorConverter()
  Color get audioMeterBar;
  @override
  @ColorConverter()
  Color get audioMeterTooHotBar;
  @override
  @ColorConverter()
  Color get audioMeterPeakedBar;
  @override
  @ColorConverter()
  Color get private;
  @override // new colors
  @ColorConverter()
  Color get negspace;
  @override
  @ColorConverter()
  Color get primaryTextColor;
  @override
  @ColorConverter()
  Color get secondaryTextColor;
  @override
  @ColorConverter()
  Color get primaryColor;
  @override
  @ColorConverter()
  Color get primaryColorLight;
  @override
  @ColorConverter()
  Color get hover;
  @override
  @ColorConverter()
  Color get alarm;
  @override
  @ColorConverter()
  Color get cardColor;
  @override
  @ColorConverter()
  Color get chartTextColor;
  @override
  @ColorConverter()
  Color get textEditorBackground;
  @override
  Brightness get keyboardAppearance;
  @override
  @JsonKey(ignore: true)
  _$$_StyleConfigCopyWith<_$_StyleConfig> get copyWith =>
      throw _privateConstructorUsedError;
}
