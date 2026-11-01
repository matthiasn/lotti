import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/ai/database/embedding_register.dart';

/// A received version waiting for the text it was made from.
class HeldEmbeddingVersion {
  const HeldEmbeddingVersion({
    required this.register,
    required this.payload,
    this.labelIds = const [],
  });

  factory HeldEmbeddingVersion.fromJson(Map<String, dynamic> json) =>
      HeldEmbeddingVersion(
        register: EmbeddingRegister.fromJson(
          json['register'] as Map<String, dynamic>,
        ),
        payload: json['payload'] as String,
        labelIds: [...?(json['labelIds'] as List<dynamic>?)?.cast<String>()],
      );

  final EmbeddingRegister register;

  /// The vectors attachment's JSON, as it arrived.
  final String payload;

  /// The labels of the local copy of a task when the version was held: a
  /// label whose definition has not arrived changes the task's text.
  final List<String> labelIds;

  Map<String, dynamic> toJson() => {
    'register': register.toJson(),
    'payload': payload,
    'labelIds': labelIds,
  };
}

/// The versions held until their text arrives, newest per register, kept in
/// one JSON file so they survive a restart: their receipts are recorded, so
/// nothing would send them again.
///
/// The table stays small — a version is held only while its entry has not
/// caught up — so every change rewrites the whole file, through a temporary
/// file and a rename.
class HeldEmbeddingVersions {
  HeldEmbeddingVersions._(this._file, this._held);

  /// Opens the table at [path]. A missing or unreadable file is an empty
  /// table: what it held is versions a later backfill can deliver again.
  static Future<HeldEmbeddingVersions> open(String path) async {
    final file = File(path);
    final held = <String, HeldEmbeddingVersion>{};
    if (file.existsSync()) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final entry in json.entries) {
          held[entry.key] = HeldEmbeddingVersion.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      } on Object {
        held.clear();
      }
    }
    return HeldEmbeddingVersions._(file, held);
  }

  final File _file;
  final Map<String, HeldEmbeddingVersion> _held;
  final StreamController<int> _counts = StreamController<int>.broadcast();

  /// The last write, so writes land one after another, each with the
  /// snapshot taken when it was asked for: two writes never share the
  /// temporary file, and an older snapshot never replaces a newer one.
  Future<void> _writes = Future.value();

  /// Every held version.
  List<HeldEmbeddingVersion> get all => List.unmodifiable(_held.values);

  /// The version held of register [registerId], or `null`.
  HeldEmbeddingVersion? operator [](String registerId) => _held[registerId];

  /// How many versions are held now, then again after every change: what
  /// Sync health shows, since a held version's receipt is recorded and the
  /// sequence log never reports it missing.
  Stream<int> watchCount() {
    StreamSubscription<int>? changes;
    late final StreamController<int> controller;
    controller = StreamController<int>(
      onListen: () {
        controller.add(_held.length);
        changes = _counts.stream.listen(controller.add);
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  /// Holds [version], replacing what was held of its register.
  Future<void> put(HeldEmbeddingVersion version) async {
    _held[version.register.id] = version;
    _counts.add(_held.length);
    await _persist();
  }

  /// Drops what is held of [registerId]; a no-op when nothing is.
  Future<void> remove(String registerId) async {
    if (_held.remove(registerId) == null) return;
    _counts.add(_held.length);
    await _persist();
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      for (final entry in _held.entries) entry.key: entry.value.toJson(),
    });
    final write = _writes.then((_) => _write(snapshot));
    // A failed write fails its caller; the next one still runs.
    _writes = write.then((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> _write(String snapshot) async {
    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(snapshot, flush: true);
    await temp.rename(_file.path);
  }
}
