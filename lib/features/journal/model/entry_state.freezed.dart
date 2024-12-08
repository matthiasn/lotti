// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$EntryState {
  String get entryId => throw _privateConstructorUsedError;
  JournalEntity? get entry => throw _privateConstructorUsedError;
  bool get showMap => throw _privateConstructorUsedError;
  bool get isFocused => throw _privateConstructorUsedError;
  bool get shouldShowEditorToolBar => throw _privateConstructorUsedError;
  GlobalKey<FormBuilderState>? get formKey =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_EntryStateSaved value) saved,
    required TResult Function(EntryStateDirty value) dirty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_EntryStateSaved value)? saved,
    TResult? Function(EntryStateDirty value)? dirty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_EntryStateSaved value)? saved,
    TResult Function(EntryStateDirty value)? dirty,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EntryStateCopyWith<EntryState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntryStateCopyWith<$Res> {
  factory $EntryStateCopyWith(
          EntryState value, $Res Function(EntryState) then) =
      _$EntryStateCopyWithImpl<$Res, EntryState>;
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
class _$EntryStateCopyWithImpl<$Res, $Val extends EntryState>
    implements $EntryStateCopyWith<$Res> {
  _$EntryStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      entryId: null == entryId
          ? _value.entryId
          : entryId // ignore: cast_nullable_to_non_nullable
              as String,
      entry: freezed == entry
          ? _value.entry
          : entry // ignore: cast_nullable_to_non_nullable
              as JournalEntity?,
      showMap: null == showMap
          ? _value.showMap
          : showMap // ignore: cast_nullable_to_non_nullable
              as bool,
      isFocused: null == isFocused
          ? _value.isFocused
          : isFocused // ignore: cast_nullable_to_non_nullable
              as bool,
      shouldShowEditorToolBar: null == shouldShowEditorToolBar
          ? _value.shouldShowEditorToolBar
          : shouldShowEditorToolBar // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: freezed == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>?,
    ) as $Val);
  }

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $JournalEntityCopyWith<$Res>? get entry {
    if (_value.entry == null) {
      return null;
    }

    return $JournalEntityCopyWith<$Res>(_value.entry!, (value) {
      return _then(_value.copyWith(entry: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EntryStateSavedImplCopyWith<$Res>
    implements $EntryStateCopyWith<$Res> {
  factory _$$EntryStateSavedImplCopyWith(_$EntryStateSavedImpl value,
          $Res Function(_$EntryStateSavedImpl) then) =
      __$$EntryStateSavedImplCopyWithImpl<$Res>;
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
class __$$EntryStateSavedImplCopyWithImpl<$Res>
    extends _$EntryStateCopyWithImpl<$Res, _$EntryStateSavedImpl>
    implements _$$EntryStateSavedImplCopyWith<$Res> {
  __$$EntryStateSavedImplCopyWithImpl(
      _$EntryStateSavedImpl _value, $Res Function(_$EntryStateSavedImpl) _then)
      : super(_value, _then);

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
    return _then(_$EntryStateSavedImpl(
      entryId: null == entryId
          ? _value.entryId
          : entryId // ignore: cast_nullable_to_non_nullable
              as String,
      entry: freezed == entry
          ? _value.entry
          : entry // ignore: cast_nullable_to_non_nullable
              as JournalEntity?,
      showMap: null == showMap
          ? _value.showMap
          : showMap // ignore: cast_nullable_to_non_nullable
              as bool,
      isFocused: null == isFocused
          ? _value.isFocused
          : isFocused // ignore: cast_nullable_to_non_nullable
              as bool,
      shouldShowEditorToolBar: null == shouldShowEditorToolBar
          ? _value.shouldShowEditorToolBar
          : shouldShowEditorToolBar // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: freezed == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>?,
    ));
  }
}

/// @nodoc

class _$EntryStateSavedImpl implements _EntryStateSaved {
  _$EntryStateSavedImpl(
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

  @override
  String toString() {
    return 'EntryState.saved(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused, shouldShowEditorToolBar: $shouldShowEditorToolBar, formKey: $formKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntryStateSavedImpl &&
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

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntryStateSavedImplCopyWith<_$EntryStateSavedImpl> get copyWith =>
      __$$EntryStateSavedImplCopyWithImpl<_$EntryStateSavedImpl>(
          this, _$identity);

  @override
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
    return saved(
        entryId, entry, showMap, isFocused, shouldShowEditorToolBar, formKey);
  }

  @override
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
    return saved?.call(
        entryId, entry, showMap, isFocused, shouldShowEditorToolBar, formKey);
  }

  @override
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
    if (saved != null) {
      return saved(
          entryId, entry, showMap, isFocused, shouldShowEditorToolBar, formKey);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_EntryStateSaved value) saved,
    required TResult Function(EntryStateDirty value) dirty,
  }) {
    return saved(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_EntryStateSaved value)? saved,
    TResult? Function(EntryStateDirty value)? dirty,
  }) {
    return saved?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_EntryStateSaved value)? saved,
    TResult Function(EntryStateDirty value)? dirty,
    required TResult orElse(),
  }) {
    if (saved != null) {
      return saved(this);
    }
    return orElse();
  }
}

