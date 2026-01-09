// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'whats_new_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WhatsNewContent {
  /// The release metadata.
  WhatsNewRelease get release;

  /// The header section (title, date) before the first divider.
  String get headerMarkdown;

  /// Content sections split by horizontal dividers.
  /// Each section becomes a swipable page in the modal.
  List<String> get sections;

  /// URL to the banner image, if available.
  String? get bannerImageUrl;

  /// Create a copy of WhatsNewContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WhatsNewContentCopyWith<WhatsNewContent> get copyWith =>
      _$WhatsNewContentCopyWithImpl<WhatsNewContent>(
          this as WhatsNewContent, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WhatsNewContent &&
            (identical(other.release, release) || other.release == release) &&
            (identical(other.headerMarkdown, headerMarkdown) ||
                other.headerMarkdown == headerMarkdown) &&
            const DeepCollectionEquality().equals(other.sections, sections) &&
            (identical(other.bannerImageUrl, bannerImageUrl) ||
                other.bannerImageUrl == bannerImageUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, release, headerMarkdown,
      const DeepCollectionEquality().hash(sections), bannerImageUrl);

  @override
  String toString() {
    return 'WhatsNewContent(release: $release, headerMarkdown: $headerMarkdown, sections: $sections, bannerImageUrl: $bannerImageUrl)';
  }
}

/// @nodoc
abstract mixin class $WhatsNewContentCopyWith<$Res> {
  factory $WhatsNewContentCopyWith(
          WhatsNewContent value, $Res Function(WhatsNewContent) _then) =
      _$WhatsNewContentCopyWithImpl;
  @useResult
  $Res call(
      {WhatsNewRelease release,
      String headerMarkdown,
      List<String> sections,
      String? bannerImageUrl});

  $WhatsNewReleaseCopyWith<$Res> get release;
}

