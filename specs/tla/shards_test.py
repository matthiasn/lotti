"""CI must execute every model, with enough room for measured long profiles."""

import unittest
from pathlib import Path

from specs.tla.shards import EXTENDED_CONFIGURATIONS, plan


class ShardPlanTest(unittest.TestCase):
    def test_every_checked_in_configuration_runs_once(self):
        configurations = sorted(path.stem for path in Path(__file__).parent.glob('*.cfg'))
        planned = plan(configurations)
        assigned = [name for shard in planned for name in shard['configurations'].split()]
        self.assertCountEqual(assigned, configurations)
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertEqual([shard['shard'] for shard in planned], list(range(1, len(planned) + 1)))

    def test_long_profile_cannot_consume_a_regular_shards_deadline(self):
        planned = plan(
            ['SyncPipeline', 'SyncPipelineForkSuccessor', 'SyncPipelineMixedPeers'],
            shards=1,
        )
        long = next(shard for shard in planned if 'SyncPipelineForkSuccessor' in shard['configurations'])
        self.assertEqual(long['configurations'], 'SyncPipelineForkSuccessor')
        self.assertEqual(long['timeout_minutes'], 360)
        self.assertEqual(long['java_options'], '-Xmx12g')
        for shard in planned:
            if shard is not long:
                self.assertEqual(shard['timeout_minutes'], 60)
                self.assertEqual(shard['java_options'], '')

    def test_extended_only_plan_still_runs_every_profile(self):
        planned = plan(sorted(EXTENDED_CONFIGURATIONS))
        self.assertCountEqual(
            [shard['configurations'] for shard in planned], EXTENDED_CONFIGURATIONS,
        )
        self.assertTrue(all(shard['timeout_minutes'] == 360 for shard in planned))


if __name__ == '__main__':
    unittest.main()
