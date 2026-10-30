import 'dart:typed_data';

import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';

/// How the device that embeds an entry shares the version it wrote with the
/// user's other devices.
///
/// Defined here and implemented by sync, which ranks above this feature:
/// `EmbeddingProcessor` reserves a version before its store write and sends
/// it after, without importing sync.
abstract interface class EmbeddingShare {
  /// Reserves the next version of register [registerId], extending
  /// [previous], the clock of the version stored now.
  ///
  /// Returns `null` when versions are not shared at the moment — sync is not
  /// set up, or `sync_embeddings` is off. The version is then stored without
  /// a clock and stays on this device.
  Future<EmbeddingVersionTicket?> reserve({
    required String registerId,
    VectorClock? previous,
  });
}

/// A reserved register version, finalized exactly once: by [send] once the
/// version is stored, or by [release] when the store write failed.
abstract interface class EmbeddingVersionTicket {
  /// The version's clock: the previous one with this host's counter bumped.
  VectorClock get vectorClock;

  /// This device's host id, recorded as the version's originator.
  String get hostId;

  /// Enqueues [version], already stored, with its complete chunk set
  /// [chunks] (none for a tombstone), and binds the reservation.
  ///
  /// Never throws: a version that could not be enqueued is released and
  /// settled, and a sharing failure never fails the embed that stored it.
  Future<void> send(EmbeddingRegister version, List<Float32List> chunks);

  /// Gives the reservation up; the counter is settled from the stored
  /// payload, so a version that did land is still sent.
  Future<void> release();
}