abstract class _EntryStateSaved implements EntryState {
  factory _EntryStateSaved(
      {required final String entryId,
      required final JournalEntity? entry,
      required final bool showMap,
      required final bool isFocused,
      required final bool shouldShowEditorToolBar,
      final GlobalKey<FormBuilderState>? formKey}) = _$EntryStateSavedImpl;

  @override
  String get entryId;
  @override
  JournalEntity? get entry;
  @override
  bool get showMap;
  @override
  bool get isFocused;
  @override
  bool get shouldShowEditorToolBar;
  @override
  GlobalKey<FormBuilderState>? get formKey;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntryStateSavedImplCopyWith<_$EntryStateSavedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$EntryStateDirtyImplCopyWith<$Res>
    implements $EntryStateCopyWith<$Res> {
  factory _$$EntryStateDirtyImplCopyWith(_$EntryStateDirtyImpl value,
          $Res Function(_$EntryStateDirtyImpl) then) =
      __$$EntryStateDirtyImplCopyWithImpl<$Res>;
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
class __$$EntryStateDirtyImplCopyWithImpl<$Res>
    extends _$EntryStateCopyWithImpl<$Res, _$EntryStateDirtyImpl>
    implements _$$EntryStateDirtyImplCopyWith<$Res> {
  __$$EntryStateDirtyImplCopyWithImpl(
      _$EntryStateDirtyImpl _value, $Res Function(_$EntryStateDirtyImpl) _then)
      : super(_value, _then);

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
    return _then(_$EntryStateDirtyImpl(
      entryId: null == entryId
          ? _value.entryId
          : entryId // ignore: cast_nullable_to_non_nullable
              as String,
      entry: freezed == entry
          ? _value.entry
          : entry // ignore: cast_nullable_to_non_nullable
              as JournalEntity?,
      showMap: null == showMap
          ? _value.showMap
          : showMap // ignore: cast_nullable_to_non_nullable
              as bool,
      isFocused: null == isFocused
          ? _value.isFocused
          : isFocused // ignore: cast_nullable_to_non_nullable
              as bool,
      shouldShowEditorToolBar: null == shouldShowEditorToolBar
          ? _value.shouldShowEditorToolBar
          : shouldShowEditorToolBar // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: freezed == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>?,
    ));
  }
}

/// @nodoc

class _$EntryStateDirtyImpl implements EntryStateDirty {
  _$EntryStateDirtyImpl(
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

  @override
  String toString() {
    return 'EntryState.dirty(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused, shouldShowEditorToolBar: $shouldShowEditorToolBar, formKey: $formKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntryStateDirtyImpl &&
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

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntryStateDirtyImplCopyWith<_$EntryStateDirtyImpl> get copyWith =>
      __$$EntryStateDirtyImplCopyWithImpl<_$EntryStateDirtyImpl>(
          this, _$identity);

  @override
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
    return dirty(
        entryId, entry, showMap, isFocused, shouldShowEditorToolBar, formKey);
  }

  @override
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
    return dirty?.call(
        entryId, entry, showMap, isFocused, shouldShowEditorToolBar, formKey);
  }

  @override
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
    if (dirty != null) {
      return dirty(
          entryId, entry, showMap, isFocused, shouldShowEditorToolBar, formKey);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_EntryStateSaved value) saved,
    required TResult Function(EntryStateDirty value) dirty,
  }) {
    return dirty(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_EntryStateSaved value)? saved,
    TResult? Function(EntryStateDirty value)? dirty,
  }) {
    return dirty?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_EntryStateSaved value)? saved,
    TResult Function(EntryStateDirty value)? dirty,
    required TResult orElse(),
  }) {
    if (dirty != null) {
      return dirty(this);
    }
    return orElse();
  }
}

abstract class EntryStateDirty implements EntryState {
  factory EntryStateDirty(
      {required final String entryId,
      required final JournalEntity? entry,
      required final bool showMap,
      required final bool isFocused,
      required final bool shouldShowEditorToolBar,
      final GlobalKey<FormBuilderState>? formKey}) = _$EntryStateDirtyImpl;

  @override
  String get entryId;
  @override
  JournalEntity? get entry;
  @override
  bool get showMap;
  @override
  bool get isFocused;
  @override
  bool get shouldShowEditorToolBar;
  @override
  GlobalKey<FormBuilderState>? get formKey;

  /// Create a copy of EntryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntryStateDirtyImplCopyWith<_$EntryStateDirtyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
