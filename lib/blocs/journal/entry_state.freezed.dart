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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$EntryState {
  String get entryId => throw _privateConstructorUsedError;
  JournalEntity? get entry => throw _privateConstructorUsedError;
  bool get showMap => throw _privateConstructorUsedError;
  bool get isFocused => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)
        saved,
    required TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)
        dirty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        saved,
    TResult? Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        dirty,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        saved,
    TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
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

  @JsonKey(ignore: true)
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
      {String entryId, JournalEntity? entry, bool showMap, bool isFocused});

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

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryId = null,
    Object? entry = freezed,
    Object? showMap = null,
    Object? isFocused = null,
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
    ) as $Val);
  }

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
abstract class _$$_EntryStateSavedCopyWith<$Res>
    implements $EntryStateCopyWith<$Res> {
  factory _$$_EntryStateSavedCopyWith(
          _$_EntryStateSaved value, $Res Function(_$_EntryStateSaved) then) =
      __$$_EntryStateSavedCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String entryId, JournalEntity? entry, bool showMap, bool isFocused});

  @override
  $JournalEntityCopyWith<$Res>? get entry;
}

/// @nodoc
class __$$_EntryStateSavedCopyWithImpl<$Res>
    extends _$EntryStateCopyWithImpl<$Res, _$_EntryStateSaved>
    implements _$$_EntryStateSavedCopyWith<$Res> {
  __$$_EntryStateSavedCopyWithImpl(
      _$_EntryStateSaved _value, $Res Function(_$_EntryStateSaved) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryId = null,
    Object? entry = freezed,
    Object? showMap = null,
    Object? isFocused = null,
  }) {
    return _then(_$_EntryStateSaved(
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
    ));
  }
}

/// @nodoc

class _$_EntryStateSaved implements _EntryStateSaved {
  _$_EntryStateSaved(
      {required this.entryId,
      required this.entry,
      required this.showMap,
      required this.isFocused});

  @override
  final String entryId;
  @override
  final JournalEntity? entry;
  @override
  final bool showMap;
  @override
  final bool isFocused;

  @override
  String toString() {
    return 'EntryState.saved(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_EntryStateSaved &&
            (identical(other.entryId, entryId) || other.entryId == entryId) &&
            (identical(other.entry, entry) || other.entry == entry) &&
            (identical(other.showMap, showMap) || other.showMap == showMap) &&
            (identical(other.isFocused, isFocused) ||
                other.isFocused == isFocused));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, entryId, entry, showMap, isFocused);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_EntryStateSavedCopyWith<_$_EntryStateSaved> get copyWith =>
      __$$_EntryStateSavedCopyWithImpl<_$_EntryStateSaved>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)
        saved,
    required TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)
        dirty,
  }) {
    return saved(entryId, entry, showMap, isFocused);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        saved,
    TResult? Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        dirty,
  }) {
    return saved?.call(entryId, entry, showMap, isFocused);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        saved,
    TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        dirty,
    required TResult orElse(),
  }) {
    if (saved != null) {
      return saved(entryId, entry, showMap, isFocused);
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
      required final bool isFocused}) = _$_EntryStateSaved;

  @override
  String get entryId;
  @override
  JournalEntity? get entry;
  @override
  bool get showMap;
  @override
  bool get isFocused;
  @override
  @JsonKey(ignore: true)
  _$$_EntryStateSavedCopyWith<_$_EntryStateSaved> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$EntryStateDirtyCopyWith<$Res>
    implements $EntryStateCopyWith<$Res> {
  factory _$$EntryStateDirtyCopyWith(
          _$EntryStateDirty value, $Res Function(_$EntryStateDirty) then) =
      __$$EntryStateDirtyCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String entryId, JournalEntity? entry, bool showMap, bool isFocused});

  @override
  $JournalEntityCopyWith<$Res>? get entry;
}

/// @nodoc
class __$$EntryStateDirtyCopyWithImpl<$Res>
    extends _$EntryStateCopyWithImpl<$Res, _$EntryStateDirty>
    implements _$$EntryStateDirtyCopyWith<$Res> {
  __$$EntryStateDirtyCopyWithImpl(
      _$EntryStateDirty _value, $Res Function(_$EntryStateDirty) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryId = null,
    Object? entry = freezed,
    Object? showMap = null,
    Object? isFocused = null,
  }) {
    return _then(_$EntryStateDirty(
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
    ));
  }
}

/// @nodoc

class _$EntryStateDirty implements EntryStateDirty {
  _$EntryStateDirty(
      {required this.entryId,
      required this.entry,
      required this.showMap,
      required this.isFocused});

  @override
  final String entryId;
  @override
  final JournalEntity? entry;
  @override
  final bool showMap;
  @override
  final bool isFocused;

  @override
  String toString() {
    return 'EntryState.dirty(entryId: $entryId, entry: $entry, showMap: $showMap, isFocused: $isFocused)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntryStateDirty &&
            (identical(other.entryId, entryId) || other.entryId == entryId) &&
            (identical(other.entry, entry) || other.entry == entry) &&
            (identical(other.showMap, showMap) || other.showMap == showMap) &&
            (identical(other.isFocused, isFocused) ||
                other.isFocused == isFocused));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, entryId, entry, showMap, isFocused);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EntryStateDirtyCopyWith<_$EntryStateDirty> get copyWith =>
      __$$EntryStateDirtyCopyWithImpl<_$EntryStateDirty>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)
        saved,
    required TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)
        dirty,
  }) {
    return dirty(entryId, entry, showMap, isFocused);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        saved,
    TResult? Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        dirty,
  }) {
    return dirty?.call(entryId, entry, showMap, isFocused);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        saved,
    TResult Function(
            String entryId, JournalEntity? entry, bool showMap, bool isFocused)?
        dirty,
    required TResult orElse(),
  }) {
    if (dirty != null) {
      return dirty(entryId, entry, showMap, isFocused);
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
      required final bool isFocused}) = _$EntryStateDirty;

  @override
  String get entryId;
  @override
  JournalEntity? get entry;
  @override
  bool get showMap;
  @override
  bool get isFocused;
  @override
  @JsonKey(ignore: true)
  _$$EntryStateDirtyCopyWith<_$EntryStateDirty> get copyWith =>
      throw _privateConstructorUsedError;
}
