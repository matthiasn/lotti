// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_text.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EntryText {
  String get plainText;
  Geolocation? get geolocation;
  String? get markdown;
  String? get quill;

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EntryTextCopyWith<EntryText> get copyWith =>
      _$EntryTextCopyWithImpl<EntryText>(this as EntryText, _$identity);

  /// Serializes this EntryText to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EntryText &&
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

  @override
  String toString() {
    return 'EntryText(plainText: $plainText, geolocation: $geolocation, markdown: $markdown, quill: $quill)';
  }
}

/// @nodoc
abstract mixin class $EntryTextCopyWith<$Res> {
  factory $EntryTextCopyWith(EntryText value, $Res Function(EntryText) _then) =
      _$EntryTextCopyWithImpl;
  @useResult
  $Res call(
      {String plainText,
      Geolocation? geolocation,
      String? markdown,
      String? quill});

  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$EntryTextCopyWithImpl<$Res> implements $EntryTextCopyWith<$Res> {
  _$EntryTextCopyWithImpl(this._self, this._then);

  final EntryText _self;
  final $Res Function(EntryText) _then;

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
    return _then(_self.copyWith(
      plainText: null == plainText
          ? _self.plainText
          : plainText // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
      markdown: freezed == markdown
          ? _self.markdown
          : markdown // ignore: cast_nullable_to_non_nullable
              as String?,
      quill: freezed == quill
          ? _self.quill
          : quill // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// Adds pattern-matching-related methods to [EntryText].
extension EntryTextPatterns on EntryText {
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_EntryText value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EntryText() when $default != null:
        return $default(_that);
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
  TResult map<TResult extends Object?>(
    TResult Function(_EntryText value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EntryText():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_EntryText value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EntryText() when $default != null:
        return $default(_that);
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
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String plainText, Geolocation? geolocation,
            String? markdown, String? quill)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EntryText() when $default != null:
        return $default(
            _that.plainText, _that.geolocation, _that.markdown, _that.quill);
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
  TResult when<TResult extends Object?>(
    TResult Function(String plainText, Geolocation? geolocation,
            String? markdown, String? quill)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EntryText():
        return $default(
            _that.plainText, _that.geolocation, _that.markdown, _that.quill);
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String plainText, Geolocation? geolocation,
            String? markdown, String? quill)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EntryText() when $default != null:
        return $default(
            _that.plainText, _that.geolocation, _that.markdown, _that.quill);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _EntryText implements EntryText {
  const _EntryText(
      {required this.plainText, this.geolocation, this.markdown, this.quill});
  factory _EntryText.fromJson(Map<String, dynamic> json) =>
      _$EntryTextFromJson(json);

  @override
  final String plainText;
  @override
  final Geolocation? geolocation;
  @override
  final String? markdown;
  @override
  final String? quill;

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EntryTextCopyWith<_EntryText> get copyWith =>
      __$EntryTextCopyWithImpl<_EntryText>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$EntryTextToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EntryText &&
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

  @override
  String toString() {
    return 'EntryText(plainText: $plainText, geolocation: $geolocation, markdown: $markdown, quill: $quill)';
  }
}

/// @nodoc
abstract mixin class _$EntryTextCopyWith<$Res>
    implements $EntryTextCopyWith<$Res> {
  factory _$EntryTextCopyWith(
          _EntryText value, $Res Function(_EntryText) _then) =
      __$EntryTextCopyWithImpl;
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
class __$EntryTextCopyWithImpl<$Res> implements _$EntryTextCopyWith<$Res> {
  __$EntryTextCopyWithImpl(this._self, this._then);

  final _EntryText _self;
  final $Res Function(_EntryText) _then;

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? plainText = null,
    Object? geolocation = freezed,
    Object? markdown = freezed,
    Object? quill = freezed,
  }) {
    return _then(_EntryText(
      plainText: null == plainText
          ? _self.plainText
          : plainText // ignore: cast_nullable_to_non_nullable
              as String,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
      markdown: freezed == markdown
          ? _self.markdown
          : markdown // ignore: cast_nullable_to_non_nullable
              as String?,
      quill: freezed == quill
          ? _self.quill
          : quill // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of EntryText
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

// dart format on
