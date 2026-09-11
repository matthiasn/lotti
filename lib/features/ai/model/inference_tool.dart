import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Lotti-owned tool-definition types for the inference layer.
///
/// See `inference_message.dart` for why the AI layer owns these rather than
/// borrowing them from `openai_dart`.

const _mapEquality = MapEquality<String, dynamic>();

/// A function the model may call.
@immutable
class LottiTool {
  /// Creates a tool the model may call.
  const LottiTool({required this.name, this.parameters, this.description});

  /// The tool name the model uses to invoke it.
  final String name;

  /// A JSON Schema object describing the tool's arguments.
  ///
  /// Null for a tool that takes none; providers differ on whether they accept
  /// an empty schema, so the field is omitted rather than sent as `{}`.
  final Map<String, dynamic>? parameters;

  /// Human-readable description guiding the model on when to call this tool.
  final String? description;

  /// Returns a copy with the given fields replaced.
  LottiTool copyWith({
    String? name,
    Map<String, dynamic>? parameters,
    String? description,
  }) => LottiTool(
    name: name ?? this.name,
    parameters: parameters ?? this.parameters,
    description: description ?? this.description,
  );

  @override
  bool operator ==(Object other) =>
      other is LottiTool &&
      other.name == name &&
      other.description == description &&
      _mapEquality.equals(other.parameters, parameters);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    parameters == null ? null : _mapEquality.hash(parameters),
  );

  @override
  String toString() => 'LottiTool($name)';
}

/// How the model should choose between the tools it was offered.
@immutable
sealed class LottiToolChoice {
  const LottiToolChoice();

  /// Let the model decide whether to call a tool.
  const factory LottiToolChoice.auto() = LottiToolChoiceAuto;

  /// Forbid tool calls for this turn.
  const factory LottiToolChoice.none() = LottiToolChoiceNone;

  /// Require the model to call some tool, its choice which.
  const factory LottiToolChoice.required() = LottiToolChoiceRequired;

  /// Require the model to call the tool named [name].
  const factory LottiToolChoice.specific(String name) = LottiToolChoiceSpecific;
}

/// The model decides whether to call a tool.
@immutable
final class LottiToolChoiceAuto extends LottiToolChoice {
  /// Creates the automatic tool-choice policy.
  const LottiToolChoiceAuto();

  @override
  bool operator ==(Object other) => other is LottiToolChoiceAuto;

  @override
  int get hashCode => (LottiToolChoiceAuto).hashCode;

  @override
  String toString() => 'LottiToolChoice.auto()';
}

/// Tool calls are forbidden for this turn.
@immutable
final class LottiToolChoiceNone extends LottiToolChoice {
  /// Creates the "no tool calls" policy.
  const LottiToolChoiceNone();

  @override
  bool operator ==(Object other) => other is LottiToolChoiceNone;

  @override
  int get hashCode => (LottiToolChoiceNone).hashCode;

  @override
  String toString() => 'LottiToolChoice.none()';
}

/// The model must call some tool.
@immutable
final class LottiToolChoiceRequired extends LottiToolChoice {
  /// Creates the "must call a tool" policy.
  const LottiToolChoiceRequired();

  @override
  bool operator ==(Object other) => other is LottiToolChoiceRequired;

  @override
  int get hashCode => (LottiToolChoiceRequired).hashCode;

  @override
  String toString() => 'LottiToolChoice.required()';
}

/// The model must call one named tool.
@immutable
final class LottiToolChoiceSpecific extends LottiToolChoice {
  /// Requires a call to the tool named [name].
  const LottiToolChoiceSpecific(this.name);

  /// The tool the model is forced to call.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is LottiToolChoiceSpecific && other.name == name;

  @override
  int get hashCode => Object.hash(LottiToolChoiceSpecific, name);

  @override
  String toString() => 'LottiToolChoice.specific($name)';
}
