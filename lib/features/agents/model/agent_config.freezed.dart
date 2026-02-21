// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentConfig {
  /// Maximum number of tool-call turns per wake.
  int get maxTurnsPerWake;

  /// Model identifier to use for inference.
  String get modelId;

  /// Create a copy of AgentConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentConfigCopyWith<AgentConfig> get copyWith =>
      _$AgentConfigCopyWithImpl<AgentConfig>(this as AgentConfig, _$identity);

  /// Serializes this AgentConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentConfig &&
            (identical(other.maxTurnsPerWake, maxTurnsPerWake) ||
                other.maxTurnsPerWake == maxTurnsPerWake) &&
            (identical(other.modelId, modelId) || other.modelId == modelId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, maxTurnsPerWake, modelId);

  @override
  String toString() {
    return 'AgentConfig(maxTurnsPerWake: $maxTurnsPerWake, modelId: $modelId)';
  }
}

/// @nodoc
abstract mixin class $AgentConfigCopyWith<$Res> {
  factory $AgentConfigCopyWith(
          AgentConfig value, $Res Function(AgentConfig) _then) =
      _$AgentConfigCopyWithImpl;
  @useResult
  $Res call({int maxTurnsPerWake, String modelId});
}

/// @nodoc
class _$AgentConfigCopyWithImpl<$Res> implements $AgentConfigCopyWith<$Res> {
  _$AgentConfigCopyWithImpl(this._self, this._then);

  final AgentConfig _self;
  final $Res Function(AgentConfig) _then;

