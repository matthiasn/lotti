// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EntryState {
  String get entryId;
  JournalEntity? get entry;
  bool get showMap;
  bool get isFocused;
  bool get shouldShowEditorToolBar;
  GlobalKey<FormBuilderState>? get formKey;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EntryStateCopyWith<EntryState> get copyWith =>
      _$EntryStateCopyWithImpl<EntryState>(this as EntryState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EntryState &&
            (identical(other.entryId, entryId) || other.entryId == entryId) &&
            (identical(other.entry, entry) || other.entry == entry) &&
            (identical(other.showMap, showMap) || other.showMap == showMap) &&
            (identical(other.isFocused, isFocused) ||
                other.isFocused == isFocused) &&
            (identical(
                    other.shouldShowEditorToolBar, shouldShowEditorToolBar) ||
                other.shouldShowEditorToolBar == shouldShowEditorToolBar) &&
            (identical(other.formKey, formKey) || other.formKey == formKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, entryId, entry, showMap,
      isFocused, shouldShowEditorToolBar, formKey);

  @override
  String toString() {
    return 'EntryState(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused, shouldShowEditorToolBar: $shouldShowEditorToolBar, formKey: $formKey)';
  }
}

/// @nodoc
abstract mixin class $EntryStateCopyWith<$Res> {
  factory $EntryStateCopyWith(
          EntryState value, $Res Function(EntryState) _then) =
      _$EntryStateCopyWithImpl;
  @useResult
  $Res call(
      {String entryId,
      JournalEntity? entry,
      bool showMap,
      bool isFocused,
      bool shouldShowEditorToolBar,
      GlobalKey<FormBuilderState>? formKey});

  $JournalEntityCopyWith<$Res>? get entry;
}

/// @nodoc
class _$EntryStateCopyWithImpl<$Res> implements $EntryStateCopyWith<$Res> {
  _$EntryStateCopyWithImpl(this._self, this._then);

  final EntryState _self;
  final $Res Function(EntryState) _then;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryId = null,
    Object? entry = freezed,
    Object? showMap = null,
    Object? isFocused = null,
    Object? shouldShowEditorToolBar = null,
    Object? formKey = freezed,
  }) {
    return _then(_self.copyWith(
      entryId: null == entryId
          ? _self.entryId
          : entryId // ignore: cast_nullable_to_non_nullable
              as String,
      entry: freezed == entry
          ? _self.entry
          : entry // ignore: cast_nullable_to_non_nullable
              as JournalEntity?,
      showMap: null == showMap
          ? _self.showMap
          : showMap // ignore: cast_nullable_to_non_nullable
              as bool,
      isFocused: null == isFocused
          ? _self.isFocused
          : isFocused // ignore: cast_nullable_to_non_nullable
              as bool,
      shouldShowEditorToolBar: null == shouldShowEditorToolBar
          ? _self.shouldShowEditorToolBar
          : shouldShowEditorToolBar // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: freezed == formKey
          ? _self.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>?,
    ));
  }

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $JournalEntityCopyWith<$Res>? get entry {
    if (_self.entry == null) {
      return null;
    }

    return $JournalEntityCopyWith<$Res>(_self.entry!, (value) {
      return _then(_self.copyWith(entry: value));
    });
  }
}

