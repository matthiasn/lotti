import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';

void main() {
  group('SettingsNode.hasChildren', () {
    test('is true when children is a non-empty list', () {
      const node = SettingsNode(
        id: 'sync',
        icon: Icons.sync_rounded,
        title: 'Sync',
        desc: 'desc',
        children: [
          SettingsNode(
            id: 'sync/backfill',
            icon: Icons.cloud_download_outlined,
            title: 'Backfill',
            desc: 'desc',
            panel: 'sync-backfill',
          ),
        ],
      );
      expect(node.hasChildren, isTrue);
    });

    test('is true for a branch with zero children (empty list)', () {
      // Empty-but-non-null children models a branch whose sub-nodes
      // are all gated off — spec §3 keeps it addressable as a branch.
      const node = SettingsNode(
        id: 'agents',
        icon: Icons.smart_toy_outlined,
        title: 'Agents',
        desc: 'desc',
        children: [],
      );
      expect(node.hasChildren, isTrue);
    });

    test('is false for a leaf (null children)', () {
      const node = SettingsNode(
        id: 'labels',
        icon: Icons.label_rounded,
        title: 'Labels',
        desc: 'desc',
        panel: 'labels',
      );
      expect(node.hasChildren, isFalse);
    });
  });

  group('SettingsNode equality', () {
    SettingsNode base() => const SettingsNode(
      id: 'sync/backfill',
      icon: Icons.cloud_download_outlined,
      title: 'Backfill',
      desc: 'Fill gaps',
      panel: 'sync-backfill',
    );

    test('structurally identical leaves compare equal', () {
      expect(base(), equals(base()));
      expect(base().hashCode, equals(base().hashCode));
    });

    test('differing only in id is not equal', () {
      final other = SettingsNode(
        id: 'sync/other',
        icon: base().icon,
        title: base().title,
        desc: base().desc,
        panel: base().panel,
      );
      expect(base(), isNot(equals(other)));
    });

    test('differing only in icon is not equal', () {
      final other = SettingsNode(
        id: base().id,
        icon: Icons.bolt,
        title: base().title,
        desc: base().desc,
        panel: base().panel,
      );
      expect(base(), isNot(equals(other)));
    });

    test('differing only in title is not equal', () {
      final other = SettingsNode(
        id: base().id,
        icon: base().icon,
        title: 'Other',
        desc: base().desc,
        panel: base().panel,
      );
      expect(base(), isNot(equals(other)));
    });

    test('differing only in desc is not equal', () {
      final other = SettingsNode(
        id: base().id,
        icon: base().icon,
        title: base().title,
        desc: 'Other desc',
        panel: base().panel,
      );
      expect(base(), isNot(equals(other)));
    });

    test('differing only in panel is not equal', () {
      final other = SettingsNode(
        id: base().id,
        icon: base().icon,
        title: base().title,
        desc: base().desc,
        panel: 'other-panel',
      );
      expect(base(), isNot(equals(other)));
    });

    test(
      'one branch with children vs. the same fields as a leaf is not equal',
      () {
        const leaf = SettingsNode(
          id: 'ai',
          icon: Icons.psychology_rounded,
          title: 'AI',
          desc: 'desc',
        );
        const branch = SettingsNode(
          id: 'ai',
          icon: Icons.psychology_rounded,
          title: 'AI',
          desc: 'desc',
          children: [],
        );
        expect(leaf, isNot(equals(branch)));
      },
    );

    test('branches with differing children lists are not equal', () {
      const childA = SettingsNode(
        id: 'ai/profiles',
        icon: Icons.tune_rounded,
        title: 'Profiles',
        desc: 'desc',
        panel: 'ai-profiles',
      );
      const childB = SettingsNode(
        id: 'ai/other',
        icon: Icons.tune_rounded,
        title: 'Other',
        desc: 'desc',
        panel: 'other',
      );
      const branchA = SettingsNode(
        id: 'ai',
        icon: Icons.psychology_rounded,
        title: 'AI',
        desc: 'desc',
        children: [childA],
      );
      const branchB = SettingsNode(
        id: 'ai',
        icon: Icons.psychology_rounded,
        title: 'AI',
        desc: 'desc',
        children: [childB],
      );
      expect(branchA, isNot(equals(branchB)));
    });

    test('identity short-circuit: a node equals itself', () {
      final node = base();
      expect(node == node, isTrue);
    });

    test('a node is not equal to an unrelated value', () {
      // ignore: unrelated_type_equality_checks
      expect(base() == 'sync/backfill', isFalse);
    });
  });
}
