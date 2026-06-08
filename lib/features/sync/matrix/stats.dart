import 'package:flutter/foundation.dart';

@immutable
class MatrixStats {
  const MatrixStats({
    required this.sentCount,
    required this.messageCounts,
  });

  final int sentCount;
  final Map<String, int> messageCounts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatrixStats &&
          runtimeType == other.runtimeType &&
          sentCount == other.sentCount &&
          mapEquals(messageCounts, other.messageCounts);

  @override
  int get hashCode => Object.hash(
    sentCount,
    // A plain Map's hashCode is identity-based, which would make two
    // value-equal MatrixStats (compared via mapEquals) hash differently and
    // break the hashCode/== contract. Hash the entries unordered instead so
    // the hash mirrors the unordered structural equality above.
    Object.hashAllUnordered(
      messageCounts.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
