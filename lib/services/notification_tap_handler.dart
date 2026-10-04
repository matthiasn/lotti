/// Where a tapped OS notification is handed over.
///
/// `NotificationService` lives below the features, so it resolves this
/// interface rather than the notifications feature's router. The composition
/// root registers the router under it, alongside the router itself, for
/// every profile generation.
abstract interface class NotificationTapHandler {
  /// Routes the tap that carried [payload].
  Future<void> handleTap(String payload);
}