/// Adds pattern-matching-related methods to [EntryState].
extension EntryStatePatterns on EntryState {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_EntryStateSaved value)? saved,
    TResult Function(EntryStateDirty value)? dirty,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EntryStateSaved() when saved != null:
        return saved(_that);
      case EntryStateDirty() when dirty != null:
        return dirty(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(_EntryStateSaved value) saved,
    required TResult Function(EntryStateDirty value) dirty,
  }) {
    final _that = this;
    switch (_that) {
      case _EntryStateSaved():
        return saved(_that);
      case EntryStateDirty():
        return dirty(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_EntryStateSaved value)? saved,
    TResult? Function(EntryStateDirty value)? dirty,
  }) {
    final _that = this;
    switch (_that) {
      case _EntryStateSaved() when saved != null:
        return saved(_that);
      case EntryStateDirty() when dirty != null:
        return dirty(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String entryId,
            JournalEntity? entry,
            bool showMap,
            bool isFocused,
            bool shouldShowEditorToolBar,
            GlobalKey<FormBuilderState>? formKey)?
        saved,
    TResult Function(
            String entryId,
            JournalEntity? entry,
            bool showMap,
            bool isFocused,
            bool shouldShowEditorToolBar,
            GlobalKey<FormBuilderState>? formKey)?
        dirty,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EntryStateSaved() when saved != null:
        return saved(_that.entryId, _that.entry, _that.showMap, _that.isFocused,
            _that.shouldShowEditorToolBar, _that.formKey);
      case EntryStateDirty() when dirty != null:
        return dirty(_that.entryId, _that.entry, _that.showMap, _that.isFocused,
            _that.shouldShowEditorToolBar, _that.formKey);
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
  TResult when<TResult extends Object?>({
    required TResult Function(
            String entryId,
            JournalEntity? entry,
            bool showMap,
            bool isFocused,
            bool shouldShowEditorToolBar,
            GlobalKey<FormBuilderState>? formKey)
        saved,
    required TResult Function(
            String entryId,
            JournalEntity? entry,
            bool showMap,
            bool isFocused,
            bool shouldShowEditorToolBar,
            GlobalKey<FormBuilderState>? formKey)
        dirty,
  }) {
    final _that = this;
    switch (_that) {
      case _EntryStateSaved():
        return saved(_that.entryId, _that.entry, _that.showMap, _that.isFocused,
            _that.shouldShowEditorToolBar, _that.formKey);
      case EntryStateDirty():
        return dirty(_that.entryId, _that.entry, _that.showMap, _that.isFocused,
            _that.shouldShowEditorToolBar, _that.formKey);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String entryId,
            JournalEntity? entry,
            bool showMap,
            bool isFocused,
            bool shouldShowEditorToolBar,
            GlobalKey<FormBuilderState>? formKey)?
        saved,
    TResult? Function(
            String entryId,
            JournalEntity? entry,
            bool showMap,
            bool isFocused,
            bool shouldShowEditorToolBar,
            GlobalKey<FormBuilderState>? formKey)?
        dirty,
  }) {
    final _that = this;
    switch (_that) {
      case _EntryStateSaved() when saved != null:
        return saved(_that.entryId, _that.entry, _that.showMap, _that.isFocused,
            _that.shouldShowEditorToolBar, _that.formKey);
      case EntryStateDirty() when dirty != null:
        return dirty(_that.entryId, _that.entry, _that.showMap, _that.isFocused,
            _that.shouldShowEditorToolBar, _that.formKey);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _EntryStateSaved implements EntryState {
  _EntryStateSaved(
      {required this.entryId,
      required this.entry,
      required this.showMap,
      required this.isFocused,
      required this.shouldShowEditorToolBar,
      this.formKey});

  @override
  final String entryId;
  @override
  final JournalEntity? entry;
  @override
  final bool showMap;
  @override
  final bool isFocused;
  @override
  final bool shouldShowEditorToolBar;
  @override
  final GlobalKey<FormBuilderState>? formKey;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EntryStateSavedCopyWith<_EntryStateSaved> get copyWith =>
      __$EntryStateSavedCopyWithImpl<_EntryStateSaved>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EntryStateSaved &&
            (identical(other.entryId, entryId) || other.entryId == entryId) &&
            (identical(other.entry, entry) || other.entry == entry) &&
            (identical(other.showMap, showMap) || other.showMap == showMap) &&
            (identical(other.isFocused, isFocused) ||
                other.isFocused == isFocused) &&
            (identical(
                    other.shouldShowEditorToolBar, shouldShowEditorToolBar) ||
                other.shouldShowEditorToolBar == shouldShowEditorToolBar) &&
            (identical(other.formKey, formKey) || other.formKey == formKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, entryId, entry, showMap,
      isFocused, shouldShowEditorToolBar, formKey);

  @override
  String toString() {
    return 'EntryState.saved(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused, shouldShowEditorToolBar: $shouldShowEditorToolBar, formKey: $formKey)';
  }
}

/// @nodoc
abstract mixin class _$EntryStateSavedCopyWith<$Res>
    implements $EntryStateCopyWith<$Res> {
  factory _$EntryStateSavedCopyWith(
          _EntryStateSaved value, $Res Function(_EntryStateSaved) _then) =
      __$EntryStateSavedCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String entryId,
      JournalEntity? entry,
      bool showMap,
      bool isFocused,
      bool shouldShowEditorToolBar,
      GlobalKey<FormBuilderState>? formKey});

  @override
  $JournalEntityCopyWith<$Res>? get entry;
}

/// @nodoc
class __$EntryStateSavedCopyWithImpl<$Res>
    implements _$EntryStateSavedCopyWith<$Res> {
  __$EntryStateSavedCopyWithImpl(this._self, this._then);

  final _EntryStateSaved _self;
  final $Res Function(_EntryStateSaved) _then;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? entryId = null,
    Object? entry = freezed,
    Object? showMap = null,
    Object? isFocused = null,
    Object? shouldShowEditorToolBar = null,
    Object? formKey = freezed,
  }) {
    return _then(_EntryStateSaved(
      entryId: null == entryId
          ? _self.entryId
          : entryId // ignore: cast_nullable_to_non_nullable
              as String,
      entry: freezed == entry
          ? _self.entry
          : entry // ignore: cast_nullable_to_non_nullable
              as JournalEntity?,
      showMap: null == showMap
          ? _self.showMap
          : showMap // ignore: cast_nullable_to_non_nullable
              as bool,
      isFocused: null == isFocused
          ? _self.isFocused
          : isFocused // ignore: cast_nullable_to_non_nullable
              as bool,
      shouldShowEditorToolBar: null == shouldShowEditorToolBar
          ? _self.shouldShowEditorToolBar
          : shouldShowEditorToolBar // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: freezed == formKey
          ? _self.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>?,
    ));
  }

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $JournalEntityCopyWith<$Res>? get entry {
    if (_self.entry == null) {
      return null;
    }

    return $JournalEntityCopyWith<$Res>(_self.entry!, (value) {
      return _then(_self.copyWith(entry: value));
    });
  }
}

