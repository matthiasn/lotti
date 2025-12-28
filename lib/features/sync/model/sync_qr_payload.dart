import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_qr_payload.freezed.dart';
part 'sync_qr_payload.g.dart';

/// Payload structure for the sync setup QR code.
///
/// Contains the version number and encrypted credentials data.
/// The encrypted data includes homeserver, username, password, and expiry
/// timestamp, all encrypted with AES-256-GCM using a PIN-derived key.
@Freezed(toStringOverride: false)
abstract class SyncQrPayload with _$SyncQrPayload {
  const factory SyncQrPayload({
    /// Version number for future compatibility
    required int version,

    /// Base64-encoded AES-256-GCM encrypted credentials
    required String encryptedData,
  }) = _SyncQrPayload;

  const SyncQrPayload._();

  factory SyncQrPayload.fromJson(Map<String, dynamic> json) =>
      _$SyncQrPayloadFromJson(json);

  /// Creates a payload from encrypted data with current version.
  factory SyncQrPayload.v1(String encryptedData) => SyncQrPayload(
        version: 1,
        encryptedData: encryptedData,
      );

  /// Parses a QR code string into a [SyncQrPayload].
  ///
  /// Returns null if the string is not valid JSON or doesn't match
  /// the expected payload structure.
  static SyncQrPayload? tryParse(String qrData) {
    try {
      final json = jsonDecode(qrData) as Map<String, dynamic>;
      return SyncQrPayload.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Encodes this payload as a JSON string for QR code generation.
  String toQrString() => jsonEncode(toJson());

  /// Whether this payload version is supported.
  bool get isSupported => version == 1;
}
