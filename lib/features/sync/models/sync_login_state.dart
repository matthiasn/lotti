/// The session's login state as the UI sees it (ADR 0142): the Matrix SDK's
/// `LoginState`, without the SDK, so it can be reported from an isolate the
/// UI does not share a client with.
enum SyncLoginState {
  loggedOut,
  loggedIn,

  /// The access token expired; the SDK keeps the session's keys and expects a
  /// re-login.
  softLoggedOut,
}
