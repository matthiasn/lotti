import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A short, human-comparable fingerprint of what a pairing code connects to.
///
/// Both halves of the handshake can derive it independently — the inviting
/// device from its persisted config, the joining device from the decoded
/// bundle — because it depends only on the account and the sync room, which
/// both already know. Showing it on both screens turns the confirmation step
/// into something a person can actually check: raw Matrix identifiers say
/// nothing to a reader who has never seen them before.
///
/// Every field the confirmation screen shows is folded in, so the digits
/// genuinely cover what the reader is looking at — a code that ignored the
/// homeserver would leave the one row a person might recognise unprotected.
///
/// This is a **recognition aid, not a security control**. It is unkeyed and
/// derived from public identifiers, so it detects the wrong-code mistake, not
/// a determined attacker. Real confidentiality comes from the emoji (SAS)
/// ceremony that follows.
String pairingCheckCode({
  required String user,
  required String roomId,
  required String homeServer,
}) {
  final digest = sha256.convert(utf8.encode('$user|$roomId|$homeServer'));
  final hex = digest.toString().substring(0, 6).toUpperCase();
  return '${hex.substring(0, 3)}-${hex.substring(3, 6)}';
}
