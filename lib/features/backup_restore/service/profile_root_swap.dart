import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:path/path.dart' as p;

/// Where a restore swap stands. Persisted before each step, so a crash at any
/// point can be finished or undone at the next launch.
enum ProfileRestorePhase {
  /// Moving the profile's own entries out of the root into `previous-<id>`.
  movingOut,

  /// Moving the restored entries into the root.
  movingIn,

  /// The root holds the restored profile, not yet proven to start.
  restored,

  /// Undoing: the root holds none of the restored entries any more, and the
  /// originals are on their way back.
  rollingBack,

  /// The restored profile started; what is left is deleting the originals.
  committed,
}

/// A restore swap could not complete, or its journal is unreadable.
class ProfileRestoreSwapException implements Exception {
  const ProfileRestoreSwapException(this.message);

  final String message;

  @override
  String toString() => 'ProfileRestoreSwapException: $message';
}

/// Replaces the contents of one profile root with a restored profile, and
/// undoes that, one journaled rename at a time.
///
/// Everything happens below [workDirectory], a hidden folder inside the root,
/// so every move is a same-filesystem rename: an entry is always wholly in one
/// place, never half-copied. Entries that belong to the device rather than the
/// profile — the profile registry, guest worlds, diagnostic logs and the work
/// folder itself — are never moved.
///
/// The journal names the phase *before* each step runs. [rollBack] can
/// therefore resume from any phase, including a rollback that was itself
/// interrupted, and [recover] finishes whatever a crash left behind.
class ProfileRootSwap {
  ProfileRootSwap(this.root, {required this.restoreId}) {
    if (!_safeRestoreId.hasMatch(restoreId)) {
      throw ArgumentError.value(restoreId, 'restoreId', 'unsafe for a path');
    }
  }

  static final _safeRestoreId = RegExp(r'^[A-Za-z0-9_-]+$');
  static const _journalName = 'restore-journal.json';
  static const _journalVersion = 1;

  /// Catalog stores whose top-level entries stay where they are.
  static const _deviceStoreIds = {
    'profile-registry',
    'guest-profile-container',
    'diagnostic-logs',
    'restore-work',
  };

  final Directory root;
  final String restoreId;

  Directory get workDirectory =>
      Directory(p.join(root.path, profileRestoreWorkDirectoryName));

  /// Where the verified incoming snapshot is extracted.
  Directory get incomingDirectory =>
      Directory(p.join(workDirectory.path, 'incoming-$restoreId'));

  /// The incoming profile's files, laid out like a profile root.
  Directory get incomingPayload =>
      Directory(p.join(incomingDirectory.path, 'payload'));

  Directory get _previous =>
      Directory(p.join(workDirectory.path, 'previous-$restoreId'));

  Directory get _failed =>
      Directory(p.join(workDirectory.path, 'failed-$restoreId'));

  static File _journalIn(Directory root) => File(
    p.join(root.path, profileRestoreWorkDirectoryName, _journalName),
  );

  /// Whether a restore in [root] was started and never finished or undone.
  static bool hasPendingRestore(Directory root) =>
      _journalIn(root).existsSync();

  /// Whether [name], a top-level entry of a profile root, belongs to the
  /// device and is left alone by a restore.
  static bool isDeviceEntry(String name) =>
      _deviceStoreIds.contains(ProfileBackupCatalog.classify(name).storeId);

  /// Swaps the incoming payload into the root.
  ///
  /// On failure the caller must [rollBack]; the journal already says how far
  /// the swap got.
  void swapIn() {
    if (hasPendingRestore(root)) {
      throw const ProfileRestoreSwapException(
        'An earlier restore has not been finished or undone.',
      );
    }
    if (!incomingPayload.existsSync()) {
      throw const ProfileRestoreSwapException('Nothing staged to restore.');
    }
    _writeJournal(ProfileRestorePhase.movingOut);
    _previous.createSync(recursive: true);
    _moveProfileEntries(from: root, to: _previous);
    _writeJournal(ProfileRestorePhase.movingIn);
    _moveAll(from: incomingPayload, to: root);
    _writeJournal(ProfileRestorePhase.restored);
  }

