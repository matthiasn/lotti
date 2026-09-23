import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/backup_restore/service/profile_root_swap.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late ProfileRootSwap swap;

  /// Everything the original profile holds, by relative path.
  const original = {
    'db.sqlite': 'old journal',
    'settings.sqlite': 'old settings',
    'fts5_db.sqlite': 'old index',
    'images/2026/a.jpg': 'old photo',
  };

  /// Entries that belong to the device and must never move.
  const device = {
    'profiles.json': 'registry',
    'guest_profiles/demo/db.sqlite': 'a guest world',
    'logs/general.log': 'diagnostics',
  };

  /// What the backup restores.
  const incoming = {
    'db.sqlite': 'restored journal',
    'settings.sqlite': 'restored settings',
    'audio/2026/b.m4a': 'restored audio',
  };

  void write(Directory base, Map<String, String> files) {
    for (final MapEntry(key: path, value: content) in files.entries) {
      File(p.join(base.path, path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }

  /// Every file below [base] as relative path → content, skipping the work
  /// folder unless asked.
  Map<String, String> contents(Directory base, {bool includeWork = false}) => {
    for (final file in base.listSync(recursive: true).whereType<File>())
      if (includeWork ||
          !p
              .relative(file.path, from: base.path)
              .startsWith(profileRestoreWorkDirectoryName))
        p.relative(file.path, from: base.path).replaceAll(p.separator, '/'):
            file.readAsStringSync(),
  };

  File journal() => File(
    p.join(root.path, profileRestoreWorkDirectoryName, 'restore-journal.json'),
  );

  void writeJournal(String phase, {String restoreId = 'r1'}) {
    journal()
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({'version': 1, 'restoreId': restoreId, 'phase': phase}),
      );
  }

  Directory work(String name) => Directory(
    p.join(root.path, profileRestoreWorkDirectoryName, name),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('lotti_root_swap_');
    write(root, {...original, ...device});
    swap = ProfileRootSwap(root, restoreId: 'r1');
    write(swap.incomingPayload, incoming);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('swapIn', () {
    test('replaces the profile and leaves the device entries alone', () {
      swap.swapIn();

      expect(contents(root), {...incoming, ...device});
      expect(contents(work('previous-r1')), original);
      final recorded =
          jsonDecode(journal().readAsStringSync()) as Map<String, Object?>;
      expect(recorded['phase'], 'restored');
    });

    test('refuses to start over an unfinished restore', () {
      writeJournal('movingIn', restoreId: 'other');

      expect(swap.swapIn, throwsA(isA<ProfileRestoreSwapException>()));
      expect(contents(root), {...original, ...device});
    });

    test('refuses when nothing was staged', () {
      swap.incomingDirectory.deleteSync(recursive: true);

      expect(swap.swapIn, throwsA(isA<ProfileRestoreSwapException>()));
      expect(contents(root), {...original, ...device});
      expect(journal().existsSync(), isFalse);
    });
  });

  group('commit', () {
    test('keeps the restored profile and removes everything else', () {
      swap
        ..swapIn()
        ..commit();

      expect(contents(root, includeWork: true), {...incoming, ...device});
      expect(
        Directory(
          p.join(root.path, profileRestoreWorkDirectoryName),
        ).existsSync(),
        isFalse,
      );
    });

    test('refuses to commit a swap that never finished', () {
      writeJournal('movingIn');

      expect(swap.commit, throwsA(isA<ProfileRestoreSwapException>()));
    });

    test('refuses to commit without any swap', () {
      expect(swap.commit, throwsA(isA<ProfileRestoreSwapException>()));
    });
  });

  group('rollBack', () {
    test('after a complete swap, puts the original profile back', () {
      swap
        ..swapIn()
        ..rollBack();

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    test('without a journal changes nothing', () {
      swap.rollBack();

      expect(contents(root), {...original, ...device});
      expect(swap.incomingDirectory.existsSync(), isTrue);
    });

    // Each crash point, reconstructed on disk exactly as swapIn leaves it.
    test('interrupted while moving the profile out', () {
      writeJournal('movingOut');
      final previous = work('previous-r1')..createSync(recursive: true);
      File(
        p.join(root.path, 'db.sqlite'),
      ).renameSync(p.join(previous.path, 'db.sqlite'));

      swap.rollBack();

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    test('interrupted while moving the backup in', () {
      final previous = work('previous-r1')..createSync(recursive: true);
      for (final name in [
        'db.sqlite',
        'settings.sqlite',
        'fts5_db.sqlite',
        'images',
      ]) {
        FileSystemEntity.typeSync(p.join(root.path, name)) ==
                FileSystemEntityType.directory
            ? Directory(
                p.join(root.path, name),
              ).renameSync(p.join(previous.path, name))
            : File(
                p.join(root.path, name),
              ).renameSync(p.join(previous.path, name));
      }
      writeJournal('movingIn');
      File(
        p.join(swap.incomingPayload.path, 'db.sqlite'),
      ).renameSync(p.join(root.path, 'db.sqlite'));

      swap.rollBack();

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    test('a rollback interrupted after the restored entries left finishes '
        'without touching the originals already back', () {
      swap.swapIn();
      // What rollBack does before recording rollingBack, then half of the
      // way back: the restored entries are out, some originals are home.
      final failed = work('failed-r1')..createSync(recursive: true);
      for (final name
          in incoming.keys.map((path) => path.split('/').first).toSet()) {
        FileSystemEntity.typeSync(p.join(root.path, name)) ==
                FileSystemEntityType.directory
            ? Directory(
                p.join(root.path, name),
              ).renameSync(p.join(failed.path, name))
            : File(
                p.join(root.path, name),
              ).renameSync(p.join(failed.path, name));
      }
      writeJournal('rollingBack');
      File(
        p.join(work('previous-r1').path, 'db.sqlite'),
      ).renameSync(p.join(root.path, 'db.sqlite'));

      swap.rollBack();

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    test('undoes the restore its journal names, not its own', () {
      swap.swapIn();

      // A new attempt with another id meets the pending one.
      ProfileRootSwap(root, restoreId: 'r2').rollBack();

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    test('never undoes a committed restore', () {
      swap.swapIn();
      writeJournal('committed');

      swap.rollBack();

      expect(contents(root, includeWork: true), {...incoming, ...device});
    });

    test('stops instead of overwriting an entry already in place', () {
      swap.swapIn();
      writeJournal('rollingBack');
      // Something recreated a database the original also has.

      expect(swap.rollBack, throwsA(isA<ProfileRestoreSwapException>()));
      // Nothing was moved or overwritten: the original is still parked whole,
      // the entry in the way untouched, and the journal left for a retry.
      expect(contents(work('previous-r1')), original);
      expect(
        File(p.join(root.path, 'db.sqlite')).readAsStringSync(),
        'restored journal',
      );
      expect(journal().existsSync(), isTrue);
    });
  });

  group('recover', () {
    test('rolls back a restore that never proved itself', () {
      swap.swapIn();

      ProfileRootSwap.recover(root);

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    test('finishes a committed restore', () {
      swap.swapIn();
      writeJournal('committed');

      ProfileRootSwap.recover(root);

      expect(contents(root, includeWork: true), {...incoming, ...device});
    });

    test('deletes an extraction that never reached the swap', () {
      ProfileRootSwap.recover(root);

      expect(contents(root, includeWork: true), {...original, ...device});
      expect(swap.workDirectory.existsSync(), isFalse);
    });

    test('does nothing to a profile without a restore folder', () {
      swap.incomingDirectory.deleteSync(recursive: true);
      swap.workDirectory.deleteSync(recursive: true);

      ProfileRootSwap.recover(root);

      expect(contents(root, includeWork: true), {...original, ...device});
    });

    for (final (label, json) in [
      ('not JSON', '{nope'),
      (
        'a future version',
        jsonEncode({'version': 2, 'restoreId': 'r1', 'phase': 'restored'}),
      ),
      (
        'an unknown phase',
        jsonEncode({'version': 1, 'restoreId': 'r1', 'phase': 'halfway'}),
      ),
      (
        'an unsafe id',
        jsonEncode({'version': 1, 'restoreId': '../x', 'phase': 'restored'}),
      ),
      ('not an object', '[]'),
    ]) {
      test('refuses a journal that is $label, changing nothing', () {
        swap.swapIn();
        journal().writeAsStringSync(json);

        expect(
          () => ProfileRootSwap.recover(root),
          throwsA(isA<ProfileRestoreSwapException>()),
        );
        expect(contents(root), {...incoming, ...device});
        expect(contents(work('previous-r1')), original);
      });
    }
  });

  test('knows which top-level entries belong to the device', () {
    for (final name in [
      'profiles.json',
      'profiles.json.tmp.1.2.media',
      'guest_profiles',
      'logs',
      profileRestoreWorkDirectoryName,
    ]) {
      expect(ProfileRootSwap.isDeviceEntry(name), isTrue, reason: name);
    }
    for (final name in ['db.sqlite', 'images', 'fts5_db.sqlite', 'backup']) {
      expect(ProfileRootSwap.isDeviceEntry(name), isFalse, reason: name);
    }
  });

  test('knows whether a restore is pending', () {
    expect(ProfileRootSwap.hasPendingRestore(root), isFalse);
    swap.swapIn();
    expect(ProfileRootSwap.hasPendingRestore(root), isTrue);
    swap.commit();
    expect(ProfileRootSwap.hasPendingRestore(root), isFalse);
  });

  test('rejects a restore id that is unsafe for a path', () {
    expect(
      () => ProfileRootSwap(root, restoreId: '../escape'),
      throwsArgumentError,
    );
  });

  test('describes its failures', () {
    expect(
      const ProfileRestoreSwapException('stuck').toString(),
      'ProfileRestoreSwapException: stuck',
    );
  });
}
