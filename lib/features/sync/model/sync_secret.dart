import 'package:meta/meta.dart';

/// A credential carried in a sync message — end-to-end encrypted with the
/// rest of it — that must never show up in a log line or a debug print:
/// [toString] is redacted, while the JSON carries the [value].
@immutable
class SyncSecret {
  const SyncSecret(this.value);

  factory SyncSecret.fromJson(String json) => SyncSecret(json);

  final String value;

  String toJson() => value;

  @override
  String toString() => 'SyncSecret(redacted)';

  @override
  bool operator ==(Object other) => other is SyncSecret && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
