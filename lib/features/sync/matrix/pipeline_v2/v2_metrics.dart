class V2Metrics {
  const V2Metrics({
    required this.processed,
    required this.skipped,
    required this.failures,
    required this.prefetch,
    required this.flushes,
    required this.catchupBatches,
    required this.skippedByRetryLimit,
    required this.retriesScheduled,
    required this.circuitOpens,
  });

  factory V2Metrics.fromMap(Map<String, dynamic> map) => V2Metrics(
        processed: (map['processed'] ?? 0) as int,
        skipped: (map['skipped'] ?? 0) as int,
        failures: (map['failures'] ?? 0) as int,
        prefetch: (map['prefetch'] ?? 0) as int,
        flushes: (map['flushes'] ?? 0) as int,
        catchupBatches: (map['catchupBatches'] ?? 0) as int,
        skippedByRetryLimit: (map['skippedByRetryLimit'] ?? 0) as int,
        retriesScheduled: (map['retriesScheduled'] ?? 0) as int,
        circuitOpens: (map['circuitOpens'] ?? 0) as int,
      );

  final int processed;
  final int skipped;
  final int failures;
  final int prefetch;
  final int flushes;
  final int catchupBatches;
  final int skippedByRetryLimit;
  final int retriesScheduled;
  final int circuitOpens;

  Map<String, int> toMap() => <String, int>{
        'processed': processed,
        'skipped': skipped,
        'failures': failures,
        'prefetch': prefetch,
        'flushes': flushes,
        'catchupBatches': catchupBatches,
        'skippedByRetryLimit': skippedByRetryLimit,
        'retriesScheduled': retriesScheduled,
        'circuitOpens': circuitOpens,
      };
}
