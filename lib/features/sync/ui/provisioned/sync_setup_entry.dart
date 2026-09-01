/// Page indices of the sync setup sheet, shared by every page that navigates
/// it so the targets are named rather than counted.
abstract final class SyncSetupPage {
  /// The pairing-code entry: camera or paste.
  static const int pairingCode = 0;

  /// The connect step, narrating `ProvisioningController` until it ends.
  static const int connect = 1;

  /// The device roster the journey lands on.
  static const int devices = 2;

  /// The Linux-only entry that signs in with typed Matrix credentials.
  static const int credentials = 3;
}

/// Which entry page the connect step was reached from. The connect step's
/// copy and its way back depend on it: a rejected pairing code is fixed by a
/// fresh code, a rejected sign-in by editing the details.
enum SyncSetupEntry {
  pairingCode(SyncSetupPage.pairingCode),
  credentials(SyncSetupPage.credentials);

  const SyncSetupEntry(this.page);

  /// The sheet page this entry is made on.
  final int page;
}