/// @nodoc
class _$WhatsNewContentCopyWithImpl<$Res>
    implements $WhatsNewContentCopyWith<$Res> {
  _$WhatsNewContentCopyWithImpl(this._self, this._then);

  final WhatsNewContent _self;
  final $Res Function(WhatsNewContent) _then;

  /// Create a copy of WhatsNewContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? release = null,
    Object? headerMarkdown = null,
    Object? sections = null,
    Object? bannerImageUrl = freezed,
  }) {
    return _then(_self.copyWith(
      release: null == release
          ? _self.release
          : release // ignore: cast_nullable_to_non_nullable
              as WhatsNewRelease,
      headerMarkdown: null == headerMarkdown
          ? _self.headerMarkdown
          : headerMarkdown // ignore: cast_nullable_to_non_nullable
              as String,
      sections: null == sections
          ? _self.sections
          : sections // ignore: cast_nullable_to_non_nullable
              as List<String>,
      bannerImageUrl: freezed == bannerImageUrl
          ? _self.bannerImageUrl
          : bannerImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of WhatsNewContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WhatsNewReleaseCopyWith<$Res> get release {
    return $WhatsNewReleaseCopyWith<$Res>(_self.release, (value) {
      return _then(_self.copyWith(release: value));
    });
  }
}

/// Adds pattern-matching-related methods to [WhatsNewContent].
extension WhatsNewContentPatterns on WhatsNewContent {
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
    TResult Function(_WhatsNewContent value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WhatsNewContent() when $default != null:
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
    TResult Function(_WhatsNewContent value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewContent():
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
    TResult? Function(_WhatsNewContent value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewContent() when $default != null:
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
    TResult Function(WhatsNewRelease release, String headerMarkdown,
            List<String> sections, String? bannerImageUrl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WhatsNewContent() when $default != null:
        return $default(_that.release, _that.headerMarkdown, _that.sections,
            _that.bannerImageUrl);
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
    TResult Function(WhatsNewRelease release, String headerMarkdown,
            List<String> sections, String? bannerImageUrl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewContent():
        return $default(_that.release, _that.headerMarkdown, _that.sections,
            _that.bannerImageUrl);
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
    TResult? Function(WhatsNewRelease release, String headerMarkdown,
            List<String> sections, String? bannerImageUrl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewContent() when $default != null:
        return $default(_that.release, _that.headerMarkdown, _that.sections,
            _that.bannerImageUrl);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WhatsNewContent implements WhatsNewContent {
  const _WhatsNewContent(
      {required this.release,
      required this.headerMarkdown,
      required final List<String> sections,
      this.bannerImageUrl})
      : _sections = sections;

  /// The release metadata.
  @override
  final WhatsNewRelease release;

  /// The header section (title, date) before the first divider.
  @override
  final String headerMarkdown;

  /// Content sections split by horizontal dividers.
  /// Each section becomes a swipable page in the modal.
  final List<String> _sections;

  /// Content sections split by horizontal dividers.
  /// Each section becomes a swipable page in the modal.
  @override
  List<String> get sections {
    if (_sections is EqualUnmodifiableListView) return _sections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sections);
  }

  /// URL to the banner image, if available.
  @override
  final String? bannerImageUrl;

  /// Create a copy of WhatsNewContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WhatsNewContentCopyWith<_WhatsNewContent> get copyWith =>
      __$WhatsNewContentCopyWithImpl<_WhatsNewContent>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WhatsNewContent &&
            (identical(other.release, release) || other.release == release) &&
            (identical(other.headerMarkdown, headerMarkdown) ||
                other.headerMarkdown == headerMarkdown) &&
            const DeepCollectionEquality().equals(other._sections, _sections) &&
            (identical(other.bannerImageUrl, bannerImageUrl) ||
                other.bannerImageUrl == bannerImageUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, release, headerMarkdown,
      const DeepCollectionEquality().hash(_sections), bannerImageUrl);

  @override
  String toString() {
    return 'WhatsNewContent(release: $release, headerMarkdown: $headerMarkdown, sections: $sections, bannerImageUrl: $bannerImageUrl)';
  }
}

/// @nodoc
abstract mixin class _$WhatsNewContentCopyWith<$Res>
    implements $WhatsNewContentCopyWith<$Res> {
  factory _$WhatsNewContentCopyWith(
          _WhatsNewContent value, $Res Function(_WhatsNewContent) _then) =
      __$WhatsNewContentCopyWithImpl;
  @override
  @useResult
  $Res call(
      {WhatsNewRelease release,
      String headerMarkdown,
      List<String> sections,
      String? bannerImageUrl});

  @override
  $WhatsNewReleaseCopyWith<$Res> get release;
}

/// @nodoc
class __$WhatsNewContentCopyWithImpl<$Res>
    implements _$WhatsNewContentCopyWith<$Res> {
  __$WhatsNewContentCopyWithImpl(this._self, this._then);

  final _WhatsNewContent _self;
  final $Res Function(_WhatsNewContent) _then;

  /// Create a copy of WhatsNewContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? release = null,
    Object? headerMarkdown = null,
    Object? sections = null,
    Object? bannerImageUrl = freezed,
  }) {
    return _then(_WhatsNewContent(
      release: null == release
          ? _self.release
          : release // ignore: cast_nullable_to_non_nullable
              as WhatsNewRelease,
      headerMarkdown: null == headerMarkdown
          ? _self.headerMarkdown
          : headerMarkdown // ignore: cast_nullable_to_non_nullable
              as String,
      sections: null == sections
          ? _self._sections
          : sections // ignore: cast_nullable_to_non_nullable
              as List<String>,
      bannerImageUrl: freezed == bannerImageUrl
          ? _self.bannerImageUrl
          : bannerImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of WhatsNewContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WhatsNewReleaseCopyWith<$Res> get release {
    return $WhatsNewReleaseCopyWith<$Res>(_self.release, (value) {
      return _then(_self.copyWith(release: value));
    });
  }
}

// dart format on
