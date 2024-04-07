class MatrixStats {
  MatrixStats({
    required this.sentCount,
    required this.messageCounts,
  });

  int sentCount;
  Map<String, int> messageCounts;
}
