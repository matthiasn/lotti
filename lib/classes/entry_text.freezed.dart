// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_text.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EntryText _$EntryTextFromJson(Map<String, dynamic> json) {
  return _EntryText.fromJson(json);
}

/// @nodoc
mixin _$EntryText {
  String get plainText => throw _privateConstructorUsedError;
  Geolocation? get geolocation => throw _privateConstructorUsedError;
  String? get markdown => throw _privateConstructorUsedError;
  String? get quill => throw _privateConstructorUsedError;

  /// Serializes this EntryText to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EntryTextCopyWith<EntryText> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntryTextCopyWith<$Res> {
  factory $EntryTextCopyWith(EntryText value, $Res Function(EntryText) then) =
      _$EntryTextCopyWithImpl<$Res, EntryText>;
  @useResult
  $Res call(
      {String plainText,
      Geolocation? geolocation,
      String? markdown,
      String? quill});

  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$EntryTextCopyWithImpl<$Res, $Val extends EntryText>
    implements $EntryTextCopyWith<$Res> {
  _$EntryTextCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plainText = null,
    Object? geolocation = freezed,
    Object? markdown = freezed,
    Object? quill = freezed,
  }) {
    return _then(_value.copyWith(
      plainText: null == plainText
          ? _value.plainText
          : plainText // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
      markdown: freezed == markdown
          ? _value.markdown
          : markdown // ignore: cast_nullable_to_non_nullable
              as String?,
      quill: freezed == quill
          ? _value.quill
          : quill // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_value.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_value.geolocation!, (value) {
      return _then(_value.copyWith(geolocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EntryTextImplCopyWith<$Res>
    implements $EntryTextCopyWith<$Res> {
  factory _$$EntryTextImplCopyWith(
          _$EntryTextImpl value, $Res Function(_$EntryTextImpl) then) =
      __$$EntryTextImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String plainText,
      Geolocation? geolocation,
      String? markdown,
      String? quill});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$EntryTextImplCopyWithImpl<$Res>
    extends _$EntryTextCopyWithImpl<$Res, _$EntryTextImpl>
    implements _$$EntryTextImplCopyWith<$Res> {
  __$$EntryTextImplCopyWithImpl(
      _$EntryTextImpl _value, $Res Function(_$EntryTextImpl) _then)
      : super(_value, _then);

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plainText = null,
    Object? geolocation = freezed,
    Object? markdown = freezed,
    Object? quill = freezed,
  }) {
    return _then(_$EntryTextImpl(
      plainText: null == plainText
          ? _value.plainText
          : plainText // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
      markdown: freezed == markdown
          ? _value.markdown
          : markdown // ignore: cast_nullable_to_non_nullable
              as String?,
      quill: freezed == quill
          ? _value.quill
          : quill // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EntryTextImpl implements _EntryText {
  const _$EntryTextImpl(
      {required this.plainText, this.geolocation, this.markdown, this.quill});

  factory _$EntryTextImpl.fromJson(Map<String, dynamic> json) =>
      _$$EntryTextImplFromJson(json);

  @override
  final String plainText;
  @override
  final Geolocation? geolocation;
  @override
  final String? markdown;
  @override
  final String? quill;

  @override
  String toString() {
    return 'EntryText(plainText: $plainText, geolocation: $geolocation, markdown: $markdown, quill: $quill)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntryTextImpl &&
            (identical(other.plainText, plainText) ||
                other.plainText == plainText) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation) &&
            (identical(other.markdown, markdown) ||
                other.markdown == markdown) &&
            (identical(other.quill, quill) || other.quill == quill));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, plainText, geolocation, markdown, quill);

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntryTextImplCopyWith<_$EntryTextImpl> get copyWith =>
      __$$EntryTextImplCopyWithImpl<_$EntryTextImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EntryTextImplToJson(
      this,
    );
  }
}

abstract class _EntryText implements EntryText {
  const factory _EntryText(
      {required final String plainText,
      final Geolocation? geolocation,
      final String? markdown,
      final String? quill}) = _$EntryTextImpl;

  factory _EntryText.fromJson(Map<String, dynamic> json) =
      _$EntryTextImpl.fromJson;

  @override
  String get plainText;
  @override
  Geolocation? get geolocation;
  @override
  String? get markdown;
  @override
  String? get quill;

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntryTextImplCopyWith<_$EntryTextImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