  /// Create a copy of AgentConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxTurnsPerWake = null,
    Object? modelId = null,
  }) {
    return _then(_self.copyWith(
      maxTurnsPerWake: null == maxTurnsPerWake
          ? _self.maxTurnsPerWake
          : maxTurnsPerWake // ignore: cast_nullable_to_non_nullable
              as int,
      modelId: null == modelId
          ? _self.modelId
          : modelId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentConfig].
extension AgentConfigPatterns on AgentConfig {
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
    TResult Function(_AgentConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentConfig() when $default != null:
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
    TResult Function(_AgentConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfig():
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
    TResult? Function(_AgentConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfig() when $default != null:
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
    TResult Function(int maxTurnsPerWake, String modelId)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentConfig() when $default != null:
        return $default(_that.maxTurnsPerWake, _that.modelId);
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
    TResult Function(int maxTurnsPerWake, String modelId) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfig():
        return $default(_that.maxTurnsPerWake, _that.modelId);
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
    TResult? Function(int maxTurnsPerWake, String modelId)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfig() when $default != null:
        return $default(_that.maxTurnsPerWake, _that.modelId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AgentConfig implements AgentConfig {
  const _AgentConfig(
      {this.maxTurnsPerWake = 5,
      this.modelId = 'models/gemini-3.1-pro-preview'});
  factory _AgentConfig.fromJson(Map<String, dynamic> json) =>
      _$AgentConfigFromJson(json);

  /// Maximum number of tool-call turns per wake.
  @override
  @JsonKey()
  final int maxTurnsPerWake;

  /// Model identifier to use for inference.
  @override
  @JsonKey()
  final String modelId;

  /// Create a copy of AgentConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AgentConfigCopyWith<_AgentConfig> get copyWith =>
      __$AgentConfigCopyWithImpl<_AgentConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AgentConfig &&
            (identical(other.maxTurnsPerWake, maxTurnsPerWake) ||
                other.maxTurnsPerWake == maxTurnsPerWake) &&
            (identical(other.modelId, modelId) || other.modelId == modelId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, maxTurnsPerWake, modelId);

  @override
  String toString() {
    return 'AgentConfig(maxTurnsPerWake: $maxTurnsPerWake, modelId: $modelId)';
  }
}

/// @nodoc
abstract mixin class _$AgentConfigCopyWith<$Res>
    implements $AgentConfigCopyWith<$Res> {
  factory _$AgentConfigCopyWith(
          _AgentConfig value, $Res Function(_AgentConfig) _then) =
      __$AgentConfigCopyWithImpl;
  @override
  @useResult
  $Res call({int maxTurnsPerWake, String modelId});
}

/// @nodoc
class __$AgentConfigCopyWithImpl<$Res> implements _$AgentConfigCopyWith<$Res> {
  __$AgentConfigCopyWithImpl(this._self, this._then);

  final _AgentConfig _self;
  final $Res Function(_AgentConfig) _then;

  /// Create a copy of AgentConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? maxTurnsPerWake = null,
    Object? modelId = null,
  }) {
    return _then(_AgentConfig(
      maxTurnsPerWake: null == maxTurnsPerWake
          ? _self.maxTurnsPerWake
          : maxTurnsPerWake // ignore: cast_nullable_to_non_nullable
              as int,
      modelId: null == modelId
          ? _self.modelId
          : modelId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$AgentSlots {
  /// The journal-domain task ID this agent is working on.
  String? get activeTaskId;

  /// Create a copy of AgentSlots
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentSlotsCopyWith<AgentSlots> get copyWith =>
      _$AgentSlotsCopyWithImpl<AgentSlots>(this as AgentSlots, _$identity);

  /// Serializes this AgentSlots to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentSlots &&
            (identical(other.activeTaskId, activeTaskId) ||
                other.activeTaskId == activeTaskId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, activeTaskId);

  @override
  String toString() {
    return 'AgentSlots(activeTaskId: $activeTaskId)';
  }
}

/// @nodoc
abstract mixin class $AgentSlotsCopyWith<$Res> {
  factory $AgentSlotsCopyWith(
          AgentSlots value, $Res Function(AgentSlots) _then) =
      _$AgentSlotsCopyWithImpl;
  @useResult
  $Res call({String? activeTaskId});
}

/// @nodoc
class _$AgentSlotsCopyWithImpl<$Res> implements $AgentSlotsCopyWith<$Res> {
  _$AgentSlotsCopyWithImpl(this._self, this._then);

  final AgentSlots _self;
  final $Res Function(AgentSlots) _then;

  /// Create a copy of AgentSlots
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeTaskId = freezed,
  }) {
    return _then(_self.copyWith(
      activeTaskId: freezed == activeTaskId
          ? _self.activeTaskId
          : activeTaskId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentSlots].
extension AgentSlotsPatterns on AgentSlots {
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
    TResult Function(_AgentSlots value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentSlots() when $default != null:
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
    TResult Function(_AgentSlots value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSlots():
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
    TResult? Function(_AgentSlots value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSlots() when $default != null:
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
    TResult Function(String? activeTaskId)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentSlots() when $default != null:
        return $default(_that.activeTaskId);
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
    TResult Function(String? activeTaskId) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSlots():
        return $default(_that.activeTaskId);
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
    TResult? Function(String? activeTaskId)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSlots() when $default != null:
        return $default(_that.activeTaskId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AgentSlots implements AgentSlots {
  const _AgentSlots({this.activeTaskId});
  factory _AgentSlots.fromJson(Map<String, dynamic> json) =>
      _$AgentSlotsFromJson(json);

  /// The journal-domain task ID this agent is working on.
  @override
  final String? activeTaskId;

  /// Create a copy of AgentSlots
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AgentSlotsCopyWith<_AgentSlots> get copyWith =>
      __$AgentSlotsCopyWithImpl<_AgentSlots>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentSlotsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AgentSlots &&
            (identical(other.activeTaskId, activeTaskId) ||
                other.activeTaskId == activeTaskId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, activeTaskId);

  @override
  String toString() {
    return 'AgentSlots(activeTaskId: $activeTaskId)';
  }
}

/// @nodoc
abstract mixin class _$AgentSlotsCopyWith<$Res>
    implements $AgentSlotsCopyWith<$Res> {
  factory _$AgentSlotsCopyWith(
          _AgentSlots value, $Res Function(_AgentSlots) _then) =
      __$AgentSlotsCopyWithImpl;
  @override
  @useResult
  $Res call({String? activeTaskId});
}

/// @nodoc
class __$AgentSlotsCopyWithImpl<$Res> implements _$AgentSlotsCopyWith<$Res> {
  __$AgentSlotsCopyWithImpl(this._self, this._then);

  final _AgentSlots _self;
  final $Res Function(_AgentSlots) _then;

  /// Create a copy of AgentSlots
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? activeTaskId = freezed,
  }) {
    return _then(_AgentSlots(
      activeTaskId: freezed == activeTaskId
          ? _self.activeTaskId
          : activeTaskId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$AgentMessageMetadata {
  /// The run key of the wake that produced this message.
  String? get runKey;

  /// Tool name if this is an action or toolResult message.
  String? get toolName;

  /// Operation ID for idempotency tracking.
  String? get operationId;

  /// Error message if the tool call failed.
  String? get errorMessage;

  /// Whether the tool call was denied by policy.
  bool get policyDenied;

  /// Denial reason if policyDenied is true.
  String? get denialReason;

  /// Create a copy of AgentMessageMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentMessageMetadataCopyWith<AgentMessageMetadata> get copyWith =>
      _$AgentMessageMetadataCopyWithImpl<AgentMessageMetadata>(
          this as AgentMessageMetadata, _$identity);

  /// Serializes this AgentMessageMetadata to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentMessageMetadata &&
            (identical(other.runKey, runKey) || other.runKey == runKey) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            (identical(other.operationId, operationId) ||
                other.operationId == operationId) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.policyDenied, policyDenied) ||
                other.policyDenied == policyDenied) &&
            (identical(other.denialReason, denialReason) ||
                other.denialReason == denialReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, runKey, toolName, operationId,
      errorMessage, policyDenied, denialReason);

  @override
  String toString() {
    return 'AgentMessageMetadata(runKey: $runKey, toolName: $toolName, operationId: $operationId, errorMessage: $errorMessage, policyDenied: $policyDenied, denialReason: $denialReason)';
  }
}

/// @nodoc
abstract mixin class $AgentMessageMetadataCopyWith<$Res> {
  factory $AgentMessageMetadataCopyWith(AgentMessageMetadata value,
          $Res Function(AgentMessageMetadata) _then) =
      _$AgentMessageMetadataCopyWithImpl;
  @useResult
  $Res call(
      {String? runKey,
      String? toolName,
      String? operationId,
      String? errorMessage,
      bool policyDenied,
      String? denialReason});
}

/// @nodoc
class _$AgentMessageMetadataCopyWithImpl<$Res>
    implements $AgentMessageMetadataCopyWith<$Res> {
  _$AgentMessageMetadataCopyWithImpl(this._self, this._then);

  final AgentMessageMetadata _self;
  final $Res Function(AgentMessageMetadata) _then;

  /// Create a copy of AgentMessageMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? runKey = freezed,
    Object? toolName = freezed,
    Object? operationId = freezed,
    Object? errorMessage = freezed,
    Object? policyDenied = null,
    Object? denialReason = freezed,
  }) {
    return _then(_self.copyWith(
      runKey: freezed == runKey
          ? _self.runKey
          : runKey // ignore: cast_nullable_to_non_nullable
              as String?,
      toolName: freezed == toolName
          ? _self.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String?,
      operationId: freezed == operationId
          ? _self.operationId
          : operationId // ignore: cast_nullable_to_non_nullable
              as String?,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      policyDenied: null == policyDenied
          ? _self.policyDenied
          : policyDenied // ignore: cast_nullable_to_non_nullable
              as bool,
      denialReason: freezed == denialReason
          ? _self.denialReason
          : denialReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentMessageMetadata].
extension AgentMessageMetadataPatterns on AgentMessageMetadata {
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
    TResult Function(_AgentMessageMetadata value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentMessageMetadata() when $default != null:
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
    TResult Function(_AgentMessageMetadata value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentMessageMetadata():
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
    TResult? Function(_AgentMessageMetadata value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentMessageMetadata() when $default != null:
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
    TResult Function(String? runKey, String? toolName, String? operationId,
            String? errorMessage, bool policyDenied, String? denialReason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentMessageMetadata() when $default != null:
        return $default(_that.runKey, _that.toolName, _that.operationId,
            _that.errorMessage, _that.policyDenied, _that.denialReason);
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
    TResult Function(String? runKey, String? toolName, String? operationId,
            String? errorMessage, bool policyDenied, String? denialReason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentMessageMetadata():
        return $default(_that.runKey, _that.toolName, _that.operationId,
            _that.errorMessage, _that.policyDenied, _that.denialReason);
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
    TResult? Function(String? runKey, String? toolName, String? operationId,
            String? errorMessage, bool policyDenied, String? denialReason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentMessageMetadata() when $default != null:
        return $default(_that.runKey, _that.toolName, _that.operationId,
            _that.errorMessage, _that.policyDenied, _that.denialReason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AgentMessageMetadata implements AgentMessageMetadata {
  const _AgentMessageMetadata(
      {this.runKey,
      this.toolName,
      this.operationId,
      this.errorMessage,
      this.policyDenied = false,
      this.denialReason});
  factory _AgentMessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$AgentMessageMetadataFromJson(json);

  /// The run key of the wake that produced this message.
  @override
  final String? runKey;

  /// Tool name if this is an action or toolResult message.
  @override
  final String? toolName;

  /// Operation ID for idempotency tracking.
  @override
  final String? operationId;

  /// Error message if the tool call failed.
  @override
  final String? errorMessage;

  /// Whether the tool call was denied by policy.
  @override
  @JsonKey()
  final bool policyDenied;

  /// Denial reason if policyDenied is true.
  @override
  final String? denialReason;

  /// Create a copy of AgentMessageMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AgentMessageMetadataCopyWith<_AgentMessageMetadata> get copyWith =>
      __$AgentMessageMetadataCopyWithImpl<_AgentMessageMetadata>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentMessageMetadataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AgentMessageMetadata &&
            (identical(other.runKey, runKey) || other.runKey == runKey) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            (identical(other.operationId, operationId) ||
                other.operationId == operationId) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.policyDenied, policyDenied) ||
                other.policyDenied == policyDenied) &&
            (identical(other.denialReason, denialReason) ||
                other.denialReason == denialReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, runKey, toolName, operationId,
      errorMessage, policyDenied, denialReason);

  @override
  String toString() {
    return 'AgentMessageMetadata(runKey: $runKey, toolName: $toolName, operationId: $operationId, errorMessage: $errorMessage, policyDenied: $policyDenied, denialReason: $denialReason)';
  }
}

/// @nodoc
abstract mixin class _$AgentMessageMetadataCopyWith<$Res>
    implements $AgentMessageMetadataCopyWith<$Res> {
  factory _$AgentMessageMetadataCopyWith(_AgentMessageMetadata value,
          $Res Function(_AgentMessageMetadata) _then) =
      __$AgentMessageMetadataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? runKey,
      String? toolName,
      String? operationId,
      String? errorMessage,
      bool policyDenied,
      String? denialReason});
}

/// @nodoc
class __$AgentMessageMetadataCopyWithImpl<$Res>
    implements _$AgentMessageMetadataCopyWith<$Res> {
  __$AgentMessageMetadataCopyWithImpl(this._self, this._then);

  final _AgentMessageMetadata _self;
  final $Res Function(_AgentMessageMetadata) _then;

  /// Create a copy of AgentMessageMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? runKey = freezed,
    Object? toolName = freezed,
    Object? operationId = freezed,
    Object? errorMessage = freezed,
    Object? policyDenied = null,
    Object? denialReason = freezed,
  }) {
    return _then(_AgentMessageMetadata(
      runKey: freezed == runKey
          ? _self.runKey
          : runKey // ignore: cast_nullable_to_non_nullable
              as String?,
      toolName: freezed == toolName
          ? _self.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String?,
      operationId: freezed == operationId
          ? _self.operationId
          : operationId // ignore: cast_nullable_to_non_nullable
              as String?,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      policyDenied: null == policyDenied
          ? _self.policyDenied
          : policyDenied // ignore: cast_nullable_to_non_nullable
              as bool,
      denialReason: freezed == denialReason
          ? _self.denialReason
          : denialReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