/// @nodoc

class EntryStateDirty implements EntryState {
  EntryStateDirty(
      {required this.entryId,
      required this.entry,
      required this.showMap,
      required this.isFocused,
      required this.shouldShowEditorToolBar,
      this.formKey});

  @override
  final String entryId;
  @override
  final JournalEntity? entry;
  @override
  final bool showMap;
  @override
  final bool isFocused;
  @override
  final bool shouldShowEditorToolBar;
  @override
  final GlobalKey<FormBuilderState>? formKey;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EntryStateDirtyCopyWith<EntryStateDirty> get copyWith =>
      _$EntryStateDirtyCopyWithImpl<EntryStateDirty>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EntryStateDirty &&
            (identical(other.entryId, entryId) || other.entryId == entryId) &&
            (identical(other.entry, entry) || other.entry == entry) &&
            (identical(other.showMap, showMap) || other.showMap == showMap) &&
            (identical(other.isFocused, isFocused) ||
                other.isFocused == isFocused) &&
            (identical(
                    other.shouldShowEditorToolBar, shouldShowEditorToolBar) ||
                other.shouldShowEditorToolBar == shouldShowEditorToolBar) &&
            (identical(other.formKey, formKey) || other.formKey == formKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, entryId, entry, showMap,
      isFocused, shouldShowEditorToolBar, formKey);

  @override
  String toString() {
    return 'EntryState.dirty(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused, shouldShowEditorToolBar: $shouldShowEditorToolBar, formKey: $formKey)';
  }
}

/// @nodoc
abstract mixin class $EntryStateDirtyCopyWith<$Res>
    implements $EntryStateCopyWith<$Res> {
  factory $EntryStateDirtyCopyWith(
          EntryStateDirty value, $Res Function(EntryStateDirty) _then) =
      _$EntryStateDirtyCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String entryId,
      JournalEntity? entry,
      bool showMap,
      bool isFocused,
      bool shouldShowEditorToolBar,
      GlobalKey<FormBuilderState>? formKey});

  @override
  $JournalEntityCopyWith<$Res>? get entry;
}

/// @nodoc
class _$EntryStateDirtyCopyWithImpl<$Res>
    implements $EntryStateDirtyCopyWith<$Res> {
  _$EntryStateDirtyCopyWithImpl(this._self, this._then);

  final EntryStateDirty _self;
  final $Res Function(EntryStateDirty) _then;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? entryId = null,
    Object? entry = freezed,
    Object? showMap = null,
    Object? isFocused = null,
    Object? shouldShowEditorToolBar = null,
    Object? formKey = freezed,
  }) {
    return _then(EntryStateDirty(
      entryId: null == entryId
          ? _self.entryId
          : entryId // ignore: cast_nullable_to_non_nullable
              as String,
      entry: freezed == entry
          ? _self.entry
          : entry // ignore: cast_nullable_to_non_nullable
              as JournalEntity?,
      showMap: null == showMap
          ? _self.showMap
          : showMap // ignore: cast_nullable_to_non_nullable
              as bool,
      isFocused: null == isFocused
          ? _self.isFocused
          : isFocused // ignore: cast_nullable_to_non_nullable
              as bool,
      shouldShowEditorToolBar: null == shouldShowEditorToolBar
          ? _self.shouldShowEditorToolBar
          : shouldShowEditorToolBar // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: freezed == formKey
          ? _self.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>?,
    ));
  }

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $JournalEntityCopyWith<$Res>? get entry {
    if (_self.entry == null) {
      return null;
    }

    return $JournalEntityCopyWith<$Res>(_self.entry!, (value) {
      return _then(_self.copyWith(entry: value));
    });
  }
}

// dart format on
