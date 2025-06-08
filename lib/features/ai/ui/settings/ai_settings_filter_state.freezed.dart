// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_settings_filter_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AiSettingsFilterState {
  /// Text query for searching across all AI configuration names and descriptions
  String get searchQuery => throw _privateConstructorUsedError;

  /// Selected provider IDs for filtering models (only used on Models tab)
  Set<String> get selectedProviders => throw _privateConstructorUsedError;

  /// Selected capabilities for filtering models (only used on Models tab)
  Set<Modality> get selectedCapabilities => throw _privateConstructorUsedError;

  /// Whether to show only reasoning-capable models (only used on Models tab)
  bool get reasoningFilter => throw _privateConstructorUsedError;

  /// Currently active tab
  AiSettingsTab get activeTab => throw _privateConstructorUsedError;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiSettingsFilterStateCopyWith<AiSettingsFilterState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiSettingsFilterStateCopyWith<$Res> {
  factory $AiSettingsFilterStateCopyWith(AiSettingsFilterState value,
          $Res Function(AiSettingsFilterState) then) =
      _$AiSettingsFilterStateCopyWithImpl<$Res, AiSettingsFilterState>;
  @useResult
  $Res call(
      {String searchQuery,
      Set<String> selectedProviders,
      Set<Modality> selectedCapabilities,
      bool reasoningFilter,
      AiSettingsTab activeTab});
}

