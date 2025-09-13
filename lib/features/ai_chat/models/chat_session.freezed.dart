// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatSession {
  String get id;
  String get title;
  DateTime get createdAt;
  DateTime get lastMessageAt;
  List<ChatMessage> get messages;
  String? get categoryId;
  Map<String, dynamic>? get metadata;

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatSessionCopyWith<ChatSession> get copyWith =>
      _$ChatSessionCopyWithImpl<ChatSession>(this as ChatSession, _$identity);

  /// Serializes this ChatSession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChatSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            const DeepCollectionEquality().equals(other.messages, messages) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            const DeepCollectionEquality().equals(other.metadata, metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      createdAt,
      lastMessageAt,
      const DeepCollectionEquality().hash(messages),
      categoryId,
      const DeepCollectionEquality().hash(metadata));

  @override
  String toString() {
    return 'ChatSession(id: $id, title: $title, createdAt: $createdAt, lastMessageAt: $lastMessageAt, messages: $messages, categoryId: $categoryId, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class $ChatSessionCopyWith<$Res> {
  factory $ChatSessionCopyWith(
          ChatSession value, $Res Function(ChatSession) _then) =
      _$ChatSessionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      DateTime createdAt,
      DateTime lastMessageAt,
      List<ChatMessage> messages,
      String? categoryId,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$ChatSessionCopyWithImpl<$Res> implements $ChatSessionCopyWith<$Res> {
  _$ChatSessionCopyWithImpl(this._self, this._then);

  final ChatSession _self;
  final $Res Function(ChatSession) _then;

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? createdAt = null,
    Object? lastMessageAt = null,
    Object? messages = null,
    Object? categoryId = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastMessageAt: null == lastMessageAt
          ? _self.lastMessageAt
          : lastMessageAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      messages: null == messages
          ? _self.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChatSession].
extension ChatSessionPatterns on ChatSession {
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
    TResult Function(_ChatSession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatSession() when $default != null:
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
    TResult Function(_ChatSession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatSession():
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
    TResult? Function(_ChatSession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatSession() when $default != null:
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
    TResult Function(
            String id,
            String title,
            DateTime createdAt,
            DateTime lastMessageAt,
            List<ChatMessage> messages,
            String? categoryId,
            Map<String, dynamic>? metadata)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatSession() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.createdAt,
            _that.lastMessageAt,
            _that.messages,
            _that.categoryId,
            _that.metadata);
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
    TResult Function(
            String id,
            String title,
            DateTime createdAt,
            DateTime lastMessageAt,
            List<ChatMessage> messages,
            String? categoryId,
            Map<String, dynamic>? metadata)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatSession():
        return $default(
            _that.id,
            _that.title,
            _that.createdAt,
            _that.lastMessageAt,
            _that.messages,
            _that.categoryId,
            _that.metadata);
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
    TResult? Function(
            String id,
            String title,
            DateTime createdAt,
            DateTime lastMessageAt,
            List<ChatMessage> messages,
            String? categoryId,
            Map<String, dynamic>? metadata)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatSession() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.createdAt,
            _that.lastMessageAt,
            _that.messages,
            _that.categoryId,
            _that.metadata);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ChatSession implements ChatSession {
  const _ChatSession(
      {required this.id,
      required this.title,
      required this.createdAt,
      required this.lastMessageAt,
      required final List<ChatMessage> messages,
      this.categoryId,
      final Map<String, dynamic>? metadata})
      : _messages = messages,
        _metadata = metadata;
  factory _ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final DateTime createdAt;
  @override
  final DateTime lastMessageAt;
  final List<ChatMessage> _messages;
  @override
  List<ChatMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  final String? categoryId;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatSessionCopyWith<_ChatSession> get copyWith =>
      __$ChatSessionCopyWithImpl<_ChatSession>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChatSessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChatSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      createdAt,
      lastMessageAt,
      const DeepCollectionEquality().hash(_messages),
      categoryId,
      const DeepCollectionEquality().hash(_metadata));

  @override
  String toString() {
    return 'ChatSession(id: $id, title: $title, createdAt: $createdAt, lastMessageAt: $lastMessageAt, messages: $messages, categoryId: $categoryId, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class _$ChatSessionCopyWith<$Res>
    implements $ChatSessionCopyWith<$Res> {
  factory _$ChatSessionCopyWith(
          _ChatSession value, $Res Function(_ChatSession) _then) =
      __$ChatSessionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      DateTime createdAt,
      DateTime lastMessageAt,
      List<ChatMessage> messages,
      String? categoryId,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$ChatSessionCopyWithImpl<$Res> implements _$ChatSessionCopyWith<$Res> {
  __$ChatSessionCopyWithImpl(this._self, this._then);

  final _ChatSession _self;
  final $Res Function(_ChatSession) _then;

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? createdAt = null,
    Object? lastMessageAt = null,
    Object? messages = null,
    Object? categoryId = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_ChatSession(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastMessageAt: null == lastMessageAt
          ? _self.lastMessageAt
          : lastMessageAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      messages: null == messages
          ? _self._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _self._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

// dart format on
