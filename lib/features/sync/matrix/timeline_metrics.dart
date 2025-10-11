class TimelineMetrics {
  int drainPasses = 0;
  int eventsProcessed = 0;
  int retryAttempts = 0;
  Duration totalProcessingTime = Duration.zero;

  void addProcessingTime(Duration d) {
    totalProcessingTime += d;
  }
}
