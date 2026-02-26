// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'evolution_chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EvolutionChatMessage {
  DateTime get timestamp;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EvolutionChatMessageCopyWith<EvolutionChatMessage> get copyWith =>
      _$EvolutionChatMessageCopyWithImpl<EvolutionChatMessage>(
          this as EvolutionChatMessage, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EvolutionChatMessage &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, timestamp);

  @override
  String toString() {
    return 'EvolutionChatMessage(timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $EvolutionChatMessageCopyWith<$Res> {
  factory $EvolutionChatMessageCopyWith(EvolutionChatMessage value,
          $Res Function(EvolutionChatMessage) _then) =
      _$EvolutionChatMessageCopyWithImpl;
  @useResult
  $Res call({DateTime timestamp});
}

/// @nodoc
class _$EvolutionChatMessageCopyWithImpl<$Res>
    implements $EvolutionChatMessageCopyWith<$Res> {
  _$EvolutionChatMessageCopyWithImpl(this._self, this._then);

  final EvolutionChatMessage _self;
  final $Res Function(EvolutionChatMessage) _then;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
  }) {
    return _then(_self.copyWith(
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [EvolutionChatMessage].
extension EvolutionChatMessagePatterns on EvolutionChatMessage {
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
    TResult Function(EvolutionUserMessage value)? user,
    TResult Function(EvolutionAssistantMessage value)? assistant,
    TResult Function(EvolutionSystemMessage value)? system,
    TResult Function(EvolutionProposalMessage value)? proposal,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case EvolutionUserMessage() when user != null:
        return user(_that);
      case EvolutionAssistantMessage() when assistant != null:
        return assistant(_that);
      case EvolutionSystemMessage() when system != null:
        return system(_that);
      case EvolutionProposalMessage() when proposal != null:
        return proposal(_that);
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
    required TResult Function(EvolutionUserMessage value) user,
    required TResult Function(EvolutionAssistantMessage value) assistant,
    required TResult Function(EvolutionSystemMessage value) system,
    required TResult Function(EvolutionProposalMessage value) proposal,
  }) {
    final _that = this;
    switch (_that) {
      case EvolutionUserMessage():
        return user(_that);
      case EvolutionAssistantMessage():
        return assistant(_that);
      case EvolutionSystemMessage():
        return system(_that);
      case EvolutionProposalMessage():
        return proposal(_that);
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
    TResult? Function(EvolutionUserMessage value)? user,
    TResult? Function(EvolutionAssistantMessage value)? assistant,
    TResult? Function(EvolutionSystemMessage value)? system,
    TResult? Function(EvolutionProposalMessage value)? proposal,
  }) {
    final _that = this;
    switch (_that) {
      case EvolutionUserMessage() when user != null:
        return user(_that);
      case EvolutionAssistantMessage() when assistant != null:
        return assistant(_that);
      case EvolutionSystemMessage() when system != null:
        return system(_that);
      case EvolutionProposalMessage() when proposal != null:
        return proposal(_that);
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
    TResult Function(String text, DateTime timestamp)? user,
    TResult Function(String text, DateTime timestamp)? assistant,
    TResult Function(String text, DateTime timestamp)? system,
    TResult Function(PendingProposal proposal, DateTime timestamp)? proposal,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case EvolutionUserMessage() when user != null:
        return user(_that.text, _that.timestamp);
      case EvolutionAssistantMessage() when assistant != null:
        return assistant(_that.text, _that.timestamp);
      case EvolutionSystemMessage() when system != null:
        return system(_that.text, _that.timestamp);
      case EvolutionProposalMessage() when proposal != null:
        return proposal(_that.proposal, _that.timestamp);
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
    required TResult Function(String text, DateTime timestamp) user,
    required TResult Function(String text, DateTime timestamp) assistant,
    required TResult Function(String text, DateTime timestamp) system,
    required TResult Function(PendingProposal proposal, DateTime timestamp)
        proposal,
  }) {
    final _that = this;
    switch (_that) {
      case EvolutionUserMessage():
        return user(_that.text, _that.timestamp);
      case EvolutionAssistantMessage():
        return assistant(_that.text, _that.timestamp);
      case EvolutionSystemMessage():
        return system(_that.text, _that.timestamp);
      case EvolutionProposalMessage():
        return proposal(_that.proposal, _that.timestamp);
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
    TResult? Function(String text, DateTime timestamp)? user,
    TResult? Function(String text, DateTime timestamp)? assistant,
    TResult? Function(String text, DateTime timestamp)? system,
    TResult? Function(PendingProposal proposal, DateTime timestamp)? proposal,
  }) {
    final _that = this;
    switch (_that) {
      case EvolutionUserMessage() when user != null:
        return user(_that.text, _that.timestamp);
      case EvolutionAssistantMessage() when assistant != null:
        return assistant(_that.text, _that.timestamp);
      case EvolutionSystemMessage() when system != null:
        return system(_that.text, _that.timestamp);
      case EvolutionProposalMessage() when proposal != null:
        return proposal(_that.proposal, _that.timestamp);
      case _:
        return null;
    }
  }
}

/// @nodoc

class EvolutionUserMessage implements EvolutionChatMessage {
  const EvolutionUserMessage({required this.text, required this.timestamp});

  final String text;
  @override
  final DateTime timestamp;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EvolutionUserMessageCopyWith<EvolutionUserMessage> get copyWith =>
      _$EvolutionUserMessageCopyWithImpl<EvolutionUserMessage>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EvolutionUserMessage &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text, timestamp);

  @override
  String toString() {
    return 'EvolutionChatMessage.user(text: $text, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $EvolutionUserMessageCopyWith<$Res>
    implements $EvolutionChatMessageCopyWith<$Res> {
  factory $EvolutionUserMessageCopyWith(EvolutionUserMessage value,
          $Res Function(EvolutionUserMessage) _then) =
      _$EvolutionUserMessageCopyWithImpl;
  @override
  @useResult
  $Res call({String text, DateTime timestamp});
}

/// @nodoc
class _$EvolutionUserMessageCopyWithImpl<$Res>
    implements $EvolutionUserMessageCopyWith<$Res> {
  _$EvolutionUserMessageCopyWithImpl(this._self, this._then);

  final EvolutionUserMessage _self;
  final $Res Function(EvolutionUserMessage) _then;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? text = null,
    Object? timestamp = null,
  }) {
    return _then(EvolutionUserMessage(
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class EvolutionAssistantMessage implements EvolutionChatMessage {
  const EvolutionAssistantMessage(
      {required this.text, required this.timestamp});

  final String text;
  @override
  final DateTime timestamp;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EvolutionAssistantMessageCopyWith<EvolutionAssistantMessage> get copyWith =>
      _$EvolutionAssistantMessageCopyWithImpl<EvolutionAssistantMessage>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EvolutionAssistantMessage &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text, timestamp);

  @override
  String toString() {
    return 'EvolutionChatMessage.assistant(text: $text, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $EvolutionAssistantMessageCopyWith<$Res>
    implements $EvolutionChatMessageCopyWith<$Res> {
  factory $EvolutionAssistantMessageCopyWith(EvolutionAssistantMessage value,
          $Res Function(EvolutionAssistantMessage) _then) =
      _$EvolutionAssistantMessageCopyWithImpl;
  @override
  @useResult
  $Res call({String text, DateTime timestamp});
}

/// @nodoc
class _$EvolutionAssistantMessageCopyWithImpl<$Res>
    implements $EvolutionAssistantMessageCopyWith<$Res> {
  _$EvolutionAssistantMessageCopyWithImpl(this._self, this._then);

  final EvolutionAssistantMessage _self;
  final $Res Function(EvolutionAssistantMessage) _then;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? text = null,
    Object? timestamp = null,
  }) {
    return _then(EvolutionAssistantMessage(
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class EvolutionSystemMessage implements EvolutionChatMessage {
  const EvolutionSystemMessage({required this.text, required this.timestamp});

  final String text;
  @override
  final DateTime timestamp;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EvolutionSystemMessageCopyWith<EvolutionSystemMessage> get copyWith =>
      _$EvolutionSystemMessageCopyWithImpl<EvolutionSystemMessage>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EvolutionSystemMessage &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text, timestamp);

  @override
  String toString() {
    return 'EvolutionChatMessage.system(text: $text, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $EvolutionSystemMessageCopyWith<$Res>
    implements $EvolutionChatMessageCopyWith<$Res> {
  factory $EvolutionSystemMessageCopyWith(EvolutionSystemMessage value,
          $Res Function(EvolutionSystemMessage) _then) =
      _$EvolutionSystemMessageCopyWithImpl;
  @override
  @useResult
  $Res call({String text, DateTime timestamp});
}

/// @nodoc
class _$EvolutionSystemMessageCopyWithImpl<$Res>
    implements $EvolutionSystemMessageCopyWith<$Res> {
  _$EvolutionSystemMessageCopyWithImpl(this._self, this._then);

  final EvolutionSystemMessage _self;
  final $Res Function(EvolutionSystemMessage) _then;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? text = null,
    Object? timestamp = null,
  }) {
    return _then(EvolutionSystemMessage(
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class EvolutionProposalMessage implements EvolutionChatMessage {
  const EvolutionProposalMessage(
      {required this.proposal, required this.timestamp});

  final PendingProposal proposal;
  @override
  final DateTime timestamp;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EvolutionProposalMessageCopyWith<EvolutionProposalMessage> get copyWith =>
      _$EvolutionProposalMessageCopyWithImpl<EvolutionProposalMessage>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EvolutionProposalMessage &&
            (identical(other.proposal, proposal) ||
                other.proposal == proposal) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, proposal, timestamp);

  @override
  String toString() {
    return 'EvolutionChatMessage.proposal(proposal: $proposal, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $EvolutionProposalMessageCopyWith<$Res>
    implements $EvolutionChatMessageCopyWith<$Res> {
  factory $EvolutionProposalMessageCopyWith(EvolutionProposalMessage value,
          $Res Function(EvolutionProposalMessage) _then) =
      _$EvolutionProposalMessageCopyWithImpl;
  @override
  @useResult
  $Res call({PendingProposal proposal, DateTime timestamp});
}

/// @nodoc
class _$EvolutionProposalMessageCopyWithImpl<$Res>
    implements $EvolutionProposalMessageCopyWith<$Res> {
  _$EvolutionProposalMessageCopyWithImpl(this._self, this._then);

  final EvolutionProposalMessage _self;
  final $Res Function(EvolutionProposalMessage) _then;

  /// Create a copy of EvolutionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? proposal = null,
    Object? timestamp = null,
  }) {
    return _then(EvolutionProposalMessage(
      proposal: null == proposal
          ? _self.proposal
          : proposal // ignore: cast_nullable_to_non_nullable
              as PendingProposal,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
