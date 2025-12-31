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
  int get hashCode => sentCount.hashCode ^ messageCounts.hashCode;
}