  /// Puts the original profile back, from whatever phase the journal records,
  /// and removes the restore's working folders. Without a journal there is
  /// nothing to undo.
  ///
  /// The journal decides which restore is undone: a pending restore of an
  /// earlier attempt is rolled back as itself, never mistaken for this one.
  void rollBack() {
    final journal = _readJournal(root);
    if (journal == null) return;
    if (journal.restoreId != restoreId) {
      ProfileRootSwap(root, restoreId: journal.restoreId).rollBack();
      return;
    }
    final phase = journal.phase;
    if (phase == ProfileRestorePhase.committed) {
      // The restored profile already started; undoing it would be data loss.
      _cleanUp();
      return;
    }
    if (phase == ProfileRestorePhase.movingIn ||
        phase == ProfileRestorePhase.restored) {
      _failed.createSync(recursive: true);
      _moveProfileEntries(from: root, to: _failed);
      _writeJournal(ProfileRestorePhase.rollingBack);
    }
    if (_previous.existsSync()) _moveAll(from: _previous, to: root);
    _cleanUp();
  }

  /// Makes the restore permanent: records that it succeeded, then deletes
  /// the original profile and the working folders.
  void commit() {
    final phase = _readJournal(root)?.phase;
    if (phase != ProfileRestorePhase.restored &&
        phase != ProfileRestorePhase.committed) {
      throw ProfileRestoreSwapException(
        'Cannot commit a restore in phase ${phase?.name ?? 'none'}.',
      );
    }
    _writeJournal(ProfileRestorePhase.committed);
    _cleanUp();
  }

  /// Finishes or undoes a restore a crash interrupted in [root], at launch
  /// and before anything opens the profile. A committed restore is kept;
  /// anything earlier is rolled back. Leftovers without a journal — an
  /// extraction that never reached the swap — are deleted.
  static void recover(Directory root) {
    if (hasPendingRestore(root)) {
      final journal = _readJournal(root)!;
      ProfileRootSwap(root, restoreId: journal.restoreId).rollBack();
      return;
    }
    final work = Directory(p.join(root.path, profileRestoreWorkDirectoryName));
    if (work.existsSync()) work.deleteSync(recursive: true);
  }

  void _moveProfileEntries({required Directory from, required Directory to}) {
    for (final entity in from.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (isDeviceEntry(name)) continue;
      entity.renameSync(p.join(to.path, name));
    }
  }

  /// Moves every entry of [from] into [to], after checking that none of
  /// them would land on an existing one — so a conflict moves nothing, and a
  /// rename never replaces a file.
  void _moveAll({required Directory from, required Directory to}) {
    final entities = from.listSync(followLinks: false);
    for (final entity in entities) {
      final destination = p.join(to.path, p.basename(entity.path));
      if (FileSystemEntity.typeSync(destination, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw ProfileRestoreSwapException(
          'Cannot move ${p.basename(entity.path)}: the destination is taken.',
        );
      }
    }
    for (final entity in entities) {
      entity.renameSync(p.join(to.path, p.basename(entity.path)));
    }
  }

  void _cleanUp() {
    for (final directory in [_previous, _failed, incomingDirectory]) {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    final journal = _journalIn(root);
    if (journal.existsSync()) journal.deleteSync();
    if (workDirectory.existsSync() && workDirectory.listSync().isEmpty) {
      workDirectory.deleteSync();
    }
  }

  void _writeJournal(ProfileRestorePhase phase) {
    final journal = _journalIn(root);
    journal.parent.createSync(recursive: true);
    File('${journal.path}.tmp')
      ..writeAsStringSync(
        jsonEncode({
          'version': _journalVersion,
          'restoreId': restoreId,
          'phase': phase.name,
        }),
        flush: true,
      )
      ..renameSync(journal.path);
  }

  static ({String restoreId, ProfileRestorePhase phase})? _readJournal(
    Directory root,
  ) {
    final journal = _journalIn(root);
    if (!journal.existsSync()) return null;
    try {
      final json = jsonDecode(journal.readAsStringSync());
      if (json is Map<String, Object?> &&
          json['version'] == _journalVersion &&
          json['restoreId'] is String &&
          _safeRestoreId.hasMatch(json['restoreId']! as String)) {
        final phase = ProfileRestorePhase.values.asNameMap()[json['phase']];
        if (phase != null) {
          return (restoreId: json['restoreId']! as String, phase: phase);
        }
      }
    } on FormatException {
      // Reported below.
    }
    throw ProfileRestoreSwapException(
      'The restore journal in ${root.path} is unreadable; nothing was changed.',
    );
  }
}