/// @nodoc
class _$AiSettingsFilterStateCopyWithImpl<$Res,
        $Val extends AiSettingsFilterState>
    implements $AiSettingsFilterStateCopyWith<$Res> {
  _$AiSettingsFilterStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? selectedProviders = null,
    Object? selectedCapabilities = null,
    Object? reasoningFilter = null,
    Object? activeTab = null,
  }) {
    return _then(_value.copyWith(
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      selectedProviders: null == selectedProviders
          ? _value.selectedProviders
          : selectedProviders // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCapabilities: null == selectedCapabilities
          ? _value.selectedCapabilities
          : selectedCapabilities // ignore: cast_nullable_to_non_nullable
              as Set<Modality>,
      reasoningFilter: null == reasoningFilter
          ? _value.reasoningFilter
          : reasoningFilter // ignore: cast_nullable_to_non_nullable
              as bool,
      activeTab: null == activeTab
          ? _value.activeTab
          : activeTab // ignore: cast_nullable_to_non_nullable
              as AiSettingsTab,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiSettingsFilterStateImplCopyWith<$Res>
    implements $AiSettingsFilterStateCopyWith<$Res> {
  factory _$$AiSettingsFilterStateImplCopyWith(
          _$AiSettingsFilterStateImpl value,
          $Res Function(_$AiSettingsFilterStateImpl) then) =
      __$$AiSettingsFilterStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String searchQuery,
      Set<String> selectedProviders,
      Set<Modality> selectedCapabilities,
      bool reasoningFilter,
      AiSettingsTab activeTab});
}

/// @nodoc
class __$$AiSettingsFilterStateImplCopyWithImpl<$Res>
    extends _$AiSettingsFilterStateCopyWithImpl<$Res,
        _$AiSettingsFilterStateImpl>
    implements _$$AiSettingsFilterStateImplCopyWith<$Res> {
  __$$AiSettingsFilterStateImplCopyWithImpl(_$AiSettingsFilterStateImpl _value,
      $Res Function(_$AiSettingsFilterStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? selectedProviders = null,
    Object? selectedCapabilities = null,
    Object? reasoningFilter = null,
    Object? activeTab = null,
  }) {
    return _then(_$AiSettingsFilterStateImpl(
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      selectedProviders: null == selectedProviders
          ? _value._selectedProviders
          : selectedProviders // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      selectedCapabilities: null == selectedCapabilities
          ? _value._selectedCapabilities
          : selectedCapabilities // ignore: cast_nullable_to_non_nullable
              as Set<Modality>,
      reasoningFilter: null == reasoningFilter
          ? _value.reasoningFilter
          : reasoningFilter // ignore: cast_nullable_to_non_nullable
              as bool,
      activeTab: null == activeTab
          ? _value.activeTab
          : activeTab // ignore: cast_nullable_to_non_nullable
              as AiSettingsTab,
    ));
  }
}

/// @nodoc

class _$AiSettingsFilterStateImpl implements _AiSettingsFilterState {
  const _$AiSettingsFilterStateImpl(
      {this.searchQuery = '',
      final Set<String> selectedProviders = const {},
      final Set<Modality> selectedCapabilities = const {},
      this.reasoningFilter = false,
      this.activeTab = AiSettingsTab.providers})
      : _selectedProviders = selectedProviders,
        _selectedCapabilities = selectedCapabilities;

  /// Text query for searching across all AI configuration names and descriptions
  @override
  @JsonKey()
  final String searchQuery;

  /// Selected provider IDs for filtering models (only used on Models tab)
  final Set<String> _selectedProviders;

  /// Selected provider IDs for filtering models (only used on Models tab)
  @override
  @JsonKey()
  Set<String> get selectedProviders {
    if (_selectedProviders is EqualUnmodifiableSetView)
      return _selectedProviders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedProviders);
  }

  /// Selected capabilities for filtering models (only used on Models tab)
  final Set<Modality> _selectedCapabilities;

  /// Selected capabilities for filtering models (only used on Models tab)
  @override
  @JsonKey()
  Set<Modality> get selectedCapabilities {
    if (_selectedCapabilities is EqualUnmodifiableSetView)
      return _selectedCapabilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedCapabilities);
  }

  /// Whether to show only reasoning-capable models (only used on Models tab)
  @override
  @JsonKey()
  final bool reasoningFilter;

  /// Currently active tab
  @override
  @JsonKey()
  final AiSettingsTab activeTab;

  @override
  String toString() {
    return 'AiSettingsFilterState(searchQuery: $searchQuery, selectedProviders: $selectedProviders, selectedCapabilities: $selectedCapabilities, reasoningFilter: $reasoningFilter, activeTab: $activeTab)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiSettingsFilterStateImpl &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            const DeepCollectionEquality()
                .equals(other._selectedProviders, _selectedProviders) &&
            const DeepCollectionEquality()
                .equals(other._selectedCapabilities, _selectedCapabilities) &&
            (identical(other.reasoningFilter, reasoningFilter) ||
                other.reasoningFilter == reasoningFilter) &&
            (identical(other.activeTab, activeTab) ||
                other.activeTab == activeTab));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      searchQuery,
      const DeepCollectionEquality().hash(_selectedProviders),
      const DeepCollectionEquality().hash(_selectedCapabilities),
      reasoningFilter,
      activeTab);

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiSettingsFilterStateImplCopyWith<_$AiSettingsFilterStateImpl>
      get copyWith => __$$AiSettingsFilterStateImplCopyWithImpl<
          _$AiSettingsFilterStateImpl>(this, _$identity);
}

abstract class _AiSettingsFilterState implements AiSettingsFilterState {
  const factory _AiSettingsFilterState(
      {final String searchQuery,
      final Set<String> selectedProviders,
      final Set<Modality> selectedCapabilities,
      final bool reasoningFilter,
      final AiSettingsTab activeTab}) = _$AiSettingsFilterStateImpl;

  /// Text query for searching across all AI configuration names and descriptions
  @override
  String get searchQuery;

  /// Selected provider IDs for filtering models (only used on Models tab)
  @override
  Set<String> get selectedProviders;

  /// Selected capabilities for filtering models (only used on Models tab)
  @override
  Set<Modality> get selectedCapabilities;

  /// Whether to show only reasoning-capable models (only used on Models tab)
  @override
  bool get reasoningFilter;

  /// Currently active tab
  @override
  AiSettingsTab get activeTab;

  /// Create a copy of AiSettingsFilterState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiSettingsFilterStateImplCopyWith<_$AiSettingsFilterStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
