"""CI must execute every model, with enough room for measured long profiles."""

import unittest
from pathlib import Path

from specs.tla.shards import SECONDS, SHARD_BUDGET_SECONDS, plan


class ShardPlanTest(unittest.TestCase):
    def test_every_checked_in_configuration_runs_once(self):
        configurations = sorted(path.stem for path in Path(__file__).parent.glob('*.cfg'))
        planned = plan(configurations)
        assigned = [name for shard in planned for name in shard['configurations'].split()]
        self.assertCountEqual(assigned, configurations)
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertEqual([shard['shard'] for shard in planned], list(range(1, len(planned) + 1)))

    def test_no_regular_shard_is_planned_past_its_budget(self):
        # Packed to its 60-minute timeout, every shard of the nightly run timed
        # out; the plan adds shards instead. A single configuration larger than
        # the budget still gets a shard of its own.
        configurations = sorted(path.stem for path in Path(__file__).parent.glob('*.cfg'))
        for shard in plan(configurations):
            names = shard['configurations'].split()
            if len(names) == 1:
                continue
            self.assertLessEqual(shard['estimate'], SHARD_BUDGET_SECONDS, names)

    def test_more_work_gets_more_shards(self):
        heavy = [f'Heavy{i}' for i in range(40)]
        budget_each = SHARD_BUDGET_SECONDS // 2
        SECONDS.update({name: budget_each for name in heavy})
        try:
            planned = plan(heavy)
        finally:
            for name in heavy:
                SECONDS.pop(name)
        self.assertEqual(len(planned), 20)
        self.assertTrue(all(shard['estimate'] <= SHARD_BUDGET_SECONDS for shard in planned))

    def test_manual_configurations_are_not_planned(self):
        # Too long for any CI job; run by hand (manual/).
        configurations = sorted(path.stem for path in Path(__file__).parent.glob('*.cfg'))
        self.assertNotIn('SyncPipelineForkSuccessor', configurations)
        self.assertTrue((Path(__file__).parent / 'manual' / 'SyncPipelineForkSuccessor.cfg').exists())


if __name__ == '__main__':
    unittest.main()
